// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "solady/tokens/ERC721.sol";
import "./extensions/TierLifeCycle.sol";

/// @notice Simple but highly customized ERC721 contract extension to create a tier-based NFT with life cycle collection.
/// @author 0xkuwabatake(@0xkuwabatake)
abstract contract ERC721TLC is ERC721, TierLifeCycle {

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

    ///////// PUBLIC GETTER FUNCTIONS /////////////////////////////////////////////////////////////O-'

    /// @dev Returns the token collection name.
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @dev Returns the token collection symbol.
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    ///////// ERC721T GETTERS /////////

    /// @dev Returns tier ID from `tokenId`.
    function tierId(uint256 tokenId) public view returns (uint256) {
        uint96 _unpacked = _getExtraData(tokenId);
        uint16 _tierId = uint16(_unpacked);
        return uint256(_tierId);
    }

    /// @dev Returns token timestamp as seconds since unix epoch for `tokenId`.
    function tokenTimestamp(uint256 tokenId) public view returns (uint256) {
        uint96 _unpacked = _getExtraData(tokenId);
        uint40 _tokenTimestamp = uint40(_unpacked >> 16);
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
        return TLCLib.sub(_currentIndex, _startTokenId());
    }

    ///////// INTERNAL FUNCTIONS //////////////////////////////////////////////////////////////////O-'

    ///////// INTERNAL ERC721T SAFE MINT LOGIC FUNCTION /////////

    /// @dev Safe mints single quantity of token ID to `to` and set to `tier`.
    /// Note: `tier` must not be zero and it must be validated at child contract.
    /// See: {_setMintExtraData}, {ERC721 - _safeMint}.
    function _safeMintTier(address to, uint256 tier) internal {
        uint256 _tokenId = _nextTokenId();
        unchecked {
            ++_currentIndex;
        }
        _setMintExtraData(_tokenId, tier);
        _safeMint(to, _tokenId);

        emit TierSet(_tokenId, tier, block.timestamp);
    }

    ///////// INTERNAL ERC721T MINT EXTRA DATA SETTER //////////

    /// @dev Sets mint extra data for `tokenId` to `tier`, `block.timestamp` and life cycle `tier`.
    /// See: {TierLifeCycle - lifeCycle}, {ERC721 - _setExtraData}.
    function _setMintExtraData(uint256 tokenId, uint256 tier) internal {
        uint96 _packed = uint96(tier) |                         // 2 bytes - Tier ID                      
        uint96(block.timestamp) << 16 |                         // 5 bytes - block.timestamp
        uint96(lifeCycle(tier)) << 56;                          // 5 bytes - LifeCycle for token ID                            

        _setExtraData(tokenId, _packed);
    }

    ///////// INTERNAL LIFE CYCLE TOKEN GETTER /////////

    /// @dev Returns life cycle for `tokenId` in total seconds.
    /// Note: It's intended to be queried by a public function at {ERC721TLCToken - lifeCycleToken}.
    function _lifeCycleToken(uint256 tokenId) internal view returns (uint256) {
        uint96 _unpacked = _getExtraData(tokenId);
        uint40 lifeCycleToken_ = uint40(_unpacked >> 56);
        return uint256(lifeCycleToken_);
    }

    ///////// INTERNAL TOKEN COUNTER GETTERS /////////

    /// @dev Returns the next token ID to be minted.
    function _nextTokenId() internal view returns (uint256) {
        return _currentIndex;
    }

    /// @dev The starting token ID for sequential mints is 1 (one).
    function _startTokenId() internal pure returns (uint256) {
        return 1;
    }
}