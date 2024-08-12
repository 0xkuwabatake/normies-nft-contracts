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

    ///////// MODIFIERS ///////////////////////////////////////////////////////////////////////////O-'

    /// @dev LifeCycleStatus must be ReadyToLive(2) for `tierId`.
    modifier isReadyToLive(uint256 tierId) {
        if (lifeCycleStatus(tierId) != LifeCycleStatus.ReadyToLive) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        _;
    }

    /// @dev LifeCycleStatus must be Live(3) for `tierId`.
    modifier isLive(uint256 tierId) {
        if (lifeCycleStatus(tierId) != LifeCycleStatus.Live) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        _;
    }

    /// @dev LifeCycleStatus must be Paused(4) for `tierId`.
    modifier isPaused(uint256 tierId) {
        if (lifeCycleStatus(tierId) != LifeCycleStatus.Paused) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        _;
    }

    /// @dev LifeCycleStatus must be NOT Ending(5) /  NOT Finished(6) for `tierId`.
    /// See: {TierLifeCycle - LifeCycleStatus}.
    modifier isNotEndingOrNotFinished(uint256 tierId) {
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Ending) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Finished) {
            _revert(InvalidLifeCycleStatus.selector);
        }
        _;
    }

    /// @dev LifeCycleStatus must be ReadyToStart(1) / ReadyToLive(2) for `tierId`.
    modifier isReadyToStartOrReadyToLive(uint256 tierId) {
        if (lifeCycleStatus(tierId) == LifeCycleStatus.NotLive) {
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
        _;
    }

    /// @dev LifeCycleStatus must be Paused(4) / Ending(5) for `tierId`.
    modifier isPausedOrEnding(uint256 tierId) {
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
        _;
    }

    /// @dev Timestamp must be greater than block.timestamp but less than 1099511627775 (36812 AD).
    modifier isValidTimestamp(uint256 timestamp) {
        if (timestamp <= block.timestamp) _revert(InvalidTimestamp.selector);
        if (timestamp > 0xFFFFFFFFFF) _revert(InvalidTimestamp.selector);
        _;
    }

    /// @dev Current timestamp must be greater than 48 hours before the end of first life cycle period.
    modifier is48hrsBeforeEndOfFirstPeriod(uint256 tierId) {
        uint256 _endOfFirstLifeCyclePeriod = _add(startOfLifeCycle(tierId), lifeCycle(tierId));
        // if (block.timestamp <= _sub(_endOfFirstLifeCyclePeriod, 172800)) {
        if (block.timestamp <= _sub(_endOfFirstLifeCyclePeriod, 120)) {                            // TESTNET !!!
            _revert(InvalidTimeToInitialize.selector);
        }
        _;    
    }

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

    /// @dev Initialized life cycle for `tierId` unchecked.
    /// Note: It's an unchecked method to be called inside constructor method at child contract.
    function _initLifeCycleUnchecked(uint256 tierId, uint256 totalSeconds) internal {
        _lifeCycleStatus[tierId] = LifeCycleStatus.ReadyToStart;
        LibMap.set(_lifeCycle, tierId, uint40(totalSeconds));
        emit LifeCycleUpdate(tierId, totalSeconds);
    }

    /// @dev Sets life cycle for `tierId`.
    // function _setLifeCycle(uint256 tierId, uint256 numberOfDays) 
    function _setLifeCycle(uint256 tierId, uint256 numberOfMinutes)                                // TESTNET !!!                      
        internal
        isNotEndingOrNotFinished(tierId)
    { 
        // `numberOfDays` must at least equal to or greater than 30 days.
        // if (numberOfDays < 30) _revert(InvalidNumberOfDays.selector);                        
        // uint256 _totalSeconds = numberOfDays * 86400; 
        if (numberOfMinutes < 10) _revert(InvalidNumberOfDays.selector);                           // TESTNET !!!
        uint256 _totalSeconds = numberOfMinutes * 60;                                              // TESTNET !!!

        // The defauult condition is when life cycle status is NotLive(0).
        if (lifeCycleStatus(tierId) == LifeCycleStatus.NotLive) {
            _lifeCycleStatus[tierId] = LifeCycleStatus.ReadyToStart; // NotLive(0) => ReadyToStart(1)
            LibMap.set(_lifeCycle, tierId, uint40(_totalSeconds));
        }

        // When life cycle status is ReadyToStart(1) or ReadyToLive(2).
        if (
            (lifeCycleStatus(tierId) == LifeCycleStatus.ReadyToStart) ||
            (lifeCycleStatus(tierId) == LifeCycleStatus.ReadyToLive)
           ) 
        {
            LibMap.set(_lifeCycle, tierId, uint40(_totalSeconds));
        }

        // When life cycle status is Live(3):
        // The value is able to be re-initialized starts from 48 hours before 
        // the end of first life cycle period.
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Live) {
            uint256 _endOfFirstLifeCyclePeriod = _add(startOfLifeCycle(tierId), lifeCycle(tierId));
            // if (block.timestamp <= _sub(_endOfFirstLifeCyclePeriod, 172800)) {
            if (block.timestamp <= _sub(_endOfFirstLifeCyclePeriod, 120)) {                        // TESTNET !!!
                _revert(InvalidTimeToInitialize.selector);
            } 
            LibMap.set(_lifeCycle, tierId, uint40(_totalSeconds));
        }

        // When life cycle status is Paused(4),
        // The value is able to be re-initialized after current time had passed 
        // pause of life cycle timestamp that had been defined.
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Paused) {
            if (block.timestamp <= pauseOfLifeCycle(tierId)) _revert(InvalidTimeToInitialize.selector);
            LibMap.set(_lifeCycle, tierId, uint40(_totalSeconds));
        }

        emit LifeCycleUpdate(tierId, _totalSeconds);
    }

    /// @dev Sets start of life cycle for `tierId`.
    function _setStartOfLifeCycle(uint256 tierId, uint256 timestamp)
        internal
        isValidTimestamp(timestamp)
        isReadyToStartOrReadyToLive(tierId)
    {
        // The default condition is when life cycle status is ReadyToStart(1).
        if (lifeCycleStatus(tierId) == LifeCycleStatus.ReadyToStart) {
            _lifeCycleStatus[tierId] = LifeCycleStatus.ReadyToLive; // ReadyToStart(1) => ReadyToLive(2)
            LibMap.set(_lifeCycle, _add(tierId, 10), uint40(timestamp));
        }

        // When life cycle status is ReadyToLive(2):
        // The value is still able to be re-initialized, just in case tx's block.timestamp
        // when setting the life cycle to Live(3) status had passed the start of life cycle
        // that had been defined -- see {_setLifeCycleToLive}.
        if (lifeCycleStatus(tierId) == LifeCycleStatus.ReadyToLive) {
            LibMap.set(_lifeCycle, _add(tierId, 10), uint40(timestamp));
        }
        
        emit StartOfLifeCycleUpdate(tierId, timestamp);
    }

    /// @dev Sets life cycle status for `tierId` to Live.
    function _setLifeCycleToLive(uint256 tierId)
        internal
        isReadyToLive(tierId)
    {
        if (block.timestamp >= startOfLifeCycle(tierId)) _revert(InvalidTimeToInitialize.selector);
        _lifeCycleStatus[tierId] = LifeCycleStatus.Live; // ReadyToLive(2) => Live(3)
        emit LifeCycleIsLive(tierId, block.timestamp);
    }

    /// @dev Sets life cycle status for `tier` to Paused.
    function _pauseLifeCycle(uint256 tierId, uint256 timestamp)
        internal
        isLive(tierId)
        isValidTimestamp(timestamp)
        is48hrsBeforeEndOfFirstPeriod(tierId)
    {
        _lifeCycleStatus[tierId] = LifeCycleStatus.Paused; // Live(3) => Paused(4)
        LibMap.set(_lifeCycle, _add(tierId, 20), uint40(timestamp));
        emit LifeCycleIsPaused(tierId, timestamp);
    }

    /// @dev Unpause life cycle status for `tierId`.
    function _unpauseLifeCycle(uint256 tierId)
        internal
        isPaused(tierId)
    {
        _lifeCycleStatus[tierId] = LifeCycleStatus.Live; // Paused(4) => Live(3)
        LibMap.set(_lifeCycle, _add(tierId, 20), 0);
        emit LifeCycleIsUnpaused(tierId, block.timestamp);
    }

    /// @dev Sets end of life cycle for `tierId`.
    function _setEndOfLifeCycle(uint256 tierId, uint256 timestamp)
        internal
        isLive(tierId)
        isValidTimestamp(timestamp)
        is48hrsBeforeEndOfFirstPeriod(tierId)
    {
        _lifeCycleStatus[tierId] = LifeCycleStatus.Ending; // Live(3) => Ending(5)
        LibMap.set(_lifeCycle, _add(tierId, 30), uint40(timestamp));

        emit EndOfLifeCycleSet(tierId, timestamp);
    }

    /// @dev Finish life cycle for `tierId`.
    function _finishLifeCycle(uint256 tierId)
        internal
        isPausedOrEnding(tierId)
    {
        // When life cycle status is Paused(4).
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Paused) {
            _lifeCycleStatus[tierId] = LifeCycleStatus.Finished; // Paused(4) => Finished(6)
            // Reset pause of life cycle, start of life cycle and life cycle values back to zero.
            LibMap.set(_lifeCycle, _add(tierId, 20), 0);
            LibMap.set(_lifeCycle, _add(tierId, 10), 0);
            LibMap.set(_lifeCycle, tierId, 0);
        }
        // When life cycle status is Ending(5),
        // the reset operation is able to be initialized if current time has passed the end of life cycle.
        if (lifeCycleStatus(tierId) == LifeCycleStatus.Ending) {
            if (block.timestamp <= endOfLifeCycle(tierId)) _revert(InvalidTimeToInitialize.selector);
            _lifeCycleStatus[tierId] = LifeCycleStatus.Finished; // Ending(5) => Finished(6)
            // Reset end of life cycle, start of life cycle and life cycle values back to zero.
            LibMap.set(_lifeCycle, _add(tierId, 30), 0);
            LibMap.set(_lifeCycle, _add(tierId, 10), 0);
            LibMap.set(_lifeCycle, tierId, 0);
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
}