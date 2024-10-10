// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../TestLifeCycleConfig.sol";

contract ERC721TLCDropLifeCycleWhenLiveTest is TestLifeCycleConfig {
    
    /// Life Cycle ///

    function test_RevertIf_SetLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIsLessThanFrom48HoursBeforeEndOfFirstLifeCyclePeriod() public {
        _lifeCycleStatusIsReadyToLive();

        vm.warp(START_OF_LIFE_CYCLE - 1 seconds); // 1 second before start of life cycle
        erc721TLCDrop.setLifeCycleToLive(TIER);

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days - 1 seconds); // 1 second before 48 hours before end of first life cycle period
        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.setLifeCycle(TIER, 60);
    }

    function test_SetLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIs48HoursBeforeEndOfFirstLifeCyclePeriod() public {
        _lifeCycleStatusIsReadyToLive();

        vm.warp(START_OF_LIFE_CYCLE - 1 seconds); // 1 second before start of life cycle
        erc721TLCDrop.setLifeCycleToLive(TIER);

        // Before
        ERC721TLCDrop.LifeCycleStatus statusBefore = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusBefore), uint8(LifeCycleStatus.Live));
        assertEq(erc721TLCDrop.lifeCycle(TIER), LIFE_CYCLE * 86400);

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        vm.prank(owner);
        vm.expectEmit();
        emit LifeCycleUpdate(TIER, 90 * 86400);
        erc721TLCDrop.setLifeCycle(TIER, 90);

        // After
        ERC721TLCDrop.LifeCycleStatus statusAfter = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusAfter), uint8(LifeCycleStatus.Live));
        assertEq(erc721TLCDrop.lifeCycle(TIER), 90 * 86400);
    }

    /// Start of Life Cycle ///

    function test_RevertIf_SetStartOfLifeCycle_WhenLifeCycleStatusIsLive() public {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);

        vm.warp(START_OF_LIFE_CYCLE - 1 seconds); // 1 second before start of life cycle
        erc721TLCDrop.setLifeCycleToLive(TIER);

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);
    }

    /// Update Fee ///

    function test_RevertIf_SetUpdateFee_WhenLifeCycleStatusIsLive_AndBlockTimestampIsGreaterThan48HoursBeforeEndOfFirstLifeCyclePeriod() public {
        _lifeCycleStatusIsReadyToLive();

        vm.warp(START_OF_LIFE_CYCLE - 1 days); // 1 day before start of life cycle
        erc721TLCDrop.setLifeCycleToLive(TIER);

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days - 1 seconds); // 1 second before 48 hours before end of first life cycle period
        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.setUpdateFee(TIER, 0.069 ether);
    }

    function test_SetUpdateFee_WhenLifeCycleStatusIsLive_AndBlockTimestampIs48HoursBeforeEndOfFirstLifeCyclePeriod() public {
        _lifeCycleStatusIsReadyToLive();

        vm.warp(START_OF_LIFE_CYCLE - 1 days); // 1 day before start of life cycle
        erc721TLCDrop.setLifeCycleToLive(TIER);

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of life cycle period
        vm.prank(owner);
        vm.expectEmit();
        emit TokenLifeCycleFeeUpdate(TIER, 0.069 ether);
        erc721TLCDrop.setUpdateFee(TIER, 0.069 ether);
    }

    /// Set Life Cycle to Live ///

    function test_RevertIf_SetLifeCycleToLive_WhenLifeCycleStatusIsLive() public {
        _lifeCycleStatusIsReadyToLive();

        vm.warp(START_OF_LIFE_CYCLE - 1 days); // 1 day before start of life cycle
        erc721TLCDrop.setLifeCycleToLive(TIER);

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setLifeCycleToLive(TIER);
    }

    /// Pause Life Cycle ///

    function test_PauseLifeCycle_WhenLifeCycleStatusIsLive() public {
        _lifeCycleStatusIsLive();

        // Before
        ERC721TLCDrop.LifeCycleStatus statusBefore = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusBefore), uint8(LifeCycleStatus.Live));
        assertEq(erc721TLCDrop.pauseOfLifeCycle(TIER), 0);

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period 
        vm.prank(owner);
        vm.expectEmit();
        emit LifeCycleIsPaused(TIER, PAUSE_OF_LIFE_CYCLE);
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);

        // After
        ERC721TLCDrop.LifeCycleStatus statusAfter = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusAfter), uint8(LifeCycleStatus.Paused));
        assertEq(erc721TLCDrop.pauseOfLifeCycle(TIER), PAUSE_OF_LIFE_CYCLE);
    }

    function test_PauseLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIs48HoursBeforeEndOfFirstLifeCyclePeriod() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        vm.prank(owner);
        vm.expectEmit();
        emit LifeCycleIsPaused(TIER, PAUSE_OF_LIFE_CYCLE);
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);
    }

    function test_RevertIf_PauseLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIsGreaterThan48HoursBeforeEndOfFirstLifeCyclePeriod() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days - 1 seconds); // 1 second before 48 hours before end of first life cycle period
        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);
    }

    function test_RevertIf_PauseLifeCycle_WhenLifeCycleStatusIsLive_IfTimestampIsEqualToBlockTimestamp() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period 
        vm.prank(owner);
        vm.expectRevert(InvalidTimestamp.selector);
        erc721TLCDrop.pauseLifeCycle(TIER, END_OF_FIRST_LIFE_CYCLE_PERIOD); // Timestamp is equal to block.timestamp
    }

    function test_RevertIf_PauseLifeCycle_WhenLifeCycleStatusIsLive_IfTimestampIsLessThanBlockTimestamp() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period 
        vm.prank(owner);
        vm.expectRevert(InvalidTimestamp.selector);
        erc721TLCDrop.pauseLifeCycle(TIER, END_OF_FIRST_LIFE_CYCLE_PERIOD - 1 seconds); // Timestamp is 1 second before block.timestamp
    }

    function test_RevertIf_PauseLifeCycle_WhenLifeCycleStatusIsLive_IfTimestampIsGreaterThanMaxUint40Value() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD);
        vm.prank(owner);
        vm.expectRevert(InvalidTimestamp.selector);
        erc721TLCDrop.pauseLifeCycle(TIER, 1099511627775 + 1);
    }

    function test_PauseLifeCycle_WhenLifeCycleStatusIsLive_IfTimestampIsEqualToMaxUint40Value() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD);
        vm.prank(owner);
        vm.expectEmit();
        emit LifeCycleIsPaused(TIER, 1099511627775);
        erc721TLCDrop.pauseLifeCycle(TIER, 1099511627775);
    }

    function test_RevertIf_PauseLifeCycle_WhenLifeCycleStatusIsLive_ByNonOwnerOrAdmin() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD);
        vm.prank(address(0xBAD));
        vm.expectRevert(Unauthorized.selector);
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);
    }

    /// End of Life Cycle ///

    function test_SetEndOfLifeCycle_WhenLifeCycleStatusIsLive() public {
        _lifeCycleStatusIsLive();

        // Before
        ERC721TLCDrop.LifeCycleStatus statusBefore = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusBefore), uint8(LifeCycleStatus.Live));
        assertEq(erc721TLCDrop.endOfLifeCycle(TIER), 0);

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        vm.prank(owner);
        vm.expectEmit();
        emit EndOfLifeCycleSet(TIER, END_OF_LIFE_CYCLE);
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        // After
        ERC721TLCDrop.LifeCycleStatus statusAfter = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusAfter), uint8(LifeCycleStatus.Ending));
        assertEq(erc721TLCDrop.endOfLifeCycle(TIER), END_OF_LIFE_CYCLE);
    }

    function test_SetEndOfLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIs48HoursBeforeEndOfFirstLifeCyclePeriod() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        vm.prank(owner);
        vm.expectEmit();
        emit EndOfLifeCycleSet(TIER, END_OF_LIFE_CYCLE);
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);
    }

    function test_RevertIf_SetEndOfLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIsMoreThan48HoursBeforeEndOfFirstLifeCyclePeriod() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days - 1 seconds); // 1 second before 48 hours before end of first life cycle period
        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);
    }

    function test_RevertIf_SetEndOfLifeCycle_WhenLifeCycleStatusIsLive_IfTimestampIsEqualToBlockTimestamp() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        vm.prank(owner);
        vm.expectRevert(InvalidTimestamp.selector);
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_FIRST_LIFE_CYCLE_PERIOD); // Timestamp is equal to block.timestamp
    }

    function test_RevertIf_SetEndOfLifeCycle_WhenLifeCycleStatusIsLive_IfTimestampIsLessThanBlockTimestamp() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        vm.prank(owner);
        vm.expectRevert(InvalidTimestamp.selector);
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_FIRST_LIFE_CYCLE_PERIOD - 1 seconds); // Timestamp is 1 second before block.timestamp
    }

    function test_RevertIf_SetEndOfLifeCycle_WhenLifeCycleStatusIsLive_IfTimestampIsGreaterThanMaxUint40Value() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        vm.prank(owner);
        vm.expectRevert(InvalidTimestamp.selector);
        erc721TLCDrop.setEndOfLifeCycle(TIER, 1099511627775 + 1);
    }

    function test_SetEndOfLifeCycle_WhenLifeCycleStatusIsLive_IfTimestampIsEqualToMaxUint40Value() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        vm.prank(owner);
        vm.expectEmit();
        emit EndOfLifeCycleSet(TIER, 1099511627775);
        erc721TLCDrop.setEndOfLifeCycle(TIER, 1099511627775);
    }

    function test_RevertIf_SetEndOfLifeCycle_WhenLifeCycleStatusIsLive_ByNonOwnerOrAdmin() public {
        _lifeCycleStatusIsLive();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        vm.prank(address(0xBAD));
        vm.expectRevert(Unauthorized.selector);
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);
    }

    /// Token Status ///

    function test_Get_TokenStatus_WhenLifeCycleStatusIsLive() public {
        _tokenMintedAfterStartOfLifeCycle();
        assertEq(erc721TLCDrop.tokenStatus(1), "Active");
    }

    function test_Get_TokenStatus_WhenLifeCycleStatusIsLive_AndBlockTimestampIsGreaterThanEndOfLifeCycleToken() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) + 1 seconds); // 1 second after end of life cycle token
        assertEq(erc721TLCDrop.tokenStatus(1), "Inactive");
    }

    /// Start & End of Life Cycle Token ///

    function test_Get_StartOfLifeCycleToken_ForTokenMintedBeforeStartOfLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIsLessThanFromStartOfLifeCycle() public {
        _tokenMintedBeforeStartOfLifeCycle();

        vm.warp(START_OF_LIFE_CYCLE - 1 seconds); // 1 second before start of life cycle
        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), 0);
    }

    function test_Get_EndOfLifeCycleToken_ForTokenMintedBeforeStartOfLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIsLessThanFromStartOfLifeCycle() public {
        _tokenMintedBeforeStartOfLifeCycle();

        vm.warp(START_OF_LIFE_CYCLE - 1 seconds); // 1 second before start of life cycle
        assertEq(erc721TLCDrop.endOfLifeCycleToken(1), 0);
    }

    function test_Get_StartOfLifeCycleToken_ForTokenMintedBeforeStartOfLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIsAtStartOfLifeCycle() public {
        _tokenMintedBeforeStartOfLifeCycle();

        vm.warp(START_OF_LIFE_CYCLE); // At start of life cycle
        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), erc721TLCDrop.startOfLifeCycle(TIER));
    }

    function test_Get_EndOfLifeCycleToken_ForTokenMintedBeforeStartOfLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIsAtStartOfLifeCycle() public {
        _tokenMintedBeforeStartOfLifeCycle();

        vm.warp(START_OF_LIFE_CYCLE); // At start of life cycle
        assertEq(
            erc721TLCDrop.endOfLifeCycleToken(1),
            erc721TLCDrop.startOfLifeCycle(TIER) + erc721TLCDrop.lifeCycleToken(1)
        );
    }

    function test_Get_StartOfLifeCycleToken_ForTokenMintedAfterStartOfLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIsGreaterThanStartOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), erc721TLCDrop.tokenTimestamp(1));
    }

    function test_Get_EndOfLifeCycleToken_ForTokenMintedAfterStartOfLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIsGreaterThanStartOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        assertEq(
            erc721TLCDrop.endOfLifeCycleToken(1),
            erc721TLCDrop.tokenTimestamp(1) + erc721TLCDrop.lifeCycleToken(1)
        );
    }

    function test_Get_StartOfLifeCycleToken_ForTokenMintedBeforeStartOfLifeCycle_WhenLifeCycleStatusIsLive_AfterTokenLifeCycleIsUpdatedForTheFirstTime() public {
        _tokenMintedBeforeStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD + 1 seconds); // 1 second after end of life cycle period/end of life cycle token
        vm.prank(tokenOwner);
        vm.deal(tokenOwner, 1 ether);
        erc721TLCDrop.updateTokenLifeCycle{value: TOKEN_LIFECYCLE_UPDATE_FEE}(1);

        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), erc721TLCDrop.tokenTimestamp(1));
        assertEq(erc721TLCDrop.tokenTimestamp(1), END_OF_FIRST_LIFE_CYCLE_PERIOD + 1 seconds);
    }

    function test_Get_EndtOfLifeCycleToken_MintedBeforeStartOfLifeCycle_WhenLifeCycleStatusIsLive_AfterTokenLifeCycleIsUpdatedForTheFirstTime() public {
        _tokenMintedBeforeStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD + 1 seconds); // 1 second after end of life cycle period/end of life cycle token
        vm.prank(tokenOwner);
        vm.deal(tokenOwner, 1 ether);
        erc721TLCDrop.updateTokenLifeCycle{value: TOKEN_LIFECYCLE_UPDATE_FEE}(1);

        assertEq(
            erc721TLCDrop.endOfLifeCycleToken(1),
            erc721TLCDrop.tokenTimestamp(1) + erc721TLCDrop.lifeCycleToken(1)
        );
    }

    /// Update Token Fee ///

    function test_Get_UpdateTokenFee_WhenLifeCycleStatusIsLive() public {
        _tokenMintedAfterStartOfLifeCycle();
        assertEq(erc721TLCDrop.updateTokenFee(1), erc721TLCDrop.updateFee(TIER));
    }

    /// Update Token Life Cycle ///

    function test_RevertIf_UpdateTokenLifeCycle_WhenLifeCycleStatusIsLive_ByNonTokenOwner() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) + 1 seconds); // 1 second after end of life cycle token

        hoax(address(0xBAD), 1 ether);
        vm.expectRevert(InvalidOwner.selector);
        erc721TLCDrop.updateTokenLifeCycle{value: TOKEN_LIFECYCLE_UPDATE_FEE}(1);
    }

    function testFail_UpdateTokenLifeCycle_WhenLifeCycleStatusIsLive_AndStatusIsPaused() public {
        _tokenMintedAfterStartOfLifeCycle();
        erc721TLCDrop.setPausedStatus();

        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) + 1 seconds); // 1 second after end of life cycle token

        vm.prank(tokenOwner);
        vm.expectRevert(Paused.selector);
        erc721TLCDrop.updateTokenLifeCycle{value: TOKEN_LIFECYCLE_UPDATE_FEE}(1);
    }

    function test_UpdateTokenLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIsGreaterThanEndOfLifeCycleToken() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) + 1 seconds); // 1 second after end of life cycle token

        // Before
        assertEq(erc721TLCDrop.tokenStatus(1), "Inactive");

        vm.startPrank(tokenOwner);
        vm.deal(tokenOwner, 1 ether);
        vm.expectEmit();
        emit TokenLifeCycleUpdate(
            1,
            TIER,
            erc721TLCDrop.endOfLifeCycleToken(1) + 1 seconds,
            erc721TLCDrop.lifeCycle(TIER)
        );
        emit MetadataUpdate(1);
        erc721TLCDrop.updateTokenLifeCycle{value: TOKEN_LIFECYCLE_UPDATE_FEE}(1);
        vm.stopPrank();

        // After
        assertEq(erc721TLCDrop.tokenStatus(1), "Active");
    }

    function test_UpdateTokenLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIsTwoHoursBeforeEndOfLifeCycleToken() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) - 2 hours); // 2 hours before end of life cycle token

        // Before
        assertEq(erc721TLCDrop.tokenStatus(1), "Active");

        vm.startPrank(tokenOwner);
        vm.deal(tokenOwner, 1 ether); 
        emit TokenLifeCycleUpdate(
            1,
            TIER,
            erc721TLCDrop.endOfLifeCycleToken(1) - 2 hours,
            erc721TLCDrop.lifeCycle(TIER)
        );
        emit MetadataUpdate(1);
        erc721TLCDrop.updateTokenLifeCycle{value: TOKEN_LIFECYCLE_UPDATE_FEE}(1);
        vm.stopPrank();

        // After
        assertEq(erc721TLCDrop.tokenStatus(1), "Active");
    }

    function test_RevertIf_UpdateTokenLifeCycle_WhenLifeCycleStatusIsLive_AndBlockTimestampIsGreaterThanTwoHoursBeforeEndOfLifeCycleToken() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) - 2 hours - 1 seconds); // 1 second before 2 hours before end of life cycle token

        vm.prank(tokenOwner);
        vm.deal(tokenOwner, 1 ether); 
        vm.expectRevert(InvalidTimeToUpdate.selector);
        erc721TLCDrop.updateTokenLifeCycle{value: TOKEN_LIFECYCLE_UPDATE_FEE}(1);
    }

    function testFail_UpdateTokenLifeCycle_WhenLifeCycleStatusIsLive_IfEtherBalanceIsLessThanFromUpdateFee() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) + 1 seconds); // 1 second after end of life cycle token

        vm.prank(tokenOwner);
        vm.deal(tokenOwner, 0.041 ether); // Less than 0.042 ether
        vm.expectRevert(InsufficientBalance.selector);
        erc721TLCDrop.updateTokenLifeCycle{value: TOKEN_LIFECYCLE_UPDATE_FEE}(1);
    }
}