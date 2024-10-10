// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../TestLifeCycleConfig.sol";

contract ERC721TLCDropLifeCycleWhenPausedTest is TestLifeCycleConfig {
    
    /// Life Cycle ///

    function test_RevertIf_SetLifeCycle_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsLessThanFromPauseOfLifeCycle() public {
        _lifeCycleStatusIsPaused();

        vm.warp(PAUSE_OF_LIFE_CYCLE - 1 seconds); // 1 second before defined pause of life cycle

        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.setLifeCycle(TIER, 60);
    }

    function test_RevertIf_SetLifeCycle_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsAtPauseOfLifeCycle() public {
        _lifeCycleStatusIsPaused();

        vm.warp(PAUSE_OF_LIFE_CYCLE); // At pause of life cycle

        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.setLifeCycle(TIER, 60);
    }

    function test_SetLifeCycle_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsGreaterThanPauseOfLifeCycle() public {
        _lifeCycleStatusIsPaused();

        // Before
        ERC721TLCDrop.LifeCycleStatus statusBefore = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusBefore), uint8(LifeCycleStatus.Paused));
        assertEq(erc721TLCDrop.lifeCycle(TIER), LIFE_CYCLE * 86400);

        vm.warp(PAUSE_OF_LIFE_CYCLE + 1 seconds); // 1 second after pause of life cycle
        vm.prank(owner);
        vm.expectEmit();
        emit LifeCycleUpdate(TIER, 60 * 86400);
        erc721TLCDrop.setLifeCycle(TIER, 60);

        // After
        ERC721TLCDrop.LifeCycleStatus statusAfter = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusAfter), uint8(LifeCycleStatus.Paused));
        assertEq(erc721TLCDrop.lifeCycle(TIER), 60 * 86400);
    }

    /// Update Fee ///

    function test_RevertIf_SetUpdateFee_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsLessThanPauseOfLifeCycle() public {
        _lifeCycleStatusIsPaused();

        vm.warp(PAUSE_OF_LIFE_CYCLE - 1 seconds); // 1 second before pause of life cycle

        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.setUpdateFee(TIER, 0.069 ether);
    }

    function test_RevertIf_SetUpdateFee_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsAtPauseOfLifeCycle() public {
        _lifeCycleStatusIsPaused();

        vm.warp(PAUSE_OF_LIFE_CYCLE); // At pause of life cycle

        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.setUpdateFee(TIER, 0.069 ether);
    }

    function test_SetUpdateFee_WhenLifeCycleIsPaused_AndBlockTimestampIsGreaterThanPauseOfLifeCycle() public {
        _lifeCycleStatusIsPaused();

        vm.warp(PAUSE_OF_LIFE_CYCLE + 1 seconds); // 1 second after pause of life cycle

        vm.prank(owner);
        vm.expectEmit();
        emit TokenLifeCycleFeeUpdate(TIER, 0.069 ether);
        erc721TLCDrop.setUpdateFee(TIER, 0.069 ether);
    }

    /// Start of Life Cycle ///
    
    function test_RevertIf_SetStartOfLifeCycle_WhenLifeCycleStatusIsPaused() public {
        _lifeCycleStatusIsPaused();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);
    }

    /// Set Life Cycle to Live ///

    function test_RevertIf_SetLifeCycleToLive_WhenLifeCycleStatusIsPaused() public {
        _lifeCycleStatusIsPaused();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setLifeCycleToLive(TIER);
    }

    /// Pause of Life Cycle ///

    function test_RevertIf_PauseLifeCycle_WhenLifeCycleStatusIsPaused() public {
        _lifeCycleStatusIsPaused();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);
    }

    /// Unpause Life Cycle ///

    function test_UnpauseLifeCycle_WhenLifeCycleStatusIsPaused() public {
        _lifeCycleStatusIsPaused();

        // Before
        ERC721TLCDrop.LifeCycleStatus statusBefore = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusBefore), uint8(LifeCycleStatus.Paused));
        assertEq(erc721TLCDrop.pauseOfLifeCycle(TIER), PAUSE_OF_LIFE_CYCLE);

        vm.warp(PAUSE_OF_LIFE_CYCLE + 1 seconds); // 1 second after pause of life cycle
        vm.prank(owner);
        vm.expectEmit();
        emit LifeCycleIsUnpaused(TIER, PAUSE_OF_LIFE_CYCLE + 1 seconds);
        erc721TLCDrop.unpauseLifeCycle(TIER);

        // After
        ERC721TLCDrop.LifeCycleStatus statusAfter = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusAfter), uint8(LifeCycleStatus.Live));
        assertEq(erc721TLCDrop.pauseOfLifeCycle(TIER), 0); // Pause of life cycle reset back to zero
    }

    function test_RevertIf_UnpauseLifeCycle_WhenLifeCycleStatusIsPaused_ByNonOwnerOrAdmin() public {
        _lifeCycleStatusIsPaused();

        vm.warp(PAUSE_OF_LIFE_CYCLE + 1 seconds);

        vm.prank(address(0xBAD));
        vm.expectRevert(Unauthorized.selector);
        erc721TLCDrop.unpauseLifeCycle(TIER);
    }

    /// Finish Life Cycle ///

    function test_RevertIf_FinishLifeCycle_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsLessThanFromPauseOfLifeCycle() public {
        _lifeCycleStatusIsPaused();

        vm.warp(PAUSE_OF_LIFE_CYCLE - 1 seconds); // 1 second before pause of life cycle
        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.finishLifeCycle(TIER);
    }

    function test_RevertIf_FinishLifeCycle_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsAtPauseOfLifeCycle() public {
        _lifeCycleStatusIsPaused();

        vm.warp(PAUSE_OF_LIFE_CYCLE); // At pause of life cycle
        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.finishLifeCycle(TIER);
    }

    function test_FinishLifeCycle_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsGreaterThanPauseOfLifeCycle() public {
        _lifeCycleStatusIsPaused();

        // Before
        ERC721TLCDrop.LifeCycleStatus statusBefore = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusBefore), uint8(LifeCycleStatus.Paused));
        assertEq(erc721TLCDrop.lifeCycle(TIER), LIFE_CYCLE * 86400);
        assertEq(erc721TLCDrop.startOfLifeCycle(TIER), START_OF_LIFE_CYCLE);
        assertEq(erc721TLCDrop.updateFee(TIER), TOKEN_LIFECYCLE_UPDATE_FEE);
        assertEq(erc721TLCDrop.pauseOfLifeCycle(TIER), PAUSE_OF_LIFE_CYCLE);

        vm.warp(PAUSE_OF_LIFE_CYCLE + 1 seconds); // 1 second after pause of life cycle
        vm.prank(owner);
        vm.expectEmit();
        emit LifeCycleIsFinished(TIER, PAUSE_OF_LIFE_CYCLE + 1 seconds);
        erc721TLCDrop.finishLifeCycle(TIER);

        // After
        ERC721TLCDrop.LifeCycleStatus statusAfter = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusAfter), uint8(LifeCycleStatus.Finished));
        assertEq(erc721TLCDrop.lifeCycle(TIER), LIFE_CYCLE * 86400);
        assertEq(erc721TLCDrop.startOfLifeCycle(TIER), 0);
        assertEq(erc721TLCDrop.updateFee(TIER), 0);
        assertEq(erc721TLCDrop.pauseOfLifeCycle(TIER), 0);
    }

    /// Token Status ///

    function test_Get_TokenStatus_WhenLifeCycleStatusIsPaused_AndBlockTimestampIs48HourseBeforeEndOfFirstLifeCyclePeriod() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);
        assertEq(erc721TLCDrop.tokenStatus(1), "Active");
    }

    function test_Get_TokenStatus_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsGreaterThanEndOfLifeCycleToken() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) + 1 seconds); // 1 second after end of life cycle token
        assertEq(erc721TLCDrop.tokenStatus(1), "Inactive");
    }

    /// Start & End of Life Cycle Token ///

    function test_Get_StartOfLifeCycleToken_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsLessThanFromPauseOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        vm.warp(PAUSE_OF_LIFE_CYCLE - 1 seconds); // 1 second before pause of life cycle
        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), erc721TLCDrop.tokenTimestamp(1));
    }

    function test_Get_EndOfLifeCycleToken_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsLessThanFromPauseOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        vm.warp(PAUSE_OF_LIFE_CYCLE - 1 seconds); // 1 second before pause of life cycle
        assertEq(
            erc721TLCDrop.endOfLifeCycleToken(1),
            erc721TLCDrop.tokenTimestamp(1) + erc721TLCDrop.lifeCycleToken(1)
        );
    }

    function test_Get_StartOfLifeCycleToken_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsAtPauseOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        vm.warp(PAUSE_OF_LIFE_CYCLE); // At pause of life cycle
        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), erc721TLCDrop.tokenTimestamp(1));
    }

    function test_Get_EndOfLifeCycleToken_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsAtPauseOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        vm.warp(PAUSE_OF_LIFE_CYCLE); // At pause of life cycle
        assertEq(
            erc721TLCDrop.endOfLifeCycleToken(1),
            erc721TLCDrop.tokenTimestamp(1) + erc721TLCDrop.lifeCycleToken(1)
        );
    }

    function test_Get_StartOfLifeCycleToken_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsGreaterThanPauseOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        vm.warp(PAUSE_OF_LIFE_CYCLE + 1 seconds); // 1 second after pause of life cycle
        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), 0);
    }

    function test_Get_EndOfLifeCycleToken_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsGreaterThanPauseOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        vm.warp(PAUSE_OF_LIFE_CYCLE + 1 seconds); // 1 second after pause of life cycle
        assertEq(erc721TLCDrop.endOfLifeCycleToken(1), 0);
    }

    /// Update Token Fee ///

    function test_Get_UpdateTokenFee_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsLessThanFromPauseOfLifeCycle_AndRemainderIsGreaterThanLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE_2);

        assertEq(erc721TLCDrop.updateTokenFee(1), TOKEN_LIFECYCLE_UPDATE_FEE);
    }

    function test_Get_UpdateTokenFee_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsLessThanFromPauseOfLifeCycle_AndRemainderIsLessThanLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        uint256 remainder = PAUSE_OF_LIFE_CYCLE - END_OF_FIRST_LIFE_CYCLE_PERIOD;
        uint256 proportionalUpdateTokenFee = remainder * erc721TLCDrop.updateFee(TIER) / erc721TLCDrop.lifeCycle(TIER); // 0.021 ether
        assertEq(erc721TLCDrop.updateTokenFee(1), proportionalUpdateTokenFee);
    }

    function test_Get_UpdateTokenFee_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsAtPauseOfLifeCycle_AndRemainderIsZero() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        vm.warp(PAUSE_OF_LIFE_CYCLE); // At pause of life cycle
        assertEq(erc721TLCDrop.updateTokenFee(1), 0);
    }

    function test_Get_UpdateTokenFee_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsGreaterThanPauseOfLifeCycle_AndRemainderIsZero() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD);
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        vm.warp(PAUSE_OF_LIFE_CYCLE + 1 seconds); // 1 second after pause of life cycle
        assertEq(erc721TLCDrop.updateTokenFee(1), 0);
    }

    /// Update Token Life Cycle ///

    function test_RevertIf_UpdateTokenLifeCycle_WhenLifeCycleStatusIsPaused_ByNonTokenOwner() public {
        _tokenMintedAfterStartOfLifeCycle();
        
        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) + 1 seconds); // 1 second after end of life cycle token
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        uint256 proportionalUpdateTokenFee = erc721TLCDrop.updateTokenFee(1);

        hoax(address(0xBAD), 1 ether);
        vm.expectRevert(InvalidOwner.selector);
        erc721TLCDrop.updateTokenLifeCycle{value: proportionalUpdateTokenFee}(1);
    }

    function test_UpdateTokenLifeCycle_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsGreaterThanEndOfLifeCycleToken() public {
        _tokenMintedAfterStartOfLifeCycle();
        
        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) + 1 seconds); // 1 second after end of life cycle token
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        // Token status before
        assertEq(erc721TLCDrop.tokenStatus(1), "Inactive");

        uint256 proportionalUpdateTokenFee = erc721TLCDrop.updateTokenFee(1);

        vm.startPrank(tokenOwner);
        vm.deal(tokenOwner, 0.021 ether);
        vm.expectEmit();
        emit TokenLifeCycleUpdate(
            1,
            TIER,
            erc721TLCDrop.endOfLifeCycleToken(1) + 1 seconds,
            erc721TLCDrop.lifeCycle(TIER)
        );
        emit MetadataUpdate(1);
        erc721TLCDrop.updateTokenLifeCycle{value: proportionalUpdateTokenFee}(1); // 20999967592592592 wei
        vm.stopPrank();

        // Token status after
        assertEq(erc721TLCDrop.tokenStatus(1), "Active");
    }

    function test_UpdateTokenLifeCycle_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsTwoHoursBeforeEndOfLifeCycleToken() public {
        _tokenMintedAfterStartOfLifeCycle();
        
        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) - 2 hours); // block.timestamp is 2 hours before end of life cycle token
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        // Token status before
        assertEq(erc721TLCDrop.tokenStatus(1), "Active");

        uint256 proportionalUpdateTokenFee = erc721TLCDrop.updateTokenFee(1);

        vm.startPrank(tokenOwner);
        vm.deal(tokenOwner, 0.0212 ether);
        vm.expectEmit();
        emit TokenLifeCycleUpdate(
            1,
            TIER,
            erc721TLCDrop.endOfLifeCycleToken(1) - 2 hours,
            erc721TLCDrop.lifeCycle(TIER)
        );
        emit MetadataUpdate(1);
        erc721TLCDrop.updateTokenLifeCycle{value: proportionalUpdateTokenFee}(1); // 21116650462962962 wei
        vm.stopPrank();

        // Token status after
        assertEq(erc721TLCDrop.tokenStatus(1), "Active");
    }

    function test_RevertIf_UpdateTokenLifeCycle_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsGreaterThanTwoHoursBeforeEndOfLifeCycleToken() public {
        _tokenMintedAfterStartOfLifeCycle();
        
        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) - 2 hours - 1 seconds); // 1 second before 2 hours before end of life cycle token
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        uint256 proportionalUpdateTokenFee = erc721TLCDrop.updateTokenFee(1);

        vm.prank(tokenOwner);
        vm.deal(tokenOwner, 0.0212 ether);
        vm.expectRevert(InvalidTimeToUpdate.selector);
        erc721TLCDrop.updateTokenLifeCycle{value: proportionalUpdateTokenFee}(1);
    }

    function test_UpdateTokenLifeCycle_WhenLifeCycleStatusIsPaused_AndBlockTimestampIs60SecondsBeforePauseOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        vm.warp(PAUSE_OF_LIFE_CYCLE - 60 seconds); // 60 seconds before pause of life cycle

        uint256 proportionalUpdateTokenFee = erc721TLCDrop.updateTokenFee(1);

        vm.startPrank(tokenOwner);
        vm.deal(tokenOwner, 0.00973 ether);
        vm.expectEmit();
        emit TokenLifeCycleUpdate(
            1,
            TIER,
            PAUSE_OF_LIFE_CYCLE - 60 seconds,
            erc721TLCDrop.lifeCycle(TIER)
        );
        emit MetadataUpdate(1);
        erc721TLCDrop.updateTokenLifeCycle{value: proportionalUpdateTokenFee}(1); // 972222222222 wei
        vm.stopPrank();
    }

    function test_RevertIf_UpdateTokenLifeCycle_WhenLifeCycleStatusIsPaused_AndBlockTimestampIsLessThanFrom60SecondsBeforeEndOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        vm.warp(PAUSE_OF_LIFE_CYCLE - 60 seconds + 1 seconds); // 59 seconds before pause of life cycle

        uint256 proportionalUpdateTokenFee = erc721TLCDrop.updateTokenFee(1);

        vm.prank(tokenOwner);
        vm.deal(tokenOwner, 0.00973 ether);
        vm.expectRevert(InvalidTimeToUpdate.selector);
        erc721TLCDrop.updateTokenLifeCycle{value: proportionalUpdateTokenFee}(1); 
    }
}