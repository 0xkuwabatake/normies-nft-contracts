// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../TestLifeCycleConfig.sol";

contract ERC721TLCDropLifeCycleWhenEndingTest is TestLifeCycleConfig {
    
    /// Life Cycle ///

    function test_RevertIf_SetLifeCycle_WhenLifeCycleStatusIsEnding() public {
        _lifeCycleStatusIsEnding();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setLifeCycle(TIER, 60);
    }

    /// Update Fee ///

    function test_RevertIf_SetUpdateFee_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsLessThanFromEndOfLifeCycle() public {
        _lifeCycleStatusIsEnding();

        vm.warp(END_OF_LIFE_CYCLE - 1 seconds); // 1 second before end of life cycle
        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.setUpdateFee(TIER,  0.069 ether);
    }

    function test_RevertIf_SetUpdateFee_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsAtEndOfLifeCycle() public {
        _lifeCycleStatusIsEnding();

        vm.warp(END_OF_LIFE_CYCLE); // At the end of life cycle
        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.setUpdateFee(TIER,  0.069 ether);
    }

    function test_SetUpdateFee_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsGreaterThanEndOfLifeCycle() public {
        _lifeCycleStatusIsEnding();

        vm.warp(END_OF_LIFE_CYCLE + 1 seconds); // 1 second after end of life cycle

        vm.prank(owner);
        vm.expectEmit();
        emit TokenLifeCycleFeeUpdate(TIER, 0.069 ether);
        erc721TLCDrop.setUpdateFee(TIER, 0.069 ether);
    }

    /// Start of Life Cycle ///

    function test_RevertIf_SetStartOfLifeCycle_WhenLifeCycleStatusIsEnding() public {
        _lifeCycleStatusIsEnding();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);
    }

    /// Set Life Cycle to Live ///

    function test_RevertIf_SetLifeCycleToLive_WhenLifeCycleStatusIsEnding() public {
        _lifeCycleStatusIsEnding();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setLifeCycleToLive(TIER);
    }

    /// Pause of Life Cycle ///

    function test_RevertIf_SetPauseOfLifeCycle_WhenLifeCycleStatusIsEnding() public {
        _lifeCycleStatusIsEnding();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.pauseLifeCycle(TIER, 1729555100); 
    }

    /// Unpause Life Cycle ///

    function test_RevertIf_UnpauseLifeCycle_WhenLifeCycleStatusIsEnding() public {
        _lifeCycleStatusIsEnding();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.unpauseLifeCycle(TIER);
    }

    /// End of Life Cycle ///
    
    function test_RevertIf_SetEndOfLifeCycle_WhenLifeCycleStatusIsEnding() public {
        _lifeCycleStatusIsEnding();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);
    }

    /// Finish Life Cycle ///

    function test_RevertIf_FinishLifeCycle_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsLessThanFromEndOfLifeCycle() public {
        _lifeCycleStatusIsEnding();

        vm.warp(END_OF_LIFE_CYCLE - 1 seconds); // 1 second before end of life cycle
        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.finishLifeCycle(TIER);
    }

    function test_RevertIf_FinishLifeCycle_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsAtEndOfLifeCycle() public {
        _lifeCycleStatusIsEnding();

        vm.warp(END_OF_LIFE_CYCLE); // At end of life cycle
        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.finishLifeCycle(TIER);
    }

    function test_FinishLifeCycle_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsGreaterThanEndOfLifeCycle() public {
        _lifeCycleStatusIsEnding();

        // Before
        ERC721TLCDrop.LifeCycleStatus statusBefore = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusBefore), uint8(LifeCycleStatus.Ending));
        assertEq(erc721TLCDrop.lifeCycle(TIER), LIFE_CYCLE * 86400);
        assertEq(erc721TLCDrop.startOfLifeCycle(TIER), START_OF_LIFE_CYCLE);
        assertEq(erc721TLCDrop.updateFee(TIER), TOKEN_LIFECYCLE_UPDATE_FEE);
        assertEq(erc721TLCDrop.endOfLifeCycle(TIER), END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE + 1 seconds); // 1 second after end of life cycle

        vm.prank(owner);
        vm.expectEmit();
        emit LifeCycleIsFinished(TIER, END_OF_LIFE_CYCLE + 1 seconds);
        erc721TLCDrop.finishLifeCycle(TIER);

        // After
        ERC721TLCDrop.LifeCycleStatus statusAfter = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusAfter), uint8(LifeCycleStatus.Finished));
        assertEq(erc721TLCDrop.lifeCycle(TIER), LIFE_CYCLE * 86400);
        assertEq(erc721TLCDrop.startOfLifeCycle(TIER), 0);
        assertEq(erc721TLCDrop.updateFee(TIER), 0);
        assertEq(erc721TLCDrop.endOfLifeCycle(TIER), 0);
    }

    /// Token Status ///

    function test_Get_TokenStatus_WhenLifeCycleStatusIsEnding_AndBlockTimestampIs48HourseBeforeEndOfFirstLifeCyclePeriod() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        assertEq(erc721TLCDrop.tokenStatus(1), "Active");
    }

    function test_Get_TokenStatus_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsGreaterThanEndOfLifeCycleToken() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) + 1 seconds); // 1 second after end of life cycle token
        assertEq(erc721TLCDrop.tokenStatus(1), "Inactive");
    }

    /// Start & End of Life Cycle Token ///

    function test_Get_StartOfLifeCycleToken_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsLessThanFromEndOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE - 1 seconds); // 1 second before pause of life cycle
        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), erc721TLCDrop.tokenTimestamp(1));
    }

    function test_Get_EndOfLifeCycleToken_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsLessThanFromEndOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE - 1 seconds); // 1 second before pause of life cycle
        assertEq(
            erc721TLCDrop.endOfLifeCycleToken(1),
            erc721TLCDrop.tokenTimestamp(1) + erc721TLCDrop.lifeCycleToken(1)
        );
    }

    function test_Get_StartOfLifeCycleToken_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsAtEndOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE); // At pause of life cycle
        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), erc721TLCDrop.tokenTimestamp(1));
    }

    function test_Get_EndOfLifeCycleToken_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsAtEndOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE); // At pause of life cycle
        assertEq(
            erc721TLCDrop.endOfLifeCycleToken(1),
            erc721TLCDrop.tokenTimestamp(1) + erc721TLCDrop.lifeCycleToken(1)
        );
    }

    function test_Get_StartOfLifeCycleToken_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsGreaterThanEndOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE + 1 seconds); // 1 second after pause of life cycle
        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), 0);
    }

    function test_Get_EndOfLifeCycleToken_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsGreaterThanEndOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();
        
        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE + 1 seconds); // 1 second after pause of life cycle
        assertEq(erc721TLCDrop.endOfLifeCycleToken(1), 0);
    }

    /// Update Token Fee ///

    function test_Get_UpdateTokenFee_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsLessThanFromEndOfLifeCycle_AndRemainderIsGreaterThanFromLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE_2);

        assertEq(erc721TLCDrop.updateTokenFee(1), TOKEN_LIFECYCLE_UPDATE_FEE);
    }

    function test_Get_UpdateTokenFee_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsLessThanEndOfLifeCycle_AndRemainderIsLessThanFromLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        uint256 remainder = END_OF_LIFE_CYCLE - END_OF_FIRST_LIFE_CYCLE_PERIOD;
        uint256 proportionalUpdateTokenFee = remainder * erc721TLCDrop.updateFee(TIER) / erc721TLCDrop.lifeCycle(TIER);
        assertEq(erc721TLCDrop.updateTokenFee(1), proportionalUpdateTokenFee);
    }

    function test_Get_UpdateTokenFee_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsAtEndOfLifeCycle_AndRemainderIsZero() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE); // At end of life cycle
        assertEq(erc721TLCDrop.updateTokenFee(1), 0);
    }

    function test_Get_UpdateTokenFee_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsGreaterThanEndOfLifeCycle_AndRemainderIsZero() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE + 1 seconds); // 1 second after end of life cycle
        assertEq(erc721TLCDrop.updateTokenFee(1), 0);
    }

    /// Update Token Life Cycle ///

    function test_RevertIf_UpdateTokenLifeCycle_WhenLifeCycleStatusIsEnding_ByNonTokenOwner() public {
        _tokenMintedAfterStartOfLifeCycle();
        
        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) + 1 seconds); // 1 second after end of life cycle token
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        uint256 proportionalUpdateTokenFee = erc721TLCDrop.updateTokenFee(1);

        hoax(address(0xBAD), 1 ether);
        vm.expectRevert(InvalidOwner.selector);
        erc721TLCDrop.updateTokenLifeCycle{value: proportionalUpdateTokenFee}(1);
    }

    function test_UpdateTokenLifeCycle_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsGreaterThanEndOfLifeCycleToken() public {
        _tokenMintedAfterStartOfLifeCycle();
        
        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) + 1 seconds); // 1 second after end of life cycle token
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        // Before
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

        // After
        assertEq(erc721TLCDrop.tokenStatus(1), "Active");
    }

    function test_UpdateTokenLifeCycle_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsTwoHoursBeforeEndOfLifeCycleToken() public {
        _tokenMintedAfterStartOfLifeCycle();
        
        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) - 2 hours); // block.timestamp is 2 hours before end of life cycle token
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        // Before
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

        // After
        assertEq(erc721TLCDrop.tokenStatus(1), "Active");
    }

    function test_RevertIf_UpdateTokenLifeCycle_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsGreaterThanTwoHoursBeforeEndOfLifeCycleToken() public {
        _tokenMintedAfterStartOfLifeCycle();
        
        vm.warp(erc721TLCDrop.endOfLifeCycleToken(1) - 2 hours - 1 seconds); // 2 hours before end of life cycle token
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        uint256 proportionalUpdateTokenFee = erc721TLCDrop.updateTokenFee(1);

        vm.prank(tokenOwner);
        vm.deal(tokenOwner, 0.0212 ether);
        vm.expectRevert(InvalidTimeToUpdate.selector);
        erc721TLCDrop.updateTokenLifeCycle{value: proportionalUpdateTokenFee}(1);
    }

    function test_UpdateTokenLifeCycle_WhenLifeCycleStatusIsEnding_AndBlockTimestampIs60SecondsBeforeEndOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        uint256 endOfFirstLifeCyclePeriod = START_OF_LIFE_CYCLE + LIFE_CYCLE * 86400;
        vm.warp(endOfFirstLifeCyclePeriod - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE - 60 seconds); // 60 seconds before end of life cycle

        uint256 proportionalUpdateTokenFee = erc721TLCDrop.updateTokenFee(1);

        vm.startPrank(tokenOwner);
        vm.deal(tokenOwner, 0.00973 ether);
        vm.expectEmit();
        emit TokenLifeCycleUpdate(
            1,
            TIER,
            END_OF_LIFE_CYCLE - 60 seconds,
            erc721TLCDrop.lifeCycle(TIER)
        );
        emit MetadataUpdate(1);
        erc721TLCDrop.updateTokenLifeCycle{value: proportionalUpdateTokenFee}(1); // 972222222222 wei
        vm.stopPrank();
    }

    function test_UpdateTokenLifeCycle_WhenLifeCycleStatusIsEnding_AndBlockTimestampIsLessThanFrom60SecondsBeforeEndOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        uint256 endOfFirstLifeCyclePeriod = START_OF_LIFE_CYCLE + LIFE_CYCLE * 86400;
        vm.warp(endOfFirstLifeCyclePeriod - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE - 60 seconds + 1 seconds); // block.timestamp is 59 seconds before end of life cycle

        uint256 proportionalUpdateTokenFee = erc721TLCDrop.updateTokenFee(1);

        vm.prank(tokenOwner);
        vm.deal(tokenOwner, 0.00973 ether);
        vm.expectRevert(InvalidTimeToUpdate.selector);
        erc721TLCDrop.updateTokenLifeCycle{value: proportionalUpdateTokenFee}(1); 
    }
}