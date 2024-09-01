// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../ERC721TLC.sol";
import "../extensions/ERC721TLCDataURI.sol";
import "../extensions/ERC721TransferValidator.sol";
import "../extensions/ERC2771Context.sol";
import "solady/tokens/ERC2981.sol";
import "solady/auth/OwnableRoles.sol";
import "solady/utils/LibBitmap.sol";
import "solady/utils/LibSort.sol";

interface IERC721TransferValidator {
    function validateTransfer(address caller, address from, address to, uint256 tokenId) external view;
}

/// @author 0xkuwabatake (@0xkuwabatake)
contract ERC721TLCDrop is
    ERC721TLC,
    ERC721TLCDataURI,
    ERC721TransferValidator,
    ERC2771Context,
    ERC2981,
    OwnableRoles
{
    using LibBitmap for LibBitmap.Bitmap;
    
    ///////// STORAGE /////////////////////////////////////////////////////////////////////////////O-'

    /// @dev Mapping from address => `tierId` => number minted token ID.
    mapping(address => mapping(uint256 => uint256)) private _numberMinted;

    /// @dev Mapping from `tierId` => merkle root.
    mapping(uint256 => bytes32) private _merkleRoot;

    /// @dev Mapping from `index` => `paused` or mint activity status.
    ///
    /// Note:
    /// - Index       0 is allocated for paused status toggle.
    /// - Index  1 - 10 are allocated for mint activity status toggle from tier ID #1 - #10.
    /// ```
    LibBitmap.Bitmap private _status;

    /// @dev Withdrawal address.
    address public withdrawalAddress;

    ///////// CUSTOM EVENTS ///////////////////////////////////////////////////////////////////////O-'

    /// @dev Emitted when mint status for `tierId` is updated to `state`.
    event MintStatusUpdate(uint256 indexed tierId, bool state);

    /// @dev Emitted when `mintFee` for `tierId` is updated.
    event MintFeeUpdate(uint256 indexed tierId, uint256 indexed mintFee);

    /// @dev Emitted when `discountedMintFee` to mint `tierToMint` for `tierIsOwned` by genesis owner is updated.
    event MintFeeForGenesisOwnerUpdate(
        uint256 indexed tierIsOwned,
        uint256 indexed tierToMint,
        uint256 indexed discountedMintFee
    );

    ///////// CUSTOM ERRORS ///////////////////////////////////////////////////////////////////////O-'

    /// @dev Revert with an error if an address exceeds maximum number minted for tier ID.
    error ExceedsMaxNumberMinted();

    /// @dev Revert with an error if the maximum number of airdrop recipients is exceeded.
    error ExceedsMaxRecipients();

    /// @dev Revert with an error if merkle proof is invalid.
    error InvalidMerkleProof();

    /// @dev Revert with an error if life cycle for tier ID is undefined.
    error UndefinedLifeCycle();

    /// @dev Revert with an error if mint status is not active.
    error MintIsNotActive();

    /// @dev Revert with an error if tier ID is invalid.
    error InvalidTierId();

    /// @dev Revert with an error if `discountBPS` exceeds maximum BPS (10000).
    error ExceedsMaxBPS();

    /// @dev Revert with an error if fee is undefined.
    error UndefinedFee();

    /// @dev Revert with an error if not the owner of token or tier ID.
    error InvalidOwner();

    /// @dev Revert with an error if it's at paused state.
    error Paused();

    ///////// MODIFIERS ///////////////////////////////////////////////////////////////////////////O-'

    /// @dev Tier ID must not be 0 (zero) and greater than 10 (ten).
    modifier isValidTier(uint256 tierId) {
        if (tierId == 0) _revert(InvalidTierId.selector);
        if (tierId > 10) _revert(InvalidTierId.selector);
        _;
    }

    /// @dev Tier ID for whitelist mint must not be less than 1 or greater than 2.
    modifier isWhitelistMintTier(uint256 tierId) {
        if (tierId < 1 || tierId > 2) _revert(InvalidTierId.selector);
        _;
    }

    /// @dev Tier ID for public mint must not be less than 3 or greater than 8.
    modifier isPublicMintTier(uint256 tierId) {
        if (tierId < 3 || tierId > 7) _revert(InvalidTierId.selector);
        _;
    }

    /// @dev Tier ID for claim (free mint) must not be less than 8 or greater than 10.
    modifier isClaimTier(uint256 tierId) {
        if (tierId < 8 || tierId > 10) _revert(InvalidTierId.selector);
        _;
    }

    /// @dev Life cycle value for `tierId` must be non-zero.
    /// See: {TierLifeCycle - _setLifeCycle}, {ERC721TLC - _setMintExtraData}.
    modifier isDefinedLifeCycle(uint256 tierId) {
        if (lifeCycle(tierId) == 0) _revert(UndefinedLifeCycle.selector);
        _;
    }

    /// @dev Only mint status for `tierId` is active.
    modifier onlyMintActive(uint256 tierId) {
        if (!isMintActive(tierId)) _revert(MintIsNotActive.selector);
        _;
    }

    /// @dev Only the owner of `tokenId`.
    /// See: {ERC721 - ownerOf}.
    modifier onlyTokenOwner(uint256 tokenId) {
        if (msg.sender != ownerOf(tokenId)) _revert(InvalidOwner.selector);
        _;
    }

    /// @dev When it is not at paused status.
    modifier whenNotPaused() {
        if (isItPaused()) _revert(Paused.selector);
        _;
    }

    ///////// CONSTRUCTOR /////////////////////////////////////////////////////////////////////////O-'

    constructor() ERC721TLC("ERC721TLC Drop","721TLC_DROP") {
        _initializeOwner(msg.sender);
        _setTransferValidator(0xA000027A9B2802E1ddf7000061001e5c005A0000);                                                               
        _setDefaultRoyalty(0xfa98aFe34D343D0e63C4C801EBce01d9D4459ECa, 25);                        // TESTNET !!! 
        _setWithdrawalAddress(0xfa98aFe34D343D0e63C4C801EBce01d9D4459ECa);                         // TESTNET !!! 
    }

    ///////// EXTERNAL FUNCTIONS //////////////////////////////////////////////////////////////////O-'

    ///////// EXTERNAL UPDATE TOKEN LIFE CYCLE BY TOKEN OWNER FUNCTION /////////

    /// @dev Update token life cycle for `tokenId` by the owner of `tokenId`.
    function updateTokenLifeCycle(uint256 tokenId)
        external
        payable
        onlyTokenOwner(tokenId)
        whenNotPaused
    {
       _validateUpdateFee(tokenId);
       _updateTokenLifeCycle(tokenId);
    }

    ///////// EXTERNAL MINT FUNCTIONS /////////

    /// @dev Mints one single token ID from `tierId` given `merkleProof`.
    function whitelistMint(uint256 tierId, bytes32[] calldata merkleProof) 
        external
        payable
        isWhitelistMintTier(tierId)
        isDefinedLifeCycle(tierId)
        onlyMintActive(tierId)
        whenNotPaused
    {
        _validateNumberMinted(msg.sender, tierId);
        _validateMerkleProof(msg.sender, tierId, merkleProof);
        _validateMintFee(tierId);
        _safeMintTier(msg.sender, tierId);
    }

    /// @dev Mints one single token ID from `tierId` for public.
    function publicMint(uint256 tierId)
        external
        payable
        isPublicMintTier(tierId)
        isDefinedLifeCycle(tierId)
        onlyMintActive(tierId)
        whenNotPaused
    {
        _validateNumberMinted(msg.sender, tierId);
        _validateMintFee(tierId);
        _safeMintTier(msg.sender, tierId);
    }

    /// @dev Mints one single token ID from `tierId` for genesis (tierId #1 and/or #2) NFT holder.
    function genesisPublicMint(uint256 tierId)
        external
        payable
        isPublicMintTier(tierId)
        isDefinedLifeCycle(tierId)
        onlyMintActive(tierId)
        whenNotPaused
    {
        _validateNumberMinted(msg.sender, tierId);
        _validateMintFeeForGenesisOwner(msg.sender, tierId);
        _safeMintTier(msg.sender, tierId);
    }

    ///////// EXTERNAL MINT REQUEST BY SIGNER AND MINT BY TRUSTED FORWARDER FUNCTION /////////

    /// @dev Mints one single token ID from `tierId` by trusted forwarder contract to `signer`.
    function claim(address signer, uint256 tierId) 
        external
        isClaimTier(tierId)
        isDefinedLifeCycle(tierId)
        onlyTrustedForwarder
        whenNotPaused
    {
        _validateNumberMinted(signer, tierId);
        _safeMintTier(signer, tierId);
    }

    ///////// EXTERNAL MINT BY OWNER/ADMIN FUNCTIONS /////////

    /// @dev Mints one single token ID from `tierId` to `to`.
    function mintTo(address to, uint256 tierId)
        external
        isValidTier(tierId)
        isDefinedLifeCycle(tierId)
        onlyOwnerOrRoles(1)
        whenNotPaused
    {
        _validateNumberMinted(to, tierId);
        _safeMintTier(to, tierId);
    }

    /// @dev Mints one single token ID from `tierId` to `recipients
    /// Note: Maximum total recipients is 20 (twenty).
    function airdrop(address[] calldata recipients, uint256 tierId)
        external
        isValidTier(tierId)
        isDefinedLifeCycle(tierId)
        onlyOwnerOrRoles(1)
        whenNotPaused
    {
        if (recipients.length > 20) _revert(ExceedsMaxRecipients.selector);
        uint256 i;
        unchecked {
            do {
                _validateNumberMinted(recipients[i], tierId);
                _safeMintTier(recipients[i], tierId);
                ++i;
            } while (i < recipients.length);
        }
    }

    ///////// WITHDRAWAL FUNCTIONS /////////

    /// @dev Withdraw all of the ether balance from contract to `withdrawalAddress`.
    /// See: {TLCLib - forceSafeTransferAllETH}.
    function withdraw()
        external
        onlyOwner
    {
        TLCLib.forceSafeTransferAllETH(withdrawalAddress, 210000);
    }

    /// @dev See: {_setWithdrawalAddress}.
    function setWithdrawalAddress(address addr)
        external
        onlyOwner
    {
        _setWithdrawalAddress(addr);
    }

    ///////// TIER DATA URI AND NFT METADATA UPDATE SETTERS /////////

    /// @dev See {ERC721TLCDataURI - _setTierDataURI}.
    function setTierDataURI(
        uint256 tierId, 
        string calldata name,
        string calldata description,
        string calldata tierName,
        string[2] calldata images,
        string[2] calldata animationURLs
    ) 
        external
        isValidTier(tierId)
        onlyRolesOrOwner(2)  
    {
        _setTierDataURI(tierId, name, description, tierName, images, animationURLs);
    }

    /// @dev See {ERC721TLCToken - _emitMetadataUpdate}.
    function emitMetadataUpdate(uint256 fromTokenId, uint256 toTokenId)
        external
        onlyOwnerOrRoles(2)
    {
        _emitMetadataUpdate(fromTokenId, toTokenId);
    }

    ///////// NFT DROP SETTERS /////////

    /// @dev Sets merkle `root` for `tierId`.
    function setMerkleRoot(uint256 tierId, bytes32 root)
        external
        isWhitelistMintTier(tierId)
        onlyRolesOrOwner(1) 
    {
        _merkleRoot[tierId] = root;
    }

    /// @dev Sets mint `fee` for `tierId`.
    function setMintFee(uint256 tierId, uint256 fee)
        external
        isValidTier(tierId)
        onlyRolesOrOwner(1)
    {
        // See: {ERC721TLCToken - _fee}.
        // _fee index = `tierId` + 10
        LibMap.set(_fee, _add(tierId, 10), uint128(fee));
        emit MintFeeUpdate(tierId, fee);
    }

    /// @dev Sets mint `fee` to mint `tierToMint` with `totalDiscount` in basis points for the owner of tierId #1.
    function setMintFeeForTierOneOwner(uint256 tierToMint, uint256 totalDiscount)
        external
        isPublicMintTier(tierToMint)
        onlyRolesOrOwner(1)
    {
        uint256 _discountedFee = _calculateDiscountedMintFee(tierToMint, totalDiscount);
        // See: {ERC721TLCToken - _fee}.
        // _fee index = `tierToMint` + 15
        LibMap.set(_fee, _add(tierToMint, 15), uint128(_discountedFee));
        emit MintFeeForGenesisOwnerUpdate(1, tierToMint, _discountedFee);
    }
 
    /// @dev Sets mint `fee` to mint `tierToMint` with `totalDiscount` in basis points for the owner of tierId #2.
    function setMintFeeForTierTwoOwner(uint256 tierToMint, uint256 totalDiscount)
        external
        isPublicMintTier(tierToMint)
        onlyRolesOrOwner(1)
    {
        uint256 _discountedFee = _calculateDiscountedMintFee(tierToMint, totalDiscount);
        // See: {ERC721TLCToken - _fee}.
        // _fee index = `tierToMint` + 20
        LibMap.set(_fee, _add(tierToMint, 20), uint128(_discountedFee));
        emit MintFeeForGenesisOwnerUpdate(2, tierToMint, _discountedFee);
    }

    /// @dev Sets mint activity status for `tierId`.
    function setMintStatus(uint256 tierId)
        external
        isValidTier(tierId)
        onlyRolesOrOwner(1)
    {
        bool _state;
        if (!isMintActive(tierId)) {
            _state = true; 
        } else {
            _state = false;
        }
        LibBitmap.toggle(_status, tierId);
        emit MintStatusUpdate(tierId, _state);
    }

    ///////// TOKEN LIFE CYCLE UPDATE FEE SETTER /////////

    /// See: {ERC721TLCToken - _setUpdateFee}.
    function setUpdateFee(uint256 tierId, uint256 fee)
        external
        isValidTier(tierId)
        onlyRolesOrOwner(1)
    {
        _setUpdateFee(tierId, fee);
    }

    ///////// LIFE CYCLE FOR TIER ID SETTERS /////////

    /// @dev See: {TierLIfeCycle- _setLifeCycle}.
    function setLifeCycle(uint256 tierId, uint256 numberOfDays)                                 
        external
        isValidTier(tierId)
        onlyRolesOrOwner(2)
    {
        _setLifeCycle(tierId, numberOfDays);
    }

    /// @dev See: {TierLifeCycle - _setStartOfLifeCycle}.
    /// Note: updateFee for `tierId` must be non-zero value.
    function setStartOfLifeCycle(uint256 tierId, uint256 timestamp)
        external
        isValidTier(tierId)
        onlyRolesOrOwner(2)
    {
        if (updateFee(tierId) == 0) _revert(UndefinedFee.selector);
        _setStartOfLifeCycle(tierId, timestamp);
    }

    /// @dev See: {TierLifeCycle - _setLifeCycleToLive}.
    function setLifeCycleToLive(uint256 tierId)
        external
        isValidTier(tierId)
        onlyRolesOrOwner(2)
    {
        _setLifeCycleToLive(tierId);
        if (totalSupply() != 0) {
            _emitMetadataUpdate(_startTokenId(), totalSupply());
        }
    }

    /// @dev See: {TierLifeCycle - _pauseLifeCycle}.
    function pauseLifeCycle(uint256 tierId, uint256 timestamp)
        external
        isValidTier(tierId)
        onlyRolesOrOwner(2)
    {
        _pauseLifeCycle(tierId, timestamp);
    }

    /// @dev See: {TierLifeCycle - _unpauseLifeCycle}.
    function unpauseLifeCycle(uint256 tierId)
        external
        isValidTier(tierId)
        onlyRolesOrOwner(2)
    {
        _unpauseLifeCycle(tierId);
        _emitMetadataUpdate(_startTokenId(), totalSupply());
    }

    /// @dev {TierLifeCycle - _setEndOfLifeCycle}.
    function setEndOfLifeCycle(uint256 tierId, uint256 timestamp)
        external
        isValidTier(tierId)
        onlyRolesOrOwner(2)
    {
        _setEndOfLifeCycle(tierId, timestamp);
    }

    /// @dev {TierLifeCycle - _finishLifeCycle}.
    function finishLifeCycle(uint256 tierId)
        external
        isValidTier(tierId)
        onlyRolesOrOwner(2)
    {
        // Reset token life cycle update fee for `tierId` to 0.
        _setUpdateFee(tierId, 0);
        _finishLifeCycle(tierId);
        _emitMetadataUpdate(_startTokenId(), totalSupply());
    }

    ///////// ERC2981 SETTER OPERATIONS /////////

    /// @dev See {ERC2981 - _setDefaultRoyalty}. 
    function setDefaultRoyalty(address receiver, uint96 feeNumerator)
        external
        onlyRolesOrOwner(2)
    {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /// @dev See {ERC2981 - _deleteDefaultRoyalty}.
    function resetDefaultRoyalty()
        external
        onlyRolesOrOwner(2)
    {
        _deleteDefaultRoyalty();
    }

    ///////// ERC721 TRANSFER VALIDATOR OPERATIONS /////////

    /// @dev See: {ERC721TransferValidator - _setTransferValidator}.
    function setTransferValidator(address validator)
        external
        onlyRolesOrOwner(2)
    {
        _setTransferValidator(validator);
    }

    /// @dev See: {ERC721TransferValidator - _resetTransferValidator}.
    function resetTransferValidator()
        external
        onlyRolesOrOwner(2)
    {
        _resetTransferValidator();
    }

    ///////// ERC2771 CONTEXT SETTER OPERATIONS /////////

    /// @dev See {ERC2771Context - _setTrustedForwarder}
    function setTrustedForwarder(address forwarder)
        external
        onlyOwnerOrRoles(1)
    {
        _setTrustedForwarder(forwarder);
    }

    /// @dev See {ERC2771Context - _resetTrustedForwarder}
    function resetTrustedForwarder()
        external
        onlyOwnerOrRoles(1)
    {
        _resetTrustedForwarder();
    }

    ///////// MULTICALL OPERATION /////////

    /// @dev Receives and executes a batch of function calls on this contract.
    /// @dev See: {_multicall}
    function multicall(bytes[] calldata data)
        external
        onlyOwnerOrRoles(1)
        returns (bytes[] memory) 
    {
        _multicall(data);
    }

    ///////// PAUSED STATUS OPERATION /////////

    /// @dev Sets paused status toggle.
    function setPausedStatus()
        external
        onlyOwner
    {
        LibBitmap.toggle(_status, 0);
    }

    ///////// PUBLIC GETTER FUNCTIONS /////////////////////////////////////////////////////////////O-'
    
    //// @dev Returns true if this contract implements the interface defined by `interfaceId`.
    /// See: https://eips.ethereum.org/EIPS/eip-165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override (ERC2981, ERC721TLCToken, ERC721)
        returns (bool result) 
    {
        return
            interfaceId == 0x2a55205a ||                    // ERC2981                   
            interfaceId == 0xad0d7f6c ||                    // ICreatorToken                
            ERC721TLCToken.supportsInterface(interfaceId);
    }
    
    /// @dev Returns merkle root for `tierId`.
    function merkleRoot(uint256 tierId) public view returns (bytes32) {
        return _merkleRoot[tierId];
    }

    /// @dev Returns mint fee for `tierId`.
    function mintFee(uint256 tierId) public view returns (uint256) {
        return uint256(LibMap.get(_fee, _add(tierId, 10))); 
    }

    /// @dev Returns discounted mint fee for `tierId` for the owner of `tierId` #1.
    function mintFeeForTierOneOwner(uint256 tierId) public view returns (uint256) {
        return uint256(LibMap.get(_fee, _add(tierId, 15))); 
    }

    /// @dev Returns discounted mint fee for `tierId` for the owner of `tierId` #2.
    function mintFeeForTierTwoOwner(uint256 tierId) public view returns (uint256) {
        return uint256(LibMap.get(_fee, _add(tierId, 20)));
    }

    /// @dev Returns number minted per `tierId` for `addr`.
    function numberMinted(address addr, uint256 tierId) public view returns (uint256) {
        return _numberMinted[addr][tierId];
    }

    /// @dev Returns if `tierId` is owned by `addr`. true if it's owned, false otherwise.
    /// See: {ERC721TLC - tiersOfOwner}.
    function isTierOwned(address addr, uint256 tierId) public view returns (bool result) {
        uint256[] memory _tiersOfOwner = tiersOfOwner(addr);
        LibSort.sort(_tiersOfOwner);
        (result, ) = LibSort.searchSorted(_tiersOfOwner, tierId);
    }

    /// @dev Returns mint activity status for `tierId`. true if it's active, false otherwise.
    function isMintActive(uint256 tierId) public view returns (bool) {
        return LibBitmap.get(_status, tierId);
    }

    /// @dev Returns paused status. true if it's paused, false otherwise.
    function isItPaused() public view returns (bool) {
        return LibBitmap.get(_status, 0);
    }

    ///////// INTERNAL FUNCTIONS //////////////////////////////////////////////////////////////////O-'

    /// @dev See {ERC721 - _beforeTokenTransfer}.
    function _beforeTokenTransfer(address from, address to, uint256 id)
        internal
        virtual
        override
    {
        if (from != address(0)) {
            if (to != address(0)) {
                if (_transferValidator != address(0)) {
                    IERC721TransferValidator(_transferValidator).validateTransfer(
                        msg.sender, from, to, id
                    );
                }
            }
        }
    }

    /// @dev Sets `addr` for withdrawal address.
    function _setWithdrawalAddress(address addr) internal {
        withdrawalAddress = addr;
    }

    ///////// PRIVATE FUNCTIONS ///////////////////////////////////////////////////////////////////O-'

    ///////// PRIVATE DISCOUNTED MINT FEE SETTER //////////

    /// @dev Calculate discounted mint fee for `tierId` with `totalDiscount` in basis points.
    function _calculateDiscountedMintFee(uint256 tierId, uint256 totalDiscount)
        private
        view 
        returns (uint256 result)
    {
        if (mintFee(tierId) == 0) _revert(UndefinedFee.selector);
        // Max basis points (BPS) is 10000
        if (totalDiscount > 10000) _revert(ExceedsMaxBPS.selector);
        uint256 _discount = (mintFee(tierId) * totalDiscount) / 10000;
        result = _sub(mintFee(tierId), _discount);
    }

    ///////// PRIVATE MINT VALIDATOR LOGICS //////////

    /// @dev Number minted from `addr` for `tierId` validator.
    /// Note: Maximum number minted is 1 (one).
    function _validateNumberMinted(address addr, uint256 tierId) private {
        if (_numberMinted[addr][tierId] == 1) {
            _revert(ExceedsMaxNumberMinted.selector);
        }
        unchecked { 
            ++_numberMinted[addr][tierId]; 
        }
    }

    /// @dev Merkle proof validator.
    /// See: {TLCLib - verifyMerkleLeaf}.
    function _validateMerkleProof(
        address addr,
        uint256 tierId,
        bytes32[] calldata merkleProof
    ) private view {
        // Leaf or node is the hashes of (`to`, `tierId`)
        // Ref: https://github.com/OpenZeppelin/merkle-tree?tab=readme-ov-file#leaf-hash
        bytes32 _leaf = keccak256(bytes.concat(keccak256(abi.encode(addr, tierId))));
        bool _isValid = TLCLib.verifyMerkleLeaf(merkleProof, _merkleRoot[tierId], _leaf);
        if (!_isValid) _revert(InvalidMerkleProof.selector);
    }

    /// @dev Mint fee for `tierId` validator.
    function _validateMintFee(uint256 tierId) private {
        if (mintFee(tierId) != 0) {
            _validateMsgValue(mintFee(tierId));
        }
    }

    /// @dev Mint fee from `tierId` for the owner of tierId #1 and/or tierId #2 validator.
    /// 
    /// Conditions:
    /// - Mint fee and mint fee for tier one owner and tier two owner for `tierId` 
    ///   must be non-zero value.
    /// - For the owner of tier #1 and #2, {mintFeeForTierOneOwner}.
    /// - For the owner of tier #1 only, {mintFeeForTierOneOwner}.
    /// - For the owner of tier #2 only, {mintFeeForTierTwoOwner}.
    ///```
    function _validateMintFeeForGenesisOwner(address owner, uint256 tierId) private {
        if (mintFee(tierId) == 0) _revert(UndefinedFee.selector);
        if (mintFeeForTierOneOwner(tierId) == 0) _revert(UndefinedFee.selector);
        if (mintFeeForTierTwoOwner(tierId) == 0) _revert(UndefinedFee.selector);

        if (isTierOwned(owner, 1) && isTierOwned(owner, 2)) {
            _validateMsgValue(mintFeeForTierOneOwner(tierId));
        } else if (isTierOwned(owner, 1)) {
            _validateMsgValue(mintFeeForTierOneOwner(tierId));
        } else if (isTierOwned(owner, 2)) {
            _validateMsgValue(mintFeeForTierTwoOwner(tierId));
        } else {
            _revert(InvalidOwner.selector);
        }   
    }
        
    ///////// PRIVATE HELPER FUNCTIONS /////////

    /// @dev `DELEGATECALL` with the current contract to each calldata in `data`.
    /// Source: https://github.com/Vectorized/solady/blob/main/src/utils/Multicallable.sol#L32
    function _multicall(bytes[] calldata data) private returns (bytes[] memory) {
        assembly {
            mstore(0x00, 0x20)
            mstore(0x20, data.length) // Store `data.length` into `results`.
            // Early return if no data.
            if iszero(data.length) { return(0x00, 0x40) }

            let results := 0x40
            // `shl` 5 is equivalent to multiplying by 0x20.
            let end := shl(5, data.length)
            // Copy the offsets from calldata into memory.
            calldatacopy(0x40, data.offset, end)
            // Offset into `results`.
            let resultsOffset := end
            // Pointer to the end of `results`.
            end := add(results, end)

            for {} 1 {} {
                // The offset of the current bytes in the calldata.
                let o := add(data.offset, mload(results))
                let m := add(resultsOffset, 0x40)
                // Copy the current bytes from calldata to the memory.
                calldatacopy(
                    m,
                    add(o, 0x20), // The offset of the current bytes' bytes.
                    calldataload(o) // The length of the current bytes.
                )
                if iszero(delegatecall(gas(), address(), m, calldataload(o), codesize(), 0x00)) {
                    // Bubble up the revert if the delegatecall reverts.
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                // Append the current `resultsOffset` into `results`.
                mstore(results, resultsOffset)
                results := add(results, 0x20)
                // Append the `returndatasize()`, and the return data.
                mstore(m, returndatasize())
                returndatacopy(add(m, 0x20), 0x00, returndatasize())
                // Advance the `resultsOffset` by `returndatasize() + 0x20`,
                // rounded up to the next multiple of 32.
                resultsOffset :=
                    and(add(add(resultsOffset, returndatasize()), 0x3f), 0xffffffffffffffe0)
                if iszero(lt(results, end)) { break }
            }
            return(0x00, add(resultsOffset, 0x40))
        }
    }
}