// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "solady/tokens/ERC721.sol";

/// @notice Simple but highly customized ERC721 contract extension to create a tier-based NFT collection.
/// @author 0xkuwabatake(@0xkuwabatake)
abstract contract ERC721ST is ERC721 {

    ///////// STORAGE /////////////////////////////////////////////////////////////////////////////O-'

    /// @dev The next token ID to be minted.
    uint256 private _currentIndex;

    /// @dev Token name.
    string private _name;

    /// @dev Token symbol.
    string private _symbol;

    /// @dev Mapping from tier ID and sub-tierID => sub-tier URI.
    mapping (uint256 => mapping(uint256 => string)) internal _subTierURI;

    ///////// CUSTOM EVENTS ///////////////////////////////////////////////////////////////////////O-'

    /// @dev Emitted when `tokenId` is minted and set to `subTierId` from `tierId` at `atTimestamp`.
    event SubTierSet (
        uint256 indexed tokenId,
        uint256 indexed tierId,
        uint256 indexed subTierId,
        uint256 atTimestamp
    );

    /// @dev Emitted when `subTierURI` is updated for `subTierId` from `tierId`.
    event SubTierURIUpdate (uint256 indexed tierId, uint256 indexed subTierId, string subTierURI);

    ///////// CONSTRUCTOR /////////////////////////////////////////////////////////////////////////O-'

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _currentIndex = _startTokenId();
    }

    ///////// ERC721 METADATA /////////////////////////////////////////////////////////////////////O-'

    /// @dev Returns the token collection name.
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @dev Returns the token collection symbol.
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /// @dev Returns the Uniform Resource Identifier (URI) for `tokenId` from tier ID.
    /// See: {ERC721Metadata - tokenURI}.
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) _revert(TokenDoesNotExist.selector);
        return _subTierURI[uint256(_tierId(tokenId))][uint256(_subTierId(tokenId))];
    }

    ///////// PUBLIC GETTER FUNCTIONS /////////////////////////////////////////////////////////////O-'

    /// @dev Returns tier ID and sub-tier ID from `tokenId`.
    function subTierId(uint256 tokenId)
        public
        view
        returns (uint256 tier, uint256 subTier)
    {
        return (uint256(_tierId(tokenId)), uint256(_subTierId(tokenId)));
    }

    /// @dev Returns sub-tier URI for `subTier` from`tier`.
    function subTierURI(uint256 tier, uint256 subTier)
        public
        view
        returns (string memory)
        {
        return _subTierURI[tier][subTier];
    }

    /// @dev Returns token timestamp as seconds since unix epoch for `tokenId`.
    function tokenTimestamp(uint256 tokenId) public view returns (uint256) {
        return uint256(_tokenTimestamp(tokenId));
    }

    /// @dev Returns token IDs owned by `owner`.
    function tokensOfOwner(address owner) public view returns (uint256[] memory) {
        uint256 _balance = balanceOf(owner);
        uint256[] memory _tokenIds = new uint256[](_balance);
        uint256 i;
        uint256 j = _startTokenId();

        while (i < _balance) {
            if (_exists(j) && ownerOf(j) == owner) {
                _tokenIds[i++] = j;
            }
            unchecked { ++j; }
        }
        return _tokenIds;
    }

    /// @dev Returns the total number of tokens in existence.
    function totalSupply() public view returns (uint256) {
        unchecked {
            return _currentIndex - _startTokenId();
        }
    }

    ///////// INTERNAL SAFE MINT LOGIC FUNCTION ///////////////////////////////////////////////////O-'

    /// @dev Safe mints single quantity of token ID to `to` and set to `subTier` from `tier`.
    /// Note: `tier` and `subTier` CANNOT be zero and they MUST be validated at child contract.
    function _safeMintSubTier(
        address to,
        uint256 tier,
        uint256 subTier
    ) internal {
        uint256 _tokenId = _nextTokenId();
        unchecked {
            ++_currentIndex;
        }
        _setMintExtraData(_tokenId, tier, subTier);
        _safeMint(to, _tokenId);

        emit SubTierSet(_tokenId, tier, subTier, block.timestamp);
    }

    ///////// INTERNAL MINT EXTRA DATA SETTER FUNCTION ////////////////////////////////////////////O-'

    /// @dev Sets mint extra data for`tokenId` to `subTier` from `tier` and `block.timestamp`.
    /// See: {ERC721 - _setExtraData}.
    function _setMintExtraData(
        uint256 tokenId,
        uint256 tier,
        uint256 subTier
    ) internal {
        uint96 _packed = uint96(tier) |                                // 3 bytes - Tier ID                     
        uint96(subTier) << 24 |                                        // 1 byte  - Sub-tier ID                                        
        uint96(block.timestamp) << 32;                                 // 8 bytes - block.timestamp                          
        _setExtraData(tokenId, _packed);
    }

    ///////// INTERNAL SUB-TIER URI SETTER FUNCTION ///////////////////////////////////////////////O-'

    /// @dev Sets 'uri' as NFT metadata 'subTier' from `tier`.
    function _setSubTierURI(
        uint256 tier,
        uint256 subTier,
        string memory uri
    ) internal {
        _subTierURI[tier][subTier] = uri;
        emit SubTierURIUpdate(tier, subTier, uri);
    }

    ///////// INTERNAL MINT EXTRA DATA GETTER FUNCTIONS ///////////////////////////////////////////O-'

    /// @dev Returns tier ID for `tokenId`. 
    /// See: {ERC721 - _getExtraData}.
    function _tierId(uint256 tokenId) internal view returns (uint24) {
        uint96 _unpacked = _getExtraData(tokenId);
        return uint24(_unpacked);
    }

    /// @dev Returns sub-tier ID for `tokenId`.
    /// See: {ERC721 - _getExtraData}.
    function _subTierId(uint256 tokenId) internal view returns (uint8) {
        uint96 _unpacked = _getExtraData(tokenId);
        return uint8(_unpacked >> 24);
    }

    /// @dev Returns token timestamp as seconds since unix epoch for `tokenId`.
    /// See: {ERC721 - _getExtraData}.
    function _tokenTimestamp(uint256 tokenId) internal view returns (uint64) {
        uint96 _unpacked = _getExtraData(tokenId);
        return uint64(_unpacked >> 32);
    }

    ///////// INTERNAL TOKEN COUNTER GETTER FUNCTIONS /////////////////////////////////////////////O-'

    /// @dev Returns the next token ID to be minted.
    function _nextTokenId() internal view returns (uint256) {
        return _currentIndex;
    }

    /// @dev The starting token ID for sequential mints is 1 (one).
    function _startTokenId() internal pure returns (uint256) {
        return 1;
    }

    ///////// INTERNAL HELPER FUNCTION ////////////////////////////////////////////////////////////O-'

    /// @dev For more efficient reverts.
    function _revert(bytes4 errorSelector) internal pure {
        assembly {
            mstore(0x00, errorSelector)
            revert(0x00, 0x04)
        }
    }
}