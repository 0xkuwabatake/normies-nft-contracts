// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "solady/utils/LibMap.sol";

/// @author 0xkuwabatake(@0xkuwabatake)
abstract contract TierLifeCycle {
    using LibMap for uint256;

    ///////// ENUM ////////////////////////////////////////////////////////////////////////////////O-'

    /// @dev Life Cycle status.
    ///
    /// Note:
    /// - #0 - NotLive      : initial state of a life cycle.
    /// - #1 - ReadyToStart : life cycle value has been defined and it's ready to start.
    /// - #2 - ReadyToLive  : start of life cycle value has been defined and it's ready to live.
    /// - #3 - Live         : life cycle period is live.
    /// - #4 - Paused       : life cycle period is in paused state.
    /// - #5 - Ending       : end of life cycle value has been defined (life cycle is in ending period).
    /// - #6 - Finished     : life cycle is finished and it cannot go back to Live.
    /// ```
    enum LifeCycleStatus {
        NotLive,
        ReadyToStart,
        ReadyToLive,
        Live,
        Paused,
        Ending,
        Finished
    }

    ///////// STORAGE /////////////////////////////////////////////////////////////////////////////O-'

    /// Mapping from `tierId` => `LifeCycleStatus`.
    mapping (uint256 => LifeCycleStatus) private _lifeCycleStatus;

    
    /// @dev Mapping from `tierId` => life cycle values.
    ///
    /// Note:
    /// - Index  1 - 10 are allocated for life cycle in total seconds for `tierId` #1 - #10.
    /// - Index 11 - 20 are allocated for start of life cycle timestamp for `tieId` #1 - #10.        
    /// - Index 21 - 30 are allocated for pause of life cycle timestamp for `tierId` #1 - #10.
    /// - Index 31 - 40 are allocated for end of life cycle timestamp for `tierId` #1 - #10. 
    /// ```       
    LibMap.Uint40Map private _lifeCycle;

    ///////// CUSTOM EVENTS ///////////////////////////////////////////////////////////////////////O-'

    /// @dev Emitted when life cycle for `tierId` is updated in `totalSeconds`. 
    event LifeCycleUpdate(uint256 indexed tierId, uint256 indexed totalSeconds);

    /// @dev Emitted when start of life cycle for `tierId` will start at `timestamp`.
    event StartOfLifeCycleUpdate(uint256 indexed tierId, uint256 indexed timestamp);

    /// @dev Emitted when life cycle status for `tierId` is Live at `atTimestamp`.
    event LifeCycleIsLive(uint256 indexed tierId, uint256 indexed atTimestamp);

    /// @dev Emitted when life cycle status for `tierId` will be paused at `timestamp`.
    event LifeCycleIsPaused(uint256 indexed tierId, uint256 indexed atTimestamp);

    /// @dev Emitted when life cycle status for `tierId` is unpaused at `atTimestamp`.
    event LifeCycleIsUnpaused(uint256 indexed tierId, uint256 indexed atTimestamp);

    /// @dev Emitted when end of life cycle for `tierId` is set at `timestamp`.
    event EndOfLifeCycleSet(uint256 indexed tierId, uint256 indexed atTimestamp);

    /// @dev Emitted when Life cycle status for `tierId` is Finished at `atTimestamp`.
    event LifeCycleIsFinished(uint256 indexed tierId, uint256 indexed atTimestamp);

    ///////// CUSTOM ERRORS ///////////////////////////////////////////////////////////////////////O-'

    /// @dev Revert with an error if LifeCycleStatus is invalid.
    error InvalidLifeCycleStatus();

    /// @dev Revert with an error if some state changes is initialize at invalid time.
    error InvalidTimeToInitialize();

    /// @dev Revert with an error if `numberOfDays` value is invalid.
    error InvalidNumberOfDays();

    /// @dev Revert with an error if timestamp is invalid.
    error InvalidTimestamp();

    ///////// PUBLIC GETTER FUNCTIONS /////////////////////////////////////////////////////////////O-'

    /// @dev Returns life cycle status for `tierId` in LifeCycleStatus's key value (uint8).
    function lifeCycleStatus(uint256 tierId) public view returns (LifeCycleStatus) {
        return _lifeCycleStatus[tierId];
    }

    /// @dev Returns life cycle for `tierId` in total seconds.
    function lifeCycle(uint256 tierId) public view returns (uint256) {
        return uint256(LibMap.get(_lifeCycle, tierId));
    }

    /// @dev Returns start of life cycle for `tierId` at timestamp as seconds since unix epoch.
    function startOfLifeCycle(uint256 tierId) public view returns (uint256) {
        return uint256(LibMap.get(_lifeCycle, _add(tierId, 10)));
    }

    /// @dev Returns life cycle for `tierId` is paused at timestamp as seconds since unix epoch.
    function pauseOfLifeCycle(uint256 tierId) public view returns (uint256) {
        return uint256(LibMap.get(_lifeCycle, _add(tierId, 20)));
    }

    /// @dev Returns end of life cycle for `tierId` at timestamp as seconds since unix epoch.
    function endOfLifeCycle(uint256 tierId) public view returns (uint256) {
        return uint256(LibMap.get(_lifeCycle, _add(tierId, 30)));
    }

    ///////// INTERNAL FUNCTIONS //////////////////////////////////////////////////////////////////O-'

    ///////// INTERNAL LIFE CYCLES FOR A TIER ID SETTERS /////////

    /// @dev Sets life cycle for `tierId`.
    /// 
    /// Note:
    /// Life cycle is length of a life cycle period in total seconds.
    /// 
    /// Requirements:
    /// - LifeCycleStatus must be at: NotLive(0) / Live(3) / Paused(4).
    ///   - If Live(3): `numberOfDays` can be reinitialized start from 48 hours before 
    ///     the end of first life cycle period.
    ///   - If Paused(4): `numberOfDays` can be reinitialized after current tx's timestamp
    ///     had passed pause of life cycle that had been defined.
    /// - `numberOfDays` must be at least equal to or greater than 30 days.
    /// ```
    // function _setLifeCycle(uint256 tierId, uint256 numberOfDays) 
    function _setLifeCycle(uint256 tierId, uint256 numberOfMinutes) internal {                     // TESTNET !!!
        _requireStatusIsNotLiveOrLiveOrPaused(tierId);
        // if (numberOfDays < 30) _revert(InvalidNumberOfDays.selector);                        
        // uint256 _totalSeconds = numberOfDays * 86400; 
        if (numberOfMinutes < 10) _revert(InvalidNumberOfDays.selector);                           // TESTNET !!!
        uint256 _totalSeconds = numberOfMinutes * 60;                                              // TESTNET !!!

        // NotLive(0)
        if (lifeCycleStatus(tierId) == LifeCycleStatus.NotLive) {
            _lifeCycleStatus[tierId] = LifeCycleStatus.ReadyToStart; // NotLive(0) => ReadyToStart(1)
            LibMap.set(_lifeCycle, tierId, uint40(_totalSeconds));
        }
        // Live(3)
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Live) {
            uint256 _endOfFirstLifeCyclePeriod = _add(startOfLifeCycle(tierId), lifeCycle(tierId));
            // if (block.timestamp <= _sub(_endOfFirstLifeCyclePeriod, 172800)) {
            if (block.timestamp <= _sub(_endOfFirstLifeCyclePeriod, 120)) {                        // TESTNET !!!
                _revert(InvalidTimeToInitialize.selector);
            } 
            LibMap.set(_lifeCycle, tierId, uint40(_totalSeconds));
        }
        // Paused(4)
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Paused) {
            if (block.timestamp <= pauseOfLifeCycle(tierId)) _revert(InvalidTimeToInitialize.selector);
            LibMap.set(_lifeCycle, tierId, uint40(_totalSeconds));
        }

        emit LifeCycleUpdate(tierId, _totalSeconds);
    }

    /// @dev Sets start of life cycle for `tierId`.
    /// 
    /// Note:
    /// Start of life cycle is a mark time of the beginning of life cycle period. Once it had been
    /// initialized and life cycle status is Live(3), it cannot be reinitialized.
    /// 
    /// Requirements:
    /// - LifeCycleStatus must be at: ReadyToStart(1) / ReadyToLive(2).
    ///   - `timestamp` is still can be reinitialized when life cycle status is at ReadyToLive(2), 
    ///     just in case the tx's block.timestamp when calling {_setLifeCycleToLive} had just passed
    ///     the previous start of life cycle that had been defined.
    /// - `timestamp` must follow what been described at {_requireValidTimestamp}.
    /// ```
    function _setStartOfLifeCycle(uint256 tierId, uint256 timestamp) internal {
        _requireStatusIsReadyToStartOrReadyToLive(tierId);
        _requireValidTimestamp(timestamp);
        // ReadyToStart(1)
        if (lifeCycleStatus(tierId) == LifeCycleStatus.ReadyToStart) {
            _lifeCycleStatus[tierId] = LifeCycleStatus.ReadyToLive; // ReadyToStart(1) => ReadyToLive(2)
            LibMap.set(_lifeCycle, _add(tierId, 10), uint40(timestamp));
        }
        // ReadyToLive(2)
        if (lifeCycleStatus(tierId) == LifeCycleStatus.ReadyToLive) {
            LibMap.set(_lifeCycle, _add(tierId, 10), uint40(timestamp));
        }
        
        emit StartOfLifeCycleUpdate(tierId, timestamp);
    }

    /// @dev Sets life cycle status for `tierId` to Live(3).
    /// 
    /// Note:
    /// - The intention of this method is to change the status from ReadyToLive(2) to Live(3) with
    ///   its defined start of life cycle timestamp as the starting time. 
    /// - When it goes Live(3), all of minted token statuses under `tierId` 
    ///   will started to have their own start and end of life cycle token based on
    ///   its current token timestamp comparing to start of life cycle. 
    /// - See: {ERC721TLCToken - startOfLifeCycleToken}, {ERC721TLCToken - endOfLifeCycleToken}.
    /// 
    /// Requirements:
    /// - LifeCycleStatus must be at ReadyToLive(2).
    /// - Tx's block.timestamp when calling this method must not be passed the defined start of life
    ///   cycle. If it had been passed, it can be reinitiated after start of life cycle is being
    ///   reinitialized -- see {_startOfLifeCycle}. 
    /// ```
    function _setLifeCycleToLive(uint256 tierId) internal {
        if (lifeCycleStatus(tierId) != LifeCycleStatus.ReadyToLive) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (block.timestamp >= startOfLifeCycle(tierId)) _revert(InvalidTimeToInitialize.selector);
        _lifeCycleStatus[tierId] = LifeCycleStatus.Live; // ReadyToLive(2) => Live(3)
        emit LifeCycleIsLive(tierId, block.timestamp);
    }

    /// @dev Sets life cycle status for `tierId` to Paused(4).
    /// 
    /// Note:
    /// Pause of a life cycle is a mark time for the ongoing life cycle period to stop temporarily.
    /// - Once it had been initialized, the fee to update token life cycle would be calculated
    ///   proportionally when the current time is started to have a remainder which less than
    ///   length of life cycle token. See {ERC721TLCToken - updateTokenFee}.
    /// - When current time has passed its defined pause of life cycle, all of the token statuses
    ///   would immediately go back to `Active` as per default -- see {ERC721TLCToken - tokenStatus}.
    /// - It can be unpaused at anytime after it'd been initialized. When its unpaused, 
    ///   life cycle status would immediately go back to Live(3) -- see {_unpauseLifeCycle}.
    /// - After current time had passed its defined pause of life cycle, there's an option to
    ///   stop the life cycle period permanently -- see {finishLifeCycle}.
    /// 
    /// Requirements:
    /// - LifeCycleStatus must be at Live(3).
    ///   - If it's still at the first of life cycle period, it only can be initialized start from
    ///     48 hours (172800 seconds) before the end of its first period. 
    /// - `timestamp` must be greater than block.timestamp and less than 1099511627775.  
    /// ```
    function _pauseLifeCycle(uint256 tierId, uint256 timestamp) internal {
        _requireStatusIsLive(tierId);
        _require48HrsBeforeEndOfFirstPeriod(tierId);
        _requireValidTimestamp(timestamp);

        _lifeCycleStatus[tierId] = LifeCycleStatus.Paused; // Live(3) => Paused(4)
        LibMap.set(_lifeCycle, _add(tierId, 20), uint40(timestamp));
        emit LifeCycleIsPaused(tierId, timestamp);
    }

    /// @dev Unpause life cycle status for `tierId`.
    /// 
    /// Note:
    /// The intention of this method is to continue the lifecycle period that had been stopped
    /// temporarily (paused) to go back to Live(3) status.
    /// 
    /// Requirement:
    /// - LifeCycleStatus must be at Paused(4).
    /// ```
    function _unpauseLifeCycle(uint256 tierId) internal {
        if (lifeCycleStatus(tierId) != LifeCycleStatus.Paused) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        _lifeCycleStatus[tierId] = LifeCycleStatus.Live; // Paused(4) => Live(3)
        LibMap.set(_lifeCycle, _add(tierId, 20), 0);
        emit LifeCycleIsUnpaused(tierId, block.timestamp);
    }

    /// @dev Sets end of life cycle for `tierId`.
    /// 
    /// Note:
    /// End of life cycle is a mark time of the ending of life cycle period. 
    /// - Once it had been initialized, it cannot be cancelled -- use it wisely!
    /// - Once it had been initialized, the fee to update token life cycle would be calculated
    ///   proportionally when the current time is started to have a remainder which less than
    ///   length of life cycle token. See {ERC721TLCToken - updateTokenFee}.
    /// - When current time has passed its defined end of life cycle, all of the token statuses
    ///   would immediately go back to `Active` as per default -- see {ERC721TLCToken - tokenStatus}.
    /// - When current time has passed its defined end of life cycle, it's strongly recommended to 
    ///   finish the life cycle period once for all -- see {finishLifeCycle}.
    /// 
    /// Requirements:
    /// - LifeCycleStatus must be at Live(3).
    ///   - If it's still at the first of life cycle period, it only can be initialized start from
    ///     48 hours (172800 seconds) before the end of its first period.
    /// - `timestamp` must be greater than block.timestamp and less than 1099511627775.  
    /// ```
    function _setEndOfLifeCycle(uint256 tierId, uint256 timestamp) internal {
        _requireStatusIsLive(tierId);
        _require48HrsBeforeEndOfFirstPeriod(tierId);
        _requireValidTimestamp(timestamp);

        _lifeCycleStatus[tierId] = LifeCycleStatus.Ending; // Live(3) => Ending(5)
        LibMap.set(_lifeCycle, _add(tierId, 30), uint40(timestamp));
        emit EndOfLifeCycleSet(tierId, timestamp);
    }

    /// @dev Finish life cycle for `tierId`.
    /// 
    /// Note:
    /// The intention of this method is to reset all of the values that had been defined back to
    /// zero and change status from Paused(4) / Ending(5) to Finished(6). 
    /// 
    /// Requirements:
    /// - LifeCycleStatus must be at Paused(4) / Ending (5).
    ///   - If Paused(4): it can be initialized when current time has passed pause of life cycle.
    ///   - If Ending(5): it can be initialized when current time has passed end of life cycle
    /// ```
    function _finishLifeCycle(uint256 tierId) internal {
        _requireStatusIsPausedOrEnding(tierId);
        // Paused(4)
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Paused) {
            if (pauseOfLifeCycle(tierId) != 0) {
                if (block.timestamp <= pauseOfLifeCycle(tierId)) _revert(InvalidTimeToInitialize.selector);
                _lifeCycleStatus[tierId] = LifeCycleStatus.Finished; // Paused(4) => Finished(6)
                // Reset pause of life cycle, start of life cycle and life cycle values back to zero.
                LibMap.set(_lifeCycle, _add(tierId, 20), 0);
                LibMap.set(_lifeCycle, _add(tierId, 10), 0);
                LibMap.set(_lifeCycle, tierId, 0);
            }
        }
        // Ending(5)
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Ending) {
            if (endOfLifeCycle(tierId) != 0) {
                if (block.timestamp <= endOfLifeCycle(tierId)) _revert(InvalidTimeToInitialize.selector);
                _lifeCycleStatus[tierId] = LifeCycleStatus.Finished; // Ending(5) => Finished(6)
                // Reset end of life cycle, start of life cycle and life cycle values back to zero.
                LibMap.set(_lifeCycle, _add(tierId, 30), 0);
                LibMap.set(_lifeCycle, _add(tierId, 10), 0);
                LibMap.set(_lifeCycle, tierId, 0);
            }
        }

        emit LifeCycleIsFinished(tierId, block.timestamp);
    }

    ///////// INTERNAL LIFE CYCLE STATUS FOR TIER ID VALIDATORS /////////

    /// @dev LifeCycleStatus must be Live(3) for `tierId`.
    function _requireStatusIsLive(uint256 tierId) internal view {
        if (lifeCycleStatus(tierId) != LifeCycleStatus.Live) {
            _revert(InvalidLifeCycleStatus.selector);
        }
    }

    /// @dev LifeCycleStatus must be NotLive(0) /  Live(3) / Paused(4)
    function _requireStatusIsNotLiveOrLiveOrPaused(uint256 tierId) internal view {
        if (lifeCycleStatus(tierId) == LifeCycleStatus.ReadyToStart) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (lifeCycleStatus(tierId) == LifeCycleStatus.ReadyToLive) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Ending) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Finished) {
            _revert(InvalidLifeCycleStatus.selector);
        }
    }

    /// @dev LifeCycleStatus must be ReadyToStart(1) / ReadyToLive(2) for `tierId`.
    function _requireStatusIsReadyToStartOrReadyToLive(uint256 tierId) internal view {
        if (lifeCycleStatus(tierId) == LifeCycleStatus.NotLive) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Live) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Paused) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Ending) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Finished) {
            _revert(InvalidLifeCycleStatus.selector);
        }
    }

    /// @dev LifeCycleStatus must be Paused(4) / Ending(5) for `tierId`.
    function _requireStatusIsPausedOrEnding(uint256 tierId) internal view {
        if (lifeCycleStatus(tierId) == LifeCycleStatus.NotLive) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (lifeCycleStatus(tierId) == LifeCycleStatus.ReadyToStart) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (lifeCycleStatus(tierId) == LifeCycleStatus.ReadyToLive) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Live) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Finished) {
            _revert(InvalidLifeCycleStatus.selector);
        }
    }

    /// @dev Timestamp must be greater than block.timestamp but less than 1099511627775 (36812 AD).
    function _requireValidTimestamp(uint256 timestamp) internal view {
        if (timestamp <= block.timestamp) _revert(InvalidTimestamp.selector);
        if (timestamp > 0xFFFFFFFFFF) _revert(InvalidTimestamp.selector);
    }

    /// @dev Current timestamp must be greater than 48 hours before the end of first life cycle period.
    function _require48HrsBeforeEndOfFirstPeriod(uint256 tierId) internal view {
        uint256 _endOfFirstLifeCyclePeriod = _add(startOfLifeCycle(tierId), lifeCycle(tierId));
        // if (block.timestamp <= _sub(_endOfFirstLifeCyclePeriod, 172800)) {
        if (block.timestamp <= _sub(_endOfFirstLifeCyclePeriod, 120)) {                            // TESTNET !!!
            _revert(InvalidTimeToInitialize.selector);
        }
    }

    ///////// INTERNAL HELPER FUNCTIONS /////////

    /// @dev Unchecked arithmetic for adding two numbers.
    function _add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        unchecked {
            c = a + b;
        }
    }

    /// @dev Unchecked arithmetic for subtracting two numbers.
    function _sub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        unchecked {
            c = a - b;
        }
    }

    /// @dev Helper function for more efficient reverts.
    function _revert(bytes4 errorSelector) internal pure {
        assembly {
            mstore(0x00, errorSelector)
            revert(0x00, 0x04)
        }
    }
}