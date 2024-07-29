// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "solady/tokens/ERC721.sol";

/// @notice Simple but highly customized ERC721 contract extension to create a tier-based NFT collection.
/// @author 0xkuwabatake(@0xkuwabatake)
abstract contract ERC721T is ERC721 {

    ///////// STORAGE /////////////////////////////////////////////////////////////////////////////O-'

    /// @dev The next token ID to be minted.
    uint256 private _currentIndex;

    /// @dev Token name.
    string private _name;

    /// @dev Token symbol.
    string private _symbol;

    ///////// CUSTOM EVENT ////////////////////////////////////////////////////////////////////////O-'

    /// @dev Emitted when `tokenId` is minted at `atTimestamp` and set to `tierId`.
    event TierSet (uint256 indexed tokenId, uint256 indexed tierId, uint256 indexed atTimeStamp);

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

    ///////// PUBLIC GETTER FUNCTIONS /////////////////////////////////////////////////////////////O-'

    /// @dev Returns tier ID from `tokenId`.
    function tierId(uint256 tokenId) public view returns (uint256) {
        uint96 _unpacked = _getExtraData(tokenId);
        uint32 _tierId = uint32(_unpacked);
        return uint256(_tierId);
    }

    /// @dev Returns token timestamp as seconds since unix epoch for `tokenId`.
    function tokenTimestamp(uint256 tokenId) public view returns (uint256) {
        uint96 _unpacked = _getExtraData(tokenId);
        uint64 _tokenTimestamp = uint64(_unpacked >> 32);
        return uint256(_tokenTimestamp);
    }

    /// @dev Returns tier IDs owned by `owner`.
    function tiersOfOwner(address owner) public view returns (uint256[] memory) {
        uint256[] memory _tokenIds = tokensOfOwner(owner);
        uint256[] memory _tierIds = new uint256[](_tokenIds.length);
        uint256 i;

        while (i < _tierIds.length) {
            _tierIds[i] = tierId(_tokenIds[i]);
            unchecked { ++i; }
        }
        return _tierIds;
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

    /// @dev Safe mints single quantity of token ID to `to` and set to `tier`.
    /// Note: `tier` CANNOT be zero and it MUST be validated at child contract.
    function _safeMintTier(address to, uint256 tier) internal {
        uint256 _tokenId = _nextTokenId();
        unchecked {
            ++_currentIndex;
        }
        _setMintExtraData(_tokenId, tier);
        _safeMint(to, _tokenId);

        emit TierSet(_tokenId, tier, block.timestamp);
    }

    ///////// INTERNAL MINT EXTRA DATA SETTER FUNCTION ////////////////////////////////////////////O-'

    /// @dev Sets mint extra data for `tokenId` to `tier` and `block.timestamp`.
    /// See: {ERC721 - _setExtraData}.
    function _setMintExtraData(uint256 tokenId, uint256 tier) internal {
        uint96 _packed = uint96(tier) |                                // 4 bytes - Tier ID                      
        uint64(block.timestamp) << 32;                                 // 8 bytes - block.timestamp                
        _setExtraData(tokenId, _packed);
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
}