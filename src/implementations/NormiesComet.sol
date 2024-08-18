// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*                                                                  
 _______ _______ _______ _______ _______ 
|\     /|\     /|\     /|\     /|\     /|
| +---+ | +---+ | +---+ | +---+ | +---+ |
| |   | | |   | | |   | | |   | | |   | |
| |N  | | |S  | | |C  | | |M  | | |T  | |
| +---+ | +---+ | +---+ | +---+ | +---+ |
|/_____\|/_____\|/_____\|/_____\|/_____\|

*/

import "../ERC721T.sol";
import "../extensions/ERC721TransferValidator.sol";
import "../extensions/ERC2771Context.sol";
import "solady/tokens/ERC2981.sol";
import "solady/auth/OwnableRoles.sol";
import "solady/utils/LibSort.sol";

interface IERC721TransferValidator {
    function validateTransfer(address caller, address from, address to, uint256 tokenId) external view;
}

/// @notice POAP implementation contract by Normies (https://normi.es)
/// @author 0xkuwabatake (@0xkuwabatake)
contract NormiesComet is
    ERC721T,
    ERC721TransferValidator,
    ERC2771Context,
    ERC2981,
    OwnableRoles
{
    // ============================================================================================
    //          O-' CONSTANT
    // ============================================================================================

    /// @dev Maximum number minted per wallet address for each tier ID is 1 (one).
    uint256 private constant _MAX_NUMBER_MINTED = 1;

    /// @dev Maximum airdrop recipients in one transaction.
    uint256 private constant _MAX_AIRDROP_RECIPIENTS = 20;

    // ============================================================================================
    //          O-' STORAGE
    // ============================================================================================

    /// @dev Mapping from `tierId` => `tierURI`.
    mapping (uint256 => string) internal _tierURI;

    /// @dev Mapping from signer or recipient `address` => `tierId` => number minted token ID.
    mapping(address => mapping(uint256 => uint256)) private _numberMinted;

    /// @dev Paused status. true if it's paused, false otherwise.
    bool private _pausedStatus;

    // ============================================================================================
    //          O-' ERC-4906 EVENTS
    // ============================================================================================

    /// @dev Emitted when the metadata for `tokenId` is updated.
    event MetadataUpdate(uint256 tokenId);

    /// @dev Emitted when batch of metadata `fromTokenId` to `toTokenId` is updated.
    event BatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId);

    // ============================================================================================
    //          O-' CUSTOM EVENT
    // ============================================================================================

    /// @dev Emitted when `tierURI` is updated for `tierId`.
    event TierURIUpdate (uint256 indexed tierId, string tierURI);

    // ============================================================================================
    //          O-' CUSTOM ERRORS
    // ============================================================================================

    /// @dev Revert with an error if an address exceeds maximum number minted for tier ID.
    error ExceedsMaxNumberMinted();

    /// @dev Revert with an error if the maximum number of airdrop recipients is exceeded.
    error ExceedsMaxRecipients();

    /// @dev Revert with an error if between two array-length arguments is mismatch.
    error ArrayLengthMismatch();

    /// @dev Revert with an error if tier ID is invalid.
    error InvalidTierId();

    /// @dev Revert with an error if it's in paused state.
    error Paused();

    // ============================================================================================
    //          O-' MODIFIERS
    // ============================================================================================

    /// @dev Tier ID can not be 0 (zero).
    modifier mustComply(uint256 tierId) {
        if (tierId == 0) _revert(InvalidTierId.selector);
        _;
    }

    /// @dev When not in paused status.
    modifier whenNotPaused() {
        if (isPaused()) _revert(Paused.selector);
        _;
    }

    // ============================================================================================
    //          O-' CONSTRUCTOR
    // ============================================================================================

    constructor() ERC721T("Normies Spaceventure Comet","NSCMT") {
        _initializeOwner(tx.origin); 
        _setTransferValidator(0xA000027A9B2802E1ddf7000061001e5c005A0000);                                                               
        _setDefaultRoyalty(0x351e20B00e2B42CC34Aa58d0D96aA00d4D91dabc, 25); 
    }

    // ============================================================================================
    //          O-' EXTERNAL FUNCTIONS
    // ============================================================================================

    ///////// NFT CLAIM BY SIGNER & DROPPED BY TRUSTED FORWARDER OPERATION /////////

    /// @dev Mints single quantity of token ID from `tierId` by trusted forwarder to `signer`.
    function claim(address signer, uint256 tierId) 
        external
        mustComply(tierId)
        onlyTrustedForwarder
        whenNotPaused
    {
        _validateNumberMinted(signer, tierId);
        _safeMintTier(signer, tierId);
    }

    // ============================================================================================
    //          O-' EXTERNAL ONLY OWNER/ADMIN FUNCTIONS
    // ============================================================================================

    ///////// AIRDROP AND MINT TO OPERATIONS /////////

    /// @dev Mints single quantity of token ID from `tierId` to `to`.
    function mintTo(address to, uint256 tierId)
        external
        mustComply(tierId)
        onlyOwnerOrRoles(1)
        whenNotPaused
    {
        _validateNumberMinted(to, tierId);
        _safeMintTier(to, tierId);
    }

    /// @dev Mints single quantity of token ID from `tierId` to `recipients`.
    function airdrop(address[] calldata recipients, uint256 tierId) 
        external
        mustComply(tierId)
        onlyOwnerOrRoles(1)
        whenNotPaused 
    {
        if (recipients.length > _MAX_AIRDROP_RECIPIENTS) _revert(ExceedsMaxRecipients.selector);
        uint256 i;
        unchecked {
            do {
                _validateNumberMinted(recipients[i], tierId);
                _safeMintTier(recipients[i], tierId);
                ++i;
            } while (i < recipients.length);
        }
    }

    ///////// NFT METADATA OPERATIONS /////////

    /// @dev Sets 'tierURIs' as the URI of 'tierIds'.
    /// Note: It DOES NOT check if `tierURIs` may contain an empty string (non-existent metadata).
    function setBatchTierURI(uint256[] calldata tierIds, string[] calldata tierURIs)
        external
        onlyRolesOrOwner(2) 
    {
        if (tierIds.length != tierURIs.length) _revert(ArrayLengthMismatch.selector);
        uint256 i;
        unchecked {
            do {
                if (tierIds[i] == 0) _revert(InvalidTierId.selector);
                _setTierURI(tierIds[i], tierURIs[i]);
                ++i;
            } while (i < tierIds.length);
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

    ///////// ERC-2981 OPERATIONS  /////////

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

    ///////// ERC-2771 CONTEXT SETTER OPERATIONS /////////

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

    // ============================================================================================
    //          O-' PUBLIC GETTER FUNCTIONS
    // ============================================================================================
    
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

    /// @dev Returns the Uniform Resource Identifier (URI) for `tokenId` from tier ID.
    /// See: {ERC721Metadata - tokenURI}.
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) _revert(TokenDoesNotExist.selector);
        uint256 _tierId = tierId(tokenId);
        return _tierURI[_tierId];
    }

    /// @dev Returns tier URI for `tierId`.
    function tierURI(uint256 tierId) public view returns (string memory) {
        return _tierURI[tierId];
    }

    /// @dev Returns number minted from `addr` for `tierId`.
    function numberMinted(address addr, uint256 tierId) public view returns (uint256) {
        return _numberMinted[addr][tierId];
    }

    /// @dev Returns if `tierId` is owned by `addr`. true if it's owned, false otherwise.
    function isTierOwned(address addr, uint256 tierId) public view returns (bool result) {
        uint256[] memory _tiersOfOwner = tiersOfOwner(addr);
        LibSort.sort(_tiersOfOwner);
        (result, ) = LibSort.searchSorted(_tiersOfOwner, tierId);
    }

    /// @dev Returns paused status. true if it's paused, false otherwise.
    function isPaused() public view returns (bool) {
        return _pausedStatus;
    }

    // ============================================================================================
    //          O-' INTERNAL FUNCTIONS
    // ============================================================================================

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

    ///////// INTERNAL MINT VALIDATOR LOGIC FUNCTION /////////

    /// @dev Number minted from `addr` for `tierId` validator.
    function _validateNumberMinted(address addr, uint256 tierId) internal {
        if (_numberMinted[addr][tierId] == _MAX_NUMBER_MINTED) {
            _revert(ExceedsMaxNumberMinted.selector);
        }
        unchecked { 
            ++_numberMinted[addr][tierId]; 
        }
    }

    ///////// INTERNAL TIER URI SETTER FUNCTION /////////

    /// @dev Sets `uri` as NFT metadata for `tierId`.
    function _setTierURI(uint256 tierId, string memory uri) internal {
        _tierURI[tierId] = uri;
        emit TierURIUpdate(tierId, uri);
    }

    // ============================================================================================
    //          O-' PRIVATE HELPER FUNCTION
    // ============================================================================================

    /// @dev Helper function for more efficient reverts.
    function _revert(bytes4 errorSelector) private pure {
        assembly {
            mstore(0x00, errorSelector)
            revert(0x00, 0x04)
        }
    }
}