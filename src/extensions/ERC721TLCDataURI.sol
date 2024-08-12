// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ERC721TLCToken.sol";
import "solady/utils/Base64.sol";

/// @author 0xkuwabatake (@0xkuwabatake)
abstract contract ERC721TLCDataURI is ERC721TLCToken {
    using Base64 for bytes;
    
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
    /// See: {ERC721Metadata - tokenURI}.
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) _revert(TokenDoesNotExist.selector);
        uint256 _tierId = tierId(tokenId);

        // Expiry date trait is only showing up in NFT metadata,
        // when life cycle status is Live(3) and start of life cycle has started or
        // when life cycle status is Paused(4) and hasn't passed the pause of life cycle timestamp or
        // when life cycle status is Ending(5) and hasn't passed the end of life cycle timestamp.
        if (
            (lifeCycleStatus(_tierId) == LifeCycleStatus.Live && block.timestamp >= startOfLifeCycle(_tierId)) ||
            (lifeCycleStatus(_tierId) == LifeCycleStatus.Paused && block.timestamp <= pauseOfLifeCycle(_tierId)) ||
            (lifeCycleStatus(_tierId) == LifeCycleStatus.Ending && block.timestamp <= endOfLifeCycle(_tierId))
           ) 
        {
            return string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            string.concat(
                                _header(tokenId),
                                _body(tokenId),
                                _expiryDate(tokenId),
                                '"}]}'
                                )
                        )
                    )
                )
            );
        } else {
            return string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            string.concat(_header(tokenId), _body(tokenId), '"}]}')
                        )
                    )
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
                ,_toString(tokenId),
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
                ,_toString(_tierId),
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
        string memory _year = _toString(year);
        string memory _month = _toString(month);
        string memory _day = _toString(day);

        // It follows the ISO 8601 standard (YYYY-MM-DD) by appending "0" prefix
        // to month before october and to day before day tenth.
        // Ref: https://www.iso.org/iso-8601-date-and-time-format.html
        if (month < 10) {
            _month = string.concat("0", _toString(month));
        }
        if (day < 10) {
            _day = string.concat("0", _toString(day));
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
        return timestampToDate(endOfLifeCycleToken(tokenId));
    }

    ///////// PRIVATE HELPER FUNCTIONS /////////

    /// @dev Converts a uint256 to its ASCII string decimal representation.
    /// Source: https://github.com/chiru-labs/ERC721A/blob/main/contracts/ERC721A.sol#L1266
    function _toString(uint256 value) private pure returns (string memory str) {
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits. Total: 5 * 0x20 = 0xa0.
            let m := add(mload(0x40), 0xa0)
            // Update the free memory pointer to allocate.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }

    /// @dev Returns (`year`,`month`,`day`) from the given unix timestamp.
    /// Source: https://github.com/Vectorized/solady/blob/main/src/utils/DateTimeLib.sol#L118
    function timestampToDate(uint256 timestamp)
        private
        pure
        returns (uint256 year, uint256 month, uint256 day)
    {
        (year, month, day) = epochDayToDate(timestamp / 86400);
    }

    /// @dev Returns (`year`,`month`,`day`) from the number of days since 1970-01-01.
    /// Source: https://github.com/Vectorized/solady/blob/main/src/utils/DateTimeLib.sol#L83
    function epochDayToDate(uint256 epochDay)
        private
        pure
        returns (uint256 year, uint256 month, uint256 day)
    {
        /// @solidity memory-safe-assembly
        assembly {
            epochDay := add(epochDay, 719468)
            let doe := mod(epochDay, 146097)
            let yoe :=
                div(sub(sub(add(doe, div(doe, 36524)), div(doe, 1460)), eq(doe, 146096)), 365)
            let doy := sub(doe, sub(add(mul(365, yoe), shr(2, yoe)), div(yoe, 100)))
            let mp := div(add(mul(5, doy), 2), 153)
            day := add(sub(doy, shr(11, add(mul(mp, 62719), 769))), 1)
            month := byte(mp, shl(160, 0x030405060708090a0b0c0102))
            year := add(add(yoe, mul(div(epochDay, 146097), 400)), lt(month, 3))
        }
    }
}