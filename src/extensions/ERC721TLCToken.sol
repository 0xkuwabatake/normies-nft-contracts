// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../ERC721TLC.sol";

/// @notice A customized ERC721TLC contract extension logic for tokenId`s life cycle management.
/// @author 0xkuwabatake (@0xkuwabatake)
abstract contract ERC721TLCToken is ERC721TLC {

    ///////// STORAGE /////////////////////////////////////////////////////////////////////////////O-'

    /// @dev Mapping from `tierId` or `tierToMint` => `fee`.
    ///
    /// Note:
    /// - Index  1 - 10 are allocated for token life cycle update `_fee` from `tierId` #1 - #10.
    /// - Index 11 - 17 are allocated for mint `_fee` from `tierId` #1 - #7 at child contract.
    /// - Index 18 - 22 are allocated for mint `_fee` to mint `tierToMint` for the owner of tierId` #1 at child contract.
    /// - Index 23 - 27 is allocated for mint fee to mint `tierToMint` for the owner of `tierId` #2 at child contract.
    /// ```
    LibMap.Uint64Map internal _fee;

    ///////// ERC-4906 EVENTS /////////////////////////////////////////////////////////////////////O-'

    /// @dev Emitted when the metadata for `tokenId` is updated.
    event MetadataUpdate(uint256 tokenId);

    /// @dev Emitted when batch of metadata `fromTokenId` to `toTokenId` is updated.
    event BatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId);

    ///////// CUSTOM EVENTS ///////////////////////////////////////////////////////////////////////O-'

    /// @dev Emitted when token life cycle update `fee` for its `tierId` is updated`.
    event TokenLifeCycleFeeUpdate(uint256 indexed tierId, uint256 indexed fee);

    /// @dev Emitted when `tokenId` life cycle from `tierId` is updated at `currentTimestamp` with `currentLifeCycle`.
    event TokenLifeCycleUpdate (
        uint256 indexed tokenId,
        uint256 indexed tierId,
        uint256 indexed currentTimeStamp,
        uint256 currentLifeCycle
    );

    ///////// CUSTOM ERRORS ///////////////////////////////////////////////////////////////////////O-'

    /// @dev Revert with an error if token life cycle is updated at unexpected time frame.
    error InvalidTimeToUpdate();

    /// @dev Revert with an error if ether balance is insufficient.
    error InsufficientBalance();

    /// @dev Revert with an error if token life cycle is unable to be updated.
    error UnableToUpdate();

    /// @dev Revert with an error if fee is invalid.
    error InvalidFee();

    ///////// PUBLIC GETTER FUNCTIONS /////////////////////////////////////////////////////////////O-'

    /// @dev Returns true if this contract implements the interface defined by `interfaceId`.
    /// See: {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool result)
    {
        return 
            interfaceId == 0x49064906 ||            // ERC4906       
            ERC721.supportsInterface(interfaceId);
    }

    /// @dev Returns update token life cycle fee for `tierId`.
    function updateFee(uint256 tierId) public view returns (uint256) {
        return uint256(LibMap.get(_fee, tierId));
    }

    /// @dev Returns update token life cycle fee for `tokenId`.
    /// 
    /// Note:
    /// - If Live(3): returns full update fee -- see {updateFee}.
    /// - If Paused(4) / Ending(5) and current time (block.timestamp) is less than or equal to 
    ///   defined pause or end of life cycle timestamp (offset), there would be a `_remainder`.
    ///   The `_remainder` is offset minus block.timestamp and its results will vary depending
    ///   on its value. Its return value will determine total value of token life cycle fee that
    ///   need to be paid of to continue its life cycle token.
    /// - If Paused(4) / Ending(5) and current time (block.timestamp) is greater than offset, then
    ///   return 0 (zero) -- as mark of non-existent token update fee to be applied.
    /// - If current life cycle status is not at one of three conditions above, 
    ///   it will constantly return 0 (zero) -- see {_validateAllReturnZeroUpdateTokenFee}.
    /// ```
    function updateTokenFee(uint256 tokenId) public view returns (uint256 result) {
        uint256 _tierId = tierId(tokenId);
        _validateAllReturnZeroUpdateTokenFee(_tierId);

        if (lifeCycleStatus(_tierId) == LifeCycleStatus.Live) {
            return updateFee(_tierId);
        }
        
        if (lifeCycleStatus(_tierId) == LifeCycleStatus.Paused) {
            if (block.timestamp <= pauseOfLifeCycle(_tierId)) {
                uint256 _remainder = _sub(pauseOfLifeCycle(_tierId), block.timestamp);
                if (_remainder >= lifeCycle(_tierId)) {
                    return updateFee(_tierId);
                } 
                if (_remainder < lifeCycle(_tierId)) {
                    return _calculateProportionalUpdateFee(_tierId, pauseOfLifeCycle(_tierId));
                } 
                if (_remainder == 0) {
                    return 0;
                }
            } else {
                return 0;
            }
        } 
        
        if (lifeCycleStatus(_tierId) == LifeCycleStatus.Ending) {
            if (block.timestamp <= endOfLifeCycle(_tierId)) {
                uint256 _remainder = _sub(endOfLifeCycle(_tierId), block.timestamp);
                if (_remainder >= lifeCycle(_tierId)) {
                    return updateFee(_tierId);
                } 
                if (_remainder < lifeCycle(_tierId)) {
                    return _calculateProportionalUpdateFee(_tierId, endOfLifeCycle(_tierId));
                } 
                if (_remainder == 0) {
                    return 0;
                }
            } else {
                return 0;
            }
        }
    }

    /// @dev Returns current length of life cycle for `tokenId` in total seconds.
    /// Note: 
    /// - Non-zero value does not guarantee that `tokenId` is in life cycle period (Live) and
    ///   it will constantly return 0 (zero) for non-existent `tokenId`.      
    /// See: {ERC721TLC - _lifeCycleToken}.
    function lifeCycleToken(uint256 tokenId) public view returns (uint256) {
        return _lifeCycleToken(tokenId);
    }

    /// @dev Returns start of life cycle for `tokenId`.
    /// 
    /// Note:
    /// Start of life cycle token is mark time of the beginning of life cycle `tokenId` for
    /// a particular life cycle token period. It will vary for each minted `tokenId`.
    ///
    /// Conditions:
    /// - It will return 0 (zero), if current life cycle `_tierId`'s status from `tokenId` and
    ///   current time (block.timestamp) comparing to defined start / pause / end of life cyle 
    ///   timestamp as described at {_validateAllReturnZeroStartOrEndLifeCycleToken}.
    ///
    /// - It will return non-zero value, if current life cycle `tierId`'s status is:
    ///   - at Live(3) and current time is equal to or greater than start of life cycle `_tierId` or
    ///   - at Paused(4) and current time is less than or equal to pause of life cycle `_tierId` or
    ///   - at Ending(5) and current time is less than or equal to end of life cycle `_tierId`.
    ///
    /// - The non-zero value's rules are as followings:
    ///   - If token timestamp `tokenId` is greater than start of life cycle `_tierId`,
    ///     then start of life cycle `tokenId` is its current token timestamp --
    ///     see {ERC721TLC - tokenTimestamp}. At some point, all of start of life cycle `tokenId`
    ///     will fall into this condition as long as the life cycle period for its `_tierId` is
    ///     at Live(3) status.
    ///   - If token timestamp `tokenId` is less than or equal to start of life cycle `_tierId`,
    ///     then start of life cycle `tokenId` is start of life cycle `_tierId`.
    /// ```
    function startOfLifeCycleToken(uint256 tokenId) public view returns (uint256 result) {
        uint256 _tierId = tierId(tokenId);
        _validateAllReturnZeroStartOrEndLifeCycleToken(tokenId);

        if (
            (lifeCycleStatus(_tierId) == LifeCycleStatus.Live && block.timestamp >= startOfLifeCycle(_tierId))
                || (lifeCycleStatus(_tierId) == LifeCycleStatus.Paused && block.timestamp <= pauseOfLifeCycle(_tierId))
                || (lifeCycleStatus(_tierId) == LifeCycleStatus.Ending && block.timestamp <= endOfLifeCycle(_tierId))
        ) {
            if (tokenTimestamp(tokenId) > startOfLifeCycle(_tierId)) {
                return tokenTimestamp(tokenId);
            } else {
                return startOfLifeCycle(_tierId);
            }
        }
    }

    /// @dev Returns end of life cycle for `tokenId`.
    /// 
    /// Note:
    /// End of life cycle token is mark time of the end of life cycle `tokenId` for
    /// a particular life cycle token period. It will vary for each minted `tokenId`.
    ///
    /// Conditions:
    /// - It will return 0 (zero), if current life cycle `_tierId`'s status from `tokenId` and
    ///   current time (block.timestamp) comparing to defined start / pause / end of life cyle 
    ///   timestamp as described at {_validateAllReturnZeroStartOrEndLifeCycleToken}.
    ///
    /// - It will return non-zero value, if current life cycle `_tierId`'s status is:
    ///   - at Live(3) and current time is equal to or greater than start of life cycle `_tierId` or
    ///   - at Paused(4) and current time is less than or equal to pause of life cycle `_tierId` or
    ///   - at Ending(5) and current time is less than or equal to end of life cycle `_tierId`.
    ///   - See: {endOfLifeCycleTokenUnchecked}.
    ///
    /// - The non-zero value's rules are as followings:
    ///   - If token timestamp `tokenId` is greater than start of life cycle `_tierId`,
    ///     then end of life cycle `tokenId` is the addition of its token timestamp and
    ///     life cycle token `tokenId` -- see {lifeCycleToken}. At some point, 
    ///     all of end of life cycle `tokenId`will fall into this condition
    ///     as long as the life cycle period for its `_tierId` is at Live(3) status.
    ///   - If token timestamp for `tokenId` is less than or equal to start of life cycle `_tierId`,
    ///     then end of life cycle `tokenId` is the addition start of life cycle `_tierId`
    ///     and life cycle token `tokenId`.
    /// ``` 
    function endOfLifeCycleToken(uint256 tokenId) public view returns (uint256 result) {
        uint256 _tierId = tierId(tokenId);
        _validateAllReturnZeroStartOrEndLifeCycleToken(tokenId);

        if (
            (lifeCycleStatus(_tierId) == LifeCycleStatus.Live && block.timestamp >= startOfLifeCycle(_tierId))
                || (lifeCycleStatus(_tierId) == LifeCycleStatus.Paused && block.timestamp <= pauseOfLifeCycle(_tierId))
                || (lifeCycleStatus(_tierId) == LifeCycleStatus.Ending && block.timestamp <= endOfLifeCycle(_tierId))
        ) {
            result = endOfLifeCycleTokenUnchecked(tokenId);
        }
    }

    /// @dev Returns unchecked end of life cycle token for `tokenId`.
    /// 
    /// Note:
    /// - The intention of this method is to be queried by offchain indexer to get the stored
    ///   value of end of life cycle `tokenId` especially when the {endOfLifeCycleToken}'s value
    ///   is overriden to zero value as defined at {_validateAllReturnZeroStartOrEndLifeCycleToken}.
    /// ```
    function endOfLifeCycleTokenUnchecked(uint256 tokenId) public view returns (uint256) {
        uint256 _tierId = tierId(tokenId);

        if (tokenTimestamp(tokenId) > startOfLifeCycle(_tierId)) {
            return _add(tokenTimestamp(tokenId), lifeCycleToken(tokenId));
        } else {
            return _add(startOfLifeCycle(_tierId), lifeCycleToken(tokenId));
        }
    }

    /// @dev Returns status for `tokenId` in string literal either is "Active" or "Inactive".
    /// Note: The return value will be queried by {ERC721TLCDataURI - _body} metadata.
    /// See: {_tokenStatus}.
    function tokenStatus(uint256 tokenId) public view virtual returns (string memory result) {
        if (!_exists(tokenId)) _revert(TokenDoesNotExist.selector);
        uint256 _status = _tokenStatus(tokenId);
        
        if (_status == 0) return "Active";
        if (_status == 1) return "Inactive";
        
    }

    ///////// INTERNAL FUNCTIONS //////////////////////////////////////////////////////////////////O-'

    ///////// INTERNAL TOKEN LIFE CYCLE UPDATE OPERATION /////////

    /// @dev Update token life cycle for `tokenId`.
    /// See: {TierLifeCycle - lifeCycle}, {ERC721 - _setExtraData}.
    function _updateTokenLifeCycle(uint256 tokenId) internal {
        uint256 _tierId = tierId(tokenId);                                  
        uint96 _packed = uint96(_tierId) |                     // 2 bytes - existing `_tierId`                                          
        uint96(block.timestamp) << 16 |                        // 5 bytes - block.timestamp         
        uint96(lifeCycle(_tierId)) << 56;                      // 5 bytes - life cycle for `tierId`               
        _setExtraData(tokenId, _packed);

        emit TokenLifeCycleUpdate(tokenId, _tierId, block.timestamp, lifeCycle(_tierId));
        emit MetadataUpdate(tokenId);
    }

    ///////// INTERNAL TOKEN LIFE CYCLE UPDATE FEE SETTER /////////

    /// @dev Sets token life cycle update `fee` for `tierId`.
    /// 
    /// Note:
    /// Update fee is a mandatory fee that need to be paid in native token (ether) either in full or 
    /// proportionally by token owners when updating their token life cycle 
    /// at the end of life cycle for their owned tokenId.
    /// - It is mandatory to be initialized prior to {TierLifeCycle - _setStartOfLifeCycle} and
    ///   `fee` cannot be set to zero value or greater than 18.44 ether (see below) --
    ///   these conditions must be well-validated at child contract.
    /// 
    /// Requirements:
    /// - Life cycle status must be at ReadyToStart(1) / Live (3) / Paused(4) / Ending (5).
    /// - `fee` cannot be greater than 18446744073709551615 wei (18.446744073709551615 ether).
    /// - If Live(3): non-zero `fee` is able to be reinitialized start from 48 hours before 
    ///   the end of first life cycle period.
    /// - If Paused(4): it only can be initialized when tx's block.timestamp is greater than defined
    ///   pause of life cycle timestamp.
    /// - If Ending(5): it only can be initialized when tx's block.timestamp is greater than defined
    ///   end of life cycle timestamp and in this situation the `fee` must set back to 0 (zero) --
    ///   this condition must be well-validated at child contract.
    /// ```
    function _setUpdateFee(uint256 tierId, uint256 fee) internal {
        _requireStatusIsReadyToStartOrLiveOrPausedOrEnding(tierId);
        if (fee > 0xFFFFFFFFFFFFFFFF) _revert(InvalidFee.selector);

        if (lifeCycleStatus(tierId) == LifeCycleStatus.Live) {
            uint256 _endOfFirstLifeCyclePeriod = _add(startOfLifeCycle(tierId), lifeCycle(tierId));
            if (block.timestamp < _sub(_endOfFirstLifeCyclePeriod, 172800)) {
                _revert(InvalidTimeToInitialize.selector);
            } 
            LibMap.set(_fee, tierId, uint64(fee));
        }
        
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Paused) {
            if (block.timestamp <= pauseOfLifeCycle(tierId)) _revert(InvalidTimeToInitialize.selector);
            LibMap.set(_fee, tierId, uint64(fee));
        }
        
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Ending) {
            if (block.timestamp <= endOfLifeCycle(tierId)) _revert(InvalidTimeToInitialize.selector);
            LibMap.set(_fee, tierId, uint64(fee));
        }
        
        LibMap.set(_fee, tierId, uint64(fee)); // ReadyToStart(1)

        emit TokenLifeCycleFeeUpdate(tierId, fee);
    }

    ///////// INTERNAL UPDATE NFT METADATA BASED ON ERC-4906 OPERATION /////////

    /// @dev Emits metadata update event `fromTokenId` to `toTokenId` from ERC-4906.
    /// See: https://eips.ethereum.org/EIPS/eip-4906#specification
    function _emitMetadataUpdate(uint256 fromTokenId, uint256 toTokenId) internal {
        if (fromTokenId == toTokenId) {
            emit MetadataUpdate(fromTokenId);
        } else {
            emit BatchMetadataUpdate(fromTokenId, toTokenId);
        }
    }

    ///////// INTERNAL UPDATE TOKEN LIFE CYCLE FEE VALIDATOR /////////

    /// @dev Update token life cycle fee for `tokenId` validator.
    /// 
    /// Requirements:
    /// - LifeCycleStatus must be at Live(3) / Paused(4) / Ending(5).
    /// - If Live(3): it can be initialized 2 hours (7200 seconds) before 
    ///   end of life cycle token `tokenId` -- the condition is defined as constant to prevent
    ///   token owner update its token life cycle too early from end of life cycle token `tokenId`.
    /// - If Paused(4) / Ending(5): beside of condition above, the current time must be validated 
    ///   with end of life cycle `tokenId` and `offset` -- see {_validateOffset}, 
    ///   before comparing current time with `offset` to get the remainder as the basis of total fee 
    ///   that needed to be paid -- see {_validateRemainder}.  
    /// ```
    function _validateUpdateFee(uint256 tokenId) internal {
        uint256 _tierId = tierId(tokenId);

        if (lifeCycleStatus(_tierId) == LifeCycleStatus.Live) {
            if (block.timestamp < _sub(endOfLifeCycleToken(tokenId), 7200)) {                      
                _revert(InvalidTimeToUpdate.selector);
            } 
            _validateFullUpdateFee(tokenId);
        } else if (lifeCycleStatus(_tierId) == LifeCycleStatus.Paused) {
            _validateOffset(tokenId, pauseOfLifeCycle(_tierId));
            _validateRemainder(tokenId, pauseOfLifeCycle(_tierId));
        } else if (lifeCycleStatus(_tierId) == LifeCycleStatus.Ending) {
            _validateOffset(tokenId, endOfLifeCycle(_tierId));
            _validateRemainder(tokenId, endOfLifeCycle(_tierId));
        } else {
            _revert(InvalidLifeCycleStatus.selector);
        }
    }

    ///////// INTERNAL MSG.VALUE COMPARE TO FEE VALIDATOR /////////

    /// @dev msg.value compare to `fee` validator.
    function _validateMsgValue(uint256 fee) internal {
        if (msg.value < fee) _revert(InsufficientBalance.selector);
    }

    ///////// INTERNAL TOKEN STATUS GETTER /////////

    /// @dev Returns token status for `tokenId`, either in 0 (zero) or 1 (one).
    ///
    /// Note: 
    /// - The return value will be queried and converted into string literal at {tokenStatus}.
    /// - The return value will be queried "as is" at {ERC721TLCDataURI - _header} metadata.
    ///
    /// Conditions:
    /// - If both of start and end of life cycle `tokenId` are zero value, return 0.
    /// - If both of start and end of life cycle `tokenId` are non-zero value and
    ///   current time (block.timestamp) is greater than end of life cycle `tokenId`, return 1 --
    ///   if not, return 0.
    ///```
    function _tokenStatus(uint256 tokenId) internal view returns (uint256 result) {
        if (startOfLifeCycleToken(tokenId) == 0) {
            if (endOfLifeCycleToken(tokenId) == 0) {
                return 0;
            }
        }

        if (startOfLifeCycleToken(tokenId) != 0) {
            if (endOfLifeCycleToken(tokenId) != 0) {
                if (block.timestamp > endOfLifeCycleToken(tokenId)) {
                    return 1;
                } else {
                    return 0;
                }
            }
        }
    }

    ///////// PRIVATE FUNCTIONS ///////////////////////////////////////////////////////////////////O-'

    /// @dev LifeCycleStatus must be at ReadyToStart(1) / Live(3) / Paused(4) / Ending(5)
    function _requireStatusIsReadyToStartOrLiveOrPausedOrEnding(uint256 tierId) private view {
        if (lifeCycleStatus(tierId) == LifeCycleStatus.NotLive) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (lifeCycleStatus(tierId) == LifeCycleStatus.ReadyToLive) {
            _revert(InvalidLifeCycleStatus.selector);
        } 
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Finished) {
            _revert(InvalidLifeCycleStatus.selector);
        } 
    }

    ///////// PRIVATE TOKEN LIFE CYCLE UPDATE FEE VALIDATORS /////////

    /// @dev Validate `offset` to update token life cycle.
    /// 
    /// Note:
    /// - `offset` is the defined pause of life cycle timestamp when life cycle status is Paused(4).
    /// - `offset` is the defined end of life cycle timestamp when life cycle status is Ending(5).
    ///
    /// Requirement:
    /// - The operation can be initiated start 2 hours (7200 seconds) before 
    ///   end of life cycle token `tokenId` and maximum until 1 minute (60 seconds) before 
    ///   current time (block.timestamp) meets the `offset`.
    /// ```
    function _validateOffset(uint256 tokenId, uint256 offset) private view {
        if (block.timestamp < _sub(endOfLifeCycleToken(tokenId), 7200)) {                                      
            _revert(InvalidTimeToUpdate.selector);
        }
        if (block.timestamp > _sub(offset, 60)) {                                                  
            _revert(InvalidTimeToUpdate.selector);
        }
    }

    /// @dev Validate remainder of token life cycle update fee based on its `offset`.
    /// 
    /// Conditions:
    /// - If `_remainder` is greater than or equal to life cycle `_tierId`, {_validateFullUpdateFee}.
    /// - If `_remainder` is less than life cycle `_tierId`, {_validateProportionalUpdateFee}.
    /// - If `_remainder` is zero, token life cycle `tokenId` is no longer updateable.
    /// ```
    function _validateRemainder(uint256 tokenId, uint256 offset) private {
        uint256 _tierId = tierId(tokenId);
        uint256 _remainder = _sub(offset, block.timestamp);

        if (_remainder >= lifeCycle(_tierId)) _validateFullUpdateFee(tokenId);
        if (_remainder < lifeCycle(_tierId)) _validateProportionalUpdateFee(tokenId, offset);
        if (_remainder == 0) _revert(UnableToUpdate.selector);
    }

    /// @dev Full token life cycle update fee for `tokenId` validator.
    /// See: {updateFee}.
    function _validateFullUpdateFee(uint256 tokenId) private {
        uint256 _tierId = tierId(tokenId);
        _validateMsgValue(updateFee(_tierId));
    }

    /// @dev Validate proportional token life cycle update fee for `tokenId` based on its `offset`.
    /// See: {_calculateProportionalUpdateFee}.
    function _validateProportionalUpdateFee(uint256 tokenId, uint256 offset) private {
        uint256 _tierId = tierId(tokenId);
        uint256 _proportionalFee = _calculateProportionalUpdateFee(_tierId, offset);
        _validateMsgValue(_proportionalFee);
    }

    /// @dev Calculate proportional token life cycle update fee for `tierId` with `offset`.
    function _calculateProportionalUpdateFee(uint256 tierId, uint256 offset)
        private
        view
        returns (uint256 result)
    {
        // Proportional fee = (`offset` - block.timestamp) * updateFee(tier) / lifeCycle(tier)
        uint256 _remainder = _sub(offset, block.timestamp);
        result = _remainder * updateFee(tierId) / lifeCycle(tierId);
    }

    ///////// PRIVATE START AND END OF LIFE CYCLE TOKEN ID VALIDATOR /////////

    /// @dev All life cycle statuses which token life cycle update fee for `tierId` returns 0 (zero).
    function _validateAllReturnZeroUpdateTokenFee(uint256 tierId)
        private
        view
        returns (uint256 result)
    {
        if (lifeCycleStatus(tierId) == LifeCycleStatus.NotLive) return 0;
        if (lifeCycleStatus(tierId) != LifeCycleStatus.Live) return 0;
        if (lifeCycleStatus(tierId) != LifeCycleStatus.Paused) return 0;
        if (lifeCycleStatus(tierId) != LifeCycleStatus.Ending) return 0;
        
    }

    /// @dev All life cycle statuses and conditions which start or end of life cycle `tokenId` returns 0 (zero).
    ///
    /// - It will return zero value, if current life cycle `_tierId`'s status is:
    ///   - at NotLive(0) / ReadyToStart(1) / ReadyToLive(2) / Finished(6) or
    ///   - at Live(3) and current time is less than start of life cycle `_tierId` or
    ///   - at Paused(4) and current time is greater than pause of life cycle `_tierId` or
    ///   - at Ending(5) and current time is greater than end of life cycle `_tierId`.
    ///```
    function _validateAllReturnZeroStartOrEndLifeCycleToken(uint256 tokenId)
        private
        view
        returns (uint256 result)
    {
        uint256 _tierId = tierId(tokenId);
    
        if (lifeCycleStatus(_tierId) == LifeCycleStatus.NotLive) return 0;
        if (lifeCycleStatus(_tierId) == LifeCycleStatus.ReadyToStart) return 0;
        if (lifeCycleStatus(_tierId) == LifeCycleStatus.ReadyToLive) return 0;
        if (lifeCycleStatus(_tierId) == LifeCycleStatus.Finished) return 0;
        if (
            (lifeCycleStatus(_tierId) == LifeCycleStatus.Live && block.timestamp < startOfLifeCycle(_tierId))
                || (lifeCycleStatus(_tierId) == LifeCycleStatus.Paused && block.timestamp > pauseOfLifeCycle(_tierId))
                || (lifeCycleStatus(_tierId) == LifeCycleStatus.Ending && block.timestamp > endOfLifeCycle(_tierId))
        ) {
            return 0;
        }
    }
}