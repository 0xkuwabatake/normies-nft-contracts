// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "solady/utils/LibMap.sol";

/// @notice A contract logic for tier-based life cycle status management.
/// @author 0xkuwabatake(@0xkuwabatake)
abstract contract TierLifeCycle {
    using LibMap for uint256;

    ///////// ENUM ////////////////////////////////////////////////////////////////////////////////O-'

    /// @dev Life Cycle status.
    ///
    /// Note:
    /// - #0 - NotLive      : initial state of a life cycle.
    /// - #1 - ReadyToStart : length of life cycle in total seconds is defined and it's ready to start.
    /// - #2 - ReadyToLive  : start of life cycle timestamp is defined and it's ready to live.
    /// - #3 - Live         : life cycle is at live period.
    /// - #4 - Paused       : life cycle period is at paused period.
    /// - #5 - Ending       : end of life cycle timestamp is defined (life cycle is at ending period).
    /// - #6 - Finished     : life cycle period is finished and it can never go back to re-live.
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

    
    /// @dev Mapping from `tierId` => life cycle related values.
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

    ///////// INTERNAL LIFE CYCLE FOR A TIER ID SETTERS /////////

    /// @dev Sets life cycle for `tierId`.
    /// 
    /// Note:
    /// Life cycle is length of a life cycle period in total seconds. 
    /// - It is mandatory to be defined before any type of mint events for `tierId`. 
    ///   A non-zero value of it is part of additional mint extra data that would be initialized 
    ///   when every token is minted under `tierId` -- see {ERC721TLC - _safeMintTier}. -- 
    ///   this mandatory condition must be well validated at child contract.
    /// - Once it is defined, it cannot be reset back to zero even after the life cyle period
    ///   is Finished(6) -- see {_finishLifeCycle}.
    /// 
    /// Requirements:
    /// - LifeCycleStatus must be at: NotLive(0) / Live(3) / Paused(4).
    /// - `numberOfDays` must be at least equal to or greater than 30 days.
    /// - If Live(3): `numberOfDays` is able to be reinitialized start from 48 hours before 
    ///   the end of first life cycle period.
    /// - If Paused(4): `numberOfDays` is able to be reinitialized after tx's block.timestamp
    ///   is greater than pause of life cycle timestamp that had been defined. 
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
            if (block.timestamp < _sub(_endOfFirstLifeCyclePeriod, 120)) {                         // TESTNET !!!
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
    /// Start of life cycle is a mark time of the beginning of life cycle period. 
    /// - Once it had been defined and life cycle status is Live(3), it can never be reinitialized. 
    /// - It only can reset back to zero value after {_finishLifeCycle}.
    /// 
    /// Requirements:
    /// - LifeCycleStatus must be at: ReadyToStart(1) / ReadyToLive(2).
    /// - `timestamp` is valid if following what is defined at {_requireValidTimestamp}.
    /// - If ReadyToLive(2): `timestamp` is able to be reinitialized -- just in case 
    ///   the tx's block.timestamp when calling {_setLifeCycleToLive} is greater than
    ///   the previous start of life cycle timestamp that had been defined.
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
    /// - When it goes Live(3), all of existing (minted) & non-existent (not been minted yet) token
    //    statuses under `tierId` will start to have their own start and end of life cycle token 
    ///   relatively based on its current token timestamp comparing to 
    ///   defined start of life cycle timestamp -- see: {ERC721TLCToken - startOfLifeCycleToken}, 
    ///   {ERC721TLCToken - endOfLifeCycleToken}.
    /// 
    /// Requirements:
    /// - LifeCycleStatus must be at ReadyToLive(2).
    /// - Tx's block.timestamp when calling this method must not be greater than 
    ///   the defined start of life cycle timestamp. If it is violated, it still can be reinitiated 
    ///   after start of life cycle is being reinitialized -- see {_setStartOfLifeCycle}. 
    /// ```
    function _setLifeCycleToLive(uint256 tierId) internal {
        if (lifeCycleStatus(tierId) != LifeCycleStatus.ReadyToLive) _revert(InvalidLifeCycleStatus.selector);
        if (block.timestamp > startOfLifeCycle(tierId)) _revert(InvalidTimeToInitialize.selector);
        _lifeCycleStatus[tierId] = LifeCycleStatus.Live; // ReadyToLive(2) => Live(3)
        emit LifeCycleIsLive(tierId, block.timestamp);
    }

    /// @dev Sets life cycle status for `tierId` to Paused(4).
    /// 
    /// Note:
    /// Pause of a life cycle is a mark time for the ongoing life cycle period to be stopped 
    /// temporarily.
    /// - Once it had been defined, the fee to update token life cycle would be calculated
    ///   proportionally when the current time (block.timestamp) is started to have a remainder 
    ///   which less than its life cycle token -- see {ERC721TLCToken - updateTokenFee}.
    /// - When the current time has passed its defined pause of life cycle timestamp,
    ///   all of the token statuses would immediately go back to `Active` as per default -- 
    ///   see {ERC721TLCToken - tokenStatus}.
    /// - After current time had passed its defined pause of life cycle timestamp, 
    ///   there's an option to finish the life cycle period permanently -- see {finishLifeCycle}.
    /// 
    /// Requirements:
    /// - LifeCycleStatus must be at Live(3).
    /// - `timestamp` is valid if following what is defined at {_requireValidTimestamp}.
    /// - If the current time is at the first of life cycle period, it only can be initialized 
    ///   start from 48 hours (172800 seconds) before the end of its period. 
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
    /// temporarily (paused) to go back to Live(3) status -- see {_pauseOfLifeCycle}.
    /// - It can be unpaused at anytime after it'd been initialized. When its unpaused, 
    ///   life cycle status would immediately go back to Live(3) -- see {_unpauseLifeCycle}.
    /// 
    /// Requirement:
    /// - LifeCycleStatus must be at Paused(4).
    /// ```
    function _unpauseLifeCycle(uint256 tierId) internal {
        if (lifeCycleStatus(tierId) != LifeCycleStatus.Paused) _revert(InvalidLifeCycleStatus.selector);
        _lifeCycleStatus[tierId] = LifeCycleStatus.Live; // Paused(4) => Live(3)
        LibMap.set(_lifeCycle, _add(tierId, 20), 0);
        emit LifeCycleIsUnpaused(tierId, block.timestamp);
    }

    /// @dev Sets end of life cycle for `tierId`.
    /// 
    /// Note:
    /// End of life cycle is a mark time of the ending of life cycle period. 
    /// - Once it had been defined, it cannot be cancelled, therefore use it wisely!
    /// - Once it had been defined, the fee to update token life cycle would be calculated
    ///   proportionally when the current time is started to have a remainder which less than
    ///   length of life cycle token - see {ERC721TLCToken - updateTokenFee}.
    /// - When current time has passed its defined end of life cycle timestamp,
    ///   all of the token statuses would immediately go back to `Active` as per default 
    ///   -- see {ERC721TLCToken - tokenStatus}.
    /// - When current time has passed its defined end of life cycle timestamp,
    ///   it's strongly recommended to finish the life cycle period once for all 
    ///   -- see {finishLifeCycle}.
    /// 
    /// Requirements:
    /// - LifeCycleStatus must be at Live(3).
    /// - `timestamp` is valid if following what is defined at {_requireValidTimestamp}.
    /// - If the current time is at the first of life cycle period, it only can be initialized 
    ///   start from 48 hours (172800 seconds) before the end of its first period. 
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
    /// The intention of this method is to change status from Paused(4) / Ending(5) to Finished(6)
    /// and reset start and end life cycle for `tierId` values that had been defined back to zero, 
    /// except the last defined value of life cycle for `tierId`.
    /// 
    /// Requirements:
    /// - LifeCycleStatus must be at Paused(4) / Ending (5).
    /// - If Paused(4): it can be initialized when tx's block.timestamp is greater than defined
    ///   pause of life cycle timestamp.
    /// - If Ending(5): it can be initialized when tx's block.timestamp is greater than defined
    ///   end of life cycle timestamp.
    /// ```
    function _finishLifeCycle(uint256 tierId) internal {
        _requireStatusIsPausedOrEnding(tierId);
        // Paused(4)
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Paused) {
            if (block.timestamp <= pauseOfLifeCycle(tierId)) _revert(InvalidTimeToInitialize.selector);
            _lifeCycleStatus[tierId] = LifeCycleStatus.Finished; // Paused(4) => Finished(6)
            // Reset pause of life cycle and start of life cycle back to zero.
            LibMap.set(_lifeCycle, _add(tierId, 20), 0);
            LibMap.set(_lifeCycle, _add(tierId, 10), 0);
        }
        // Ending(5)
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Ending) {
            if (block.timestamp <= endOfLifeCycle(tierId)) _revert(InvalidTimeToInitialize.selector);
            _lifeCycleStatus[tierId] = LifeCycleStatus.Finished; // Ending(5) => Finished(6)
            // Reset end of life cycle and start of life cycle back to zero.
            LibMap.set(_lifeCycle, _add(tierId, 30), 0);
            LibMap.set(_lifeCycle, _add(tierId, 10), 0);
        }

        emit LifeCycleIsFinished(tierId, block.timestamp);
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

    ///////// PRIVATE LIFE CYCLE STATUS FOR TIER ID VALIDATORS /////////

    /// @dev LifeCycleStatus must be at Live(3) for `tierId`.
    function _requireStatusIsLive(uint256 tierId) private view {
        if (lifeCycleStatus(tierId) != LifeCycleStatus.Live) {
            _revert(InvalidLifeCycleStatus.selector);
        }
    }

    /// @dev LifeCycleStatus must be at NotLive(0) /  Live(3) / Paused(4)
    function _requireStatusIsNotLiveOrLiveOrPaused(uint256 tierId) private view {
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

    /// @dev LifeCycleStatus must be at ReadyToStart(1) / ReadyToLive(2) for `tierId`.
    function _requireStatusIsReadyToStartOrReadyToLive(uint256 tierId) private view {
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

    /// @dev LifeCycleStatus must be at Paused(4) / Ending(5) for `tierId`.
    function _requireStatusIsPausedOrEnding(uint256 tierId) private view {
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
    function _requireValidTimestamp(uint256 timestamp) private view {
        if (timestamp <= block.timestamp) _revert(InvalidTimestamp.selector);
        if (timestamp > 0xFFFFFFFFFF) _revert(InvalidTimestamp.selector);
    }

    /// @dev Current time must have passed 48 hours before the end of first life cycle period.
    /// Note: first of life cycle period is start of life cycle timestamp plus life cycle in total seconds.
    function _require48HrsBeforeEndOfFirstPeriod(uint256 tierId) private view {
        uint256 _endOfFirstLifeCyclePeriod = _add(startOfLifeCycle(tierId), lifeCycle(tierId));
        // if (block.timestamp <= _sub(_endOfFirstLifeCyclePeriod, 172800)) {
        if (block.timestamp < _sub(_endOfFirstLifeCyclePeriod, 120)) {                             // TESTNET !!!
            _revert(InvalidTimeToInitialize.selector);
        }
    }
}