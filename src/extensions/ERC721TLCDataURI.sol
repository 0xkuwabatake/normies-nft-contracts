// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ERC721TLCToken.sol";
import "../utils/TLCLib.sol";

/// @author 0xkuwabatake (@0xkuwabatake)
abstract contract ERC721TLCDataURI is ERC721TLCToken {
    using TLCLib for *;

    ///////// STRUCT //////////////////////////////////////////////////////////////////////////////O-'

    /// @dev Custom type represents dataURI for tier ID NFT metadata.
    struct DataURI {
        string name;
        string description;
        string tierName;
        string[2] images;
        string[2] animationURLs;
    }

    ///////// STORAGE /////////////////////////////////////////////////////////////////////////////O-'

    /// @dev Mapping from `tierId` => `DataURI`.
    mapping (uint256 => DataURI) private _tierDataURI;

    ///////// CUSTOM EVENT ////////////////////////////////////////////////////////////////////////O-'

    /// @dev Emitted when `tierDataURI` is updated to `tierId`.
    event TierDataURIUpdate (
        uint256 indexed tierId,
        string name,
        string description,
        string tierName,
        string[2] images,
        string[2] animationURLs
    );

    ///////// PUBLIC GETTERS FUNCTIONS ////////////////////////////////////////////////////////////O-'

    /// @dev Returns the Uniform Resource Identifier (URI) for `tokenId`.
    /// 
    /// See: {ERC721Metadata - tokenURI}.
    /// 
    /// Expiry date trait is only showing up with following conditions:
    /// - when life cycle status is Live(3) and start of life cycle has started or
    /// - when life cycle status is Paused(4) and hasn't passed the pause of life cycle timestamp or
    /// - when life cycle status is Ending(5) and hasn't passed the end of life cycle timestamp.
    /// ```
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) _revert(TokenDoesNotExist.selector);
        uint256 _tierId = tierId(tokenId);

        // Live(3) / Paused(4) / Ending(5)
        if (
            (lifeCycleStatus(_tierId) == LifeCycleStatus.Live && block.timestamp >= startOfLifeCycle(_tierId)) ||
            (lifeCycleStatus(_tierId) == LifeCycleStatus.Paused && block.timestamp <= pauseOfLifeCycle(_tierId)) ||
            (lifeCycleStatus(_tierId) == LifeCycleStatus.Ending && block.timestamp <= endOfLifeCycle(_tierId))
           ) 
        {
            return string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    TLCLib.toBase64(bytes(string.concat(_header(tokenId),_body(tokenId),_expiryDate(tokenId),'"}]}')))
                )
            );
        } else {
            return string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    TLCLib.toBase64(bytes(string.concat(_header(tokenId), _body(tokenId), '"}]}')))
                )
            );
        }
    }

    /// @dev Returns DataURI for `tierId`.
    function tierDataURI(uint256 tierId) public view returns (DataURI memory) {
        return _tierDataURI[tierId];
    }

    ///////// INTERNAL FUNCTIONS //////////////////////////////////////////////////////////////////O-'

    ///////// INTERNAL TIER DATA URI SETTER /////////

    /// @dev Sets tier DataURI for `tierId`.
    function _setTierDataURI(
        uint256 tierId, 
        string memory name,
        string memory description,
        string memory tierName,
        string[2] memory images,
        string[2] memory animationURLs
    ) internal {
        _tierDataURI[tierId] = DataURI(name, description, tierName, images, animationURLs);
        emit TierDataURIUpdate(tierId, name, description, tierName, images, animationURLs);

        // When total supply of tokens is not zero, {_emitMetadataUpdate}
        if (totalSupply() != 0) {
            _emitMetadataUpdate(_startTokenId(), totalSupply());
        }
    }

    ///////// PRIVATE FUNCTIONS ///////////////////////////////////////////////////////////////////O-'

    ///////// PRIVATE TOKEN METADATA GETTERS /////////

    /// @dev Returns metadata header for `tokenId`.
    /// See: {ERC721TLCToken - _tokenStatus}.
    function _header(uint256 tokenId) private view returns (string memory) {
        uint256 _tierId = tierId(tokenId);
        uint256 _tokenStatus = _tokenStatus(tokenId);

        return string(
            abi.encodePacked(
                '{"name":"',_tierDataURI[_tierId].name," #"
                ,TLCLib.toString(tokenId),
                '","description":"'
                ,_tierDataURI[_tierId].description,'",',
                '"image":"'
                ,_tierDataURI[_tierId].images[_tokenStatus],'",',
                '"animation_url":"'
                ,_tierDataURI[_tierId].animationURLs[_tokenStatus]
            )
        );
    }

    /// @dev Returns metadata body for `tokenId`.
    /// See: {ERC721TLCToken - tokenStatus}.
    function _body(uint256 tokenId) private view returns (string memory) {
        uint256 _tierId = tierId(tokenId);
        string memory _tokenStatus = tokenStatus(tokenId);
        
        return string(
            abi.encodePacked(
                '","attributes":[{"trait_type":"Tier ID","value":"'
                ,TLCLib.toString(_tierId),
                '"},{"trait_type":"Tier","value":"'
                ,_tierDataURI[_tierId].tierName,
                '"},{"trait_type":"Status","value":"'
                ,_tokenStatus
            )
        );
    }

    /// @dev Returns expiry date metadata for `tokenId`.
    /// See: {_tokenExpiryDate}.
    function _expiryDate(uint256 tokenId) private view returns (string memory) {
        (uint256 year, uint256 month, uint256 day) = _tokenExpiryDate(tokenId);
        string memory _year = TLCLib.toString(year);
        string memory _month = TLCLib.toString(month);
        string memory _day = TLCLib.toString(day);

        // It follows the ISO 8601 standard (YYYY-MM-DD) by appending "0" prefix
        // to month before october and to day before day tenth.
        // Ref: https://www.iso.org/iso-8601-date-and-time-format.html
        if (month < 10) {
            _month = string.concat("0", TLCLib.toString(month));
        }
        if (day < 10) {
            _day = string.concat("0", TLCLib.toString(day));
        }

        return string(
            abi.encodePacked(
                '"},{"trait_type":"Expiry Date","value":"'
                ,_year,'-'
                ,_month,'-'
                ,_day
            )
        );
    }

    /// @dev Returns expiry date for `tokenId` in (`year`,`month`,`day`).
    /// See: {ERC721TLCToken - _endOfLifeCycleToken}.
    function _tokenExpiryDate(uint256 tokenId) 
        private
        view 
        returns (uint256 year, uint256 month, uint256 day) 
    {
        return TLCLib.timestampToDate(endOfLifeCycleToken(tokenId));
    }
}