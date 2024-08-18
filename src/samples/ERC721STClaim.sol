// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../ERC721ST.sol";
import "../extensions/ERC721TransferValidator.sol";
import "../extensions/ERC2771Context.sol";
import "solady/tokens/ERC2981.sol";
import "solady/auth/OwnableRoles.sol";

interface IERC721TransferValidator {
    function validateTransfer(address caller, address from, address to, uint256 tokenId) external view;
}

interface IPOAPContract {
    function isTierOwned(address addr, uint256 tierId) external view returns (bool result);
}

/// @author 0xkuwabatake (@0xkuwabatake)
contract ERC721STClaim is
    ERC721ST,
    ERC721TransferValidator,
    ERC2771Context,
    ERC2981,
    OwnableRoles
{
    IPOAPContract public immutable poapContract;

    ///////// CONSTANTS ///////////////////////////////////////////////////////////////////////////O-'

    /// @dev Maximum number minted per wallet address for each tier ID is 1 (one).
    uint256 private constant _MAX_NUMBER_MINTED = 1;

    /// @dev Maximum airdrop recipients in one transaction.
    uint256 private constant _MAX_AIRDROP_RECIPIENTS = 3;

    ///////// STORAGE /////////////////////////////////////////////////////////////////////////////O-'

    /// @dev Mapping from signer or recipient `address` => `tierId` => number minted token ID.
    mapping(address => mapping(uint256 => uint256)) private _numberMinted;

    /// @dev Mapping from `tierId` => `subTierId` => `subTierId` claimed status.
    mapping(uint256 => mapping(uint256 => bool)) private _subTierClaimed;

    /// @dev Paused status. true if it's paused, false otherwise.
    bool private _pausedStatus;

    ///////// ERC-4906 EVENTS /////////////////////////////////////////////////////////////////////O-'

    /// @dev Emitted when the metadata for `tokenId` is updated.
    event MetadataUpdate(uint256 tokenId);

    /// @dev Emitted when batch of metadata `fromTokenId` to `toTokenId` is updated.
    event BatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId);

    ///////// CUSTOM ERRORS ///////////////////////////////////////////////////////////////////////O-'

    /// @dev Revert with an error if not the owner of tier ID from POAP contract.
    error InvalidOwnerOfTierIdFromPoapContract();

    /// @dev Revert with an error if an address exceeds maximum number minted for tier ID.
    error ExceedsMaxNumberMinted();

    /// @dev Revert with an error if the maximum number of airdrop recipients is exceeded.
    error ExceedsMaxRecipients();

    /// @dev Revert with an error if sub-tier ID from tier ID had been claimed.
    error SubTierAlreadyClaimed();

    /// @dev Revert with an error if between two array-length arguments is mismatch.
    error ArrayLengthMismatch();

    /// @dev Revert with an error if sub-tier ID is invalid.
    error InvalidSubTierId();

    /// @dev Revert with an error if tier ID is invalid.
    error InvalidTierId();

    /// @dev Revert with an error if it's in paused state.
    error Paused();

    ///////// MODIFIERS ///////////////////////////////////////////////////////////////////////////O-'

    /// @dev Tier ID or sub-tier ID can not be 0 and sub-tierId maximum value is 3 (three).
    modifier mustComply(uint256 tierId, uint256 subTierId) {
        if (tierId == 0) _revert(InvalidTierId.selector);
        if (subTierId == 0 || subTierId > 3) _revert(InvalidSubTierId.selector);
        _;
    }

    /// @dev When not in paused status.
    modifier whenNotPaused() {
        if (isPaused()) _revert(Paused.selector);
        _;
    }

    ///////// CONSTRUCTOR /////////////////////////////////////////////////////////////////////////O-'

    constructor() ERC721ST("ERC721ST Claim","ST_CLAIM") {
        _initializeOwner(tx.origin);
        _setTransferValidator(0xA000027A9B2802E1ddf7000061001e5c005A0000);                                                               
        _setDefaultRoyalty(0xfa98aFe34D343D0e63C4C801EBce01d9D4459ECa, 25);
        poapContract = IPOAPContract(0xf108a39b00FCA4df3e7405A1784CC966D9612258);
    }

    ///////// EXTERNAL FUNCTIONS //////////////////////////////////////////////////////////////////O-'

    ///////// NFT CLAIM BY SIGNER & DROPPED BY TRUSTED FORWARDER OPERATION /////////

    /// @dev Mints single quantity of token ID for `subTierId` from `tierId` by trusted forwarder to `signer`.
    function claim(address signer, uint256 tierId, uint256 subTierId)
        external
        mustComply(tierId, subTierId)
        onlyTrustedForwarder 
        whenNotPaused
    {
        _validateNumberMinted(signer, tierId);
        _validateTierOfOwner(signer, tierId);
        _validateClaimedSubTier(tierId, subTierId);
        _safeMintSubTier(signer, tierId, subTierId);
    }

    ///////// EXTERNAL ONLY OWNER/ADMIN FUNCTIONS /////////////////////////////////////////////////O-'

    ///////// AIRDROP AND MINT TO OPERATIONS /////////

    /// @dev Mints single quantity of token ID for `subTierId` from `tierId` to `to`.
    function mintTo(address to, uint256 tierId, uint256 subTierId) 
        external
        mustComply(tierId, subTierId)
        onlyOwnerOrRoles(1) 
        whenNotPaused
    {
        _validateNumberMinted(to, tierId);
        _validateTierOfOwner(to, tierId);
        _validateClaimedSubTier(tierId, subTierId);
        _safeMintSubTier(to, tierId, subTierId);
    }

    /// @dev Mints single token ID for `subTierId` from `tierId` to `recipients`.
    function airdrop(address[] calldata recipients, uint256 tierId, uint256[] calldata subTierIds) 
        external
        onlyOwnerOrRoles(1)
        whenNotPaused
    {
        if (tierId == 0) _revert(InvalidTierId.selector);
        if (recipients.length > _MAX_AIRDROP_RECIPIENTS) _revert(ExceedsMaxRecipients.selector);
        if (recipients.length != subTierIds.length) _revert(ArrayLengthMismatch.selector);
        uint256 i;
        unchecked {
            do {
                if (subTierIds[i] == 0 || subTierIds[i] > 3) _revert(InvalidSubTierId.selector);
                _validateNumberMinted(recipients[i], tierId);
                _validateTierOfOwner(recipients[i], tierId); 
                _validateClaimedSubTier(tierId, subTierIds[i]);
                _safeMintSubTier(recipients[i], tierId, subTierIds[i]);
                ++i;
            } while (i < recipients.length);
        }
    }
    
    ///////// NFT METADATA OPERATIONS /////////

    /// @dev Sets 'subTierURIs' as the URI of 'subTierIds' from `tierId`.
    /// Note: It DOES NOT check if `tierURIs` may contain an empty string (non-existent metadata).
    function setBatchSubTierURI(
        uint256 tierId,
        uint256[] calldata subTierIds,
        string[] calldata subTierURIs
    ) external onlyRolesOrOwner(2) {
        if (tierId == 0) _revert(InvalidTierId.selector);
        if (subTierIds.length != subTierURIs.length) _revert(ArrayLengthMismatch.selector);
        uint256 i;
        unchecked {
            do {
                if (subTierIds[i] == 0 || subTierIds[i] > 3) _revert(InvalidSubTierId.selector);
                _setSubTierURI(tierId, subTierIds[i], subTierURIs[i]);
                ++i;
            } while (i < subTierIds.length);
        }

        if (totalSupply() != 0) {
            emit BatchMetadataUpdate(_startTokenId(), totalSupply());
        }
    }

    /// @dev Emits metadata update event `fromTokenId` to `toTokenId` from ERC-4906.
    /// See: https://eips.ethereum.org/EIPS/eip-4906
    function emitMetadataUpdate(uint256 fromTokenId, uint256 toTokenId)
        external
        onlyOwnerOrRoles(2)
    {
        if (fromTokenId == toTokenId) {
            emit MetadataUpdate(fromTokenId);
        } else {
            emit BatchMetadataUpdate(fromTokenId, toTokenId);
        }
    }

    ///////// ERC2981 OPERATIONS /////////

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

    ///////// ERC-721 TRANSFER VALIDATOR SETTER OPERATIONS /////////

    /// @dev See {ERC721TransferValidator - _setTransferValidator}.
    function setTransferValidator(address validator)
        external
        onlyRolesOrOwner(2)
    {
        _setTransferValidator(validator);
    }

    /// @dev See {ERC721TransferValidator - _resetTransferValidator}.
    function resetTransferValidator()
        external
        onlyRolesOrOwner(2)
    {
        _resetTransferValidator();
    }

    ///////// ERC2771 CONTEXT OPERATIONS /////////

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

    ///////// PAUSED STATUS OPERATION /////////

    /// @dev Sets paused `state` toggle. true if it's paused, false otherwise.
    function setPausedStatus(bool state)
        external
        onlyOwner
    {
        _pausedStatus = state;
    }

    ///////// PUBLIC GETTER FUNCTIONS /////////////////////////////////////////////////////////////O-'

    //// @dev Returns true if this contract implements the interface defined by `interfaceId`.
    /// See: https://eips.ethereum.org/EIPS/eip-165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override (ERC2981, ERC721)
        returns (bool result) 
    {
        return
            interfaceId == 0x49064906 ||            // ERC4906
            interfaceId == 0x2a55205a ||            // ERC2981
            interfaceId == 0xad0d7f6c ||            // ICreatorToken
            ERC721.supportsInterface(interfaceId);  
    }

    /// @dev Returns number minted from `addr` for `tierId`.
    function numberMinted(address addr, uint256 tierId) public view returns (uint256) {
        return _numberMinted[addr][tierId];
    }

    /// @dev Returns claimed `subTierId` status. true is claimed, false otherwise.
    function isSubTierClaimed(uint256 tierId, uint256 subTierId) public view returns (bool) {
        return _subTierClaimed[tierId][subTierId];
    }

    /// @dev Returns paused status. true if it's paused, false otherwise.
    function isPaused() public view returns (bool) {
        return _pausedStatus;
    }

    ///////// INTERNAL FUNCTIONS ///////////////////////////////////////////////////////////////////O-'

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

    ///////// INTERNAL MINT VALIDATOR LOGIC FUNCTIONS /////////

    /// @dev Number minted from `to` for `subTierId` from `tierId` validator.
    function _validateNumberMinted(address to, uint256 tierId) internal {
        if (_numberMinted[to][tierId] == _MAX_NUMBER_MINTED) {
            _revert(ExceedsMaxNumberMinted.selector);
        }
        unchecked { 
            ++_numberMinted[to][tierId]; 
        }
    }

    /// @dev `tierId` owned by `addr` from POAP contract validator.
    function _validateTierOfOwner(address addr, uint256 tierId) internal view {
        if (!poapContract.isTierOwned(addr, tierId)) {
            _revert(InvalidOwnerOfTierIdFromPoapContract.selector);
        } 
    }

    /// @dev Claimed `subTierId` status from `tierId` validator.
    function _validateClaimedSubTier(uint256 tierId, uint256 subTierId) internal {
        if (_subTierClaimed[tierId][subTierId]) _revert(SubTierAlreadyClaimed.selector);
        _subTierClaimed[tierId][subTierId] = true;
    }
}