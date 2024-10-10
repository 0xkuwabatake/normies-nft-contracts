// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../TestLifeCycleConfig.sol";

contract ERC721TLCDropLifeCycleWhenFinishedTest is TestLifeCycleConfig {
    
    /// Life Cycle ///

    function test_RevertIf_SetLifeCycle_WhenLifeCycleStatusIsFinished() public {
        _lifeCycleStatusIsFinished();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setLifeCycle(TIER, 60);
    }

    /// Update Fee ///

    function test_RevertIf_SetUpdateFee_WhenLifeCycleStatusIsFinished() public {
        _lifeCycleStatusIsFinished();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setUpdateFee(TIER, 0.069 ether);
    }

    /// Start of Life Cycle ///

    function test_RevertIf_SetStartOfLifeCycle_WhenLifeCycleStatusIsFinished() public {
        _lifeCycleStatusIsFinished();

        vm.prank(owner);
        vm.expectRevert(UndefinedFee.selector);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);
    }

    /// Set Life Cycle to Live ///

    function test_RevertIf_SetLifeCycleToLive_WhenLifeCycleStatusIsFinished() public {
        _lifeCycleStatusIsFinished();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setLifeCycleToLive(TIER);
    }

    /// Pause of Life Cycle ///

    function test_RevertIf_PauseLifeCycle_WhenLifeCycleStatusIsFinished() public {
        _lifeCycleStatusIsFinished();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.pauseLifeCycle(TIER, 1729555100); 
    }

    /// Unpause Life Cycle ///

    function test_RevertIf_UnpauseLifeCycle_WhenLifeCycleStatusIsFinished() public {
        _lifeCycleStatusIsFinished();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.unpauseLifeCycle(TIER);
    }

    /// End of Life Cycle ///

    function test_RevertIf_SetEndOfLifeCycle_WhenLifeCycleStatusIsFinished() public {
        _lifeCycleStatusIsFinished();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);
    }

    /// Finish Life Cycle ///
    
    function test_RevertIf_FinishLifeCycle_WhenLifeCycleStatusIsFinished() public {
        _lifeCycleStatusIsFinished();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.finishLifeCycle(TIER);
    }

    /// Mint when life cycle status is Finished ///

    function test_Mint_WhenLifeCycleStatusIsFinished_AfterPauseOfLifeCycle() public {
        _lifeCycleStatusIsPaused();

        vm.warp(PAUSE_OF_LIFE_CYCLE + 1 seconds); // 1 second after life cycle is finished
        erc721TLCDrop.finishLifeCycle(TIER);

        vm.warp(PAUSE_OF_LIFE_CYCLE + 2 seconds); // 2 seconds after life cycle is finished
        erc721TLCDrop.setMintStatus(TIER);

        vm.warp(PAUSE_OF_LIFE_CYCLE + 3 seconds); // 3 seconds after life cycle is finished
        vm.prank(address(0xB0B));
        vm.expectEmit();
        emit Transfer(address(0), address(0xB0B), 1);
        emit TierSet(1, TIER, PAUSE_OF_LIFE_CYCLE + 3 seconds);
        erc721TLCDrop.publicMint(TIER);
    }

    function test_Mint_WhenLifeCycleStatusIsFinished_AfterEndOfLifeCycle() public {
        _lifeCycleStatusIsEnding();

        vm.warp(END_OF_LIFE_CYCLE + 1 seconds); // 1 second after life cycle is finished
        erc721TLCDrop.finishLifeCycle(TIER);

        vm.warp(END_OF_LIFE_CYCLE + 2 seconds); // 2 seconds after life cycle is finished
        erc721TLCDrop.setMintStatus(TIER);

        vm.warp(END_OF_LIFE_CYCLE + 3 seconds); // 3 seconds after life cycle is finished
        vm.prank(address(0xB0B));
        vm.expectEmit();
        emit Transfer(address(0), address(0xB0B), 1);
        emit TierSet(1, TIER, END_OF_LIFE_CYCLE + 3 seconds);
        erc721TLCDrop.publicMint(TIER);
    }

    /// Token Status ///

    function test_Get_TokenStatus_WhenLifeCycleStatusIsFinished_AndBlockTimestampIsGreaterThanEndOfLifeCycle() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE + 1 seconds); // 1 second after life cycle is finished
        erc721TLCDrop.finishLifeCycle(TIER);

        assertEq(erc721TLCDrop.tokenStatus(1), "Active"); // Default is "Active"
    }

    /// Start & End of Life Cycle Token ///

    function test_Get_StartOfLifeCycleToken_WhenLifeCycleStatusIsFinished() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE + 1 seconds); // 1 second after life cycle is finished
        erc721TLCDrop.finishLifeCycle(TIER);

        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), 0);
    }

    function test_Get_EndOfLifeCycleToken_WhenLifeCycleStatusIsFinished() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE + 1 seconds); // 1 second after life cycle is finished
        erc721TLCDrop.finishLifeCycle(TIER);

        assertEq(erc721TLCDrop.endOfLifeCycleToken(1), 0);
    }

    /// Update Token Fee ///

    function test_Get_UpdateTokenFee_WhenLifeCycleStatusIsFinished() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE + 1 seconds); // 1 second after life cycle is finished
        erc721TLCDrop.finishLifeCycle(TIER);

        assertEq(erc721TLCDrop.updateTokenFee(1), 0);
    }

    /// Update Token Life Cycle ///

    function test_RevertIf_UpdateTokenLifeCycle_WhenLifeCycleIsFinished() public {
        _tokenMintedAfterStartOfLifeCycle();

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD - 2 days); // 48 hours before end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE + 1 seconds); // 1 second after life cycle is finished
        erc721TLCDrop.finishLifeCycle(TIER);

        vm.prank(tokenOwner);
        vm.deal(tokenOwner, 1 ether);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.updateTokenLifeCycle{value: TOKEN_LIFECYCLE_UPDATE_FEE}(1);
    }
}