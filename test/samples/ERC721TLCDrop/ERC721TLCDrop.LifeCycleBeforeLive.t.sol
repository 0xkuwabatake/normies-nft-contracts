// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../TestLifeCycleConfig.sol";

contract ERC721TLCDropLifeCycleBeforeLiveTest is TestLifeCycleConfig {
    
    ////// Life Cycle //////

    function test_RevertIf_SetLifeCycle_WhenLifeCycleStatusIsNotLive_IfTierIdIsZero() public {
        vm.prank(owner);
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.setLifeCycle(0, LIFE_CYCLE); // Tier #0
    }

    function test_RevertIf_SetLifeCycle_WhenLifeCycleStatusIsNotLive_IfTierIdIsEleven() public {
        vm.prank(owner);
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.setLifeCycle(11, LIFE_CYCLE); // Tier #11
    }

    function test_RevertIf_SetLifeCycle_WhenLifeCycleStatusIsNotLive_ByNonOwnerOrAdmin() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(Unauthorized.selector);
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
    }

    function test_RevertIf_SetLifeCycle_WhenLifeCycleStatusIsNotLive_IfNumberOfDaysIsLessThanFrom30Days() public {
        vm.prank(owner);
        vm.expectRevert(InvalidNumberOfDays.selector);
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE - 1); // 29 days
    }

    function test_SetLifeCycle_WhenLifeCycleStatusIsNotLive_IfNumberOfDaysIsMinimum30Days() public {
        // Before
        ERC721TLCDrop.LifeCycleStatus statusBefore = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusBefore), uint8(LifeCycleStatus.NotLive));
        assertEq(erc721TLCDrop.lifeCycle(TIER), 0);
        
        vm.prank(owner);
        vm.expectEmit();
        emit LifeCycleUpdate(TIER, LIFE_CYCLE * 86400);
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);

        // After
        ERC721TLCDrop.LifeCycleStatus statusAfter = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusAfter), uint8(LifeCycleStatus.ReadyToStart));
        assertEq(erc721TLCDrop.lifeCycle(TIER), LIFE_CYCLE * 86400);
    }

    function test_RevertIf_SetLifeCycle_WhenLifeCycleStatusIsReadyToStart() public {
        _lifeCycleStatusIsReadyToStart();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setLifeCycle(TIER, 60);
    }

    function test_RevertIf_SetLifeCycle_WhenLifeCycleStatusIsReadyToLive() public {
        _lifeCycleStatusIsReadyToLive();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setLifeCycle(TIER, 60);
    }

    ///////// Update Fee /////////

    function test_RevertIf_SetUpdateFee_WhenLifeCycleStatusIsNotLive() public {
        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setUpdateFee(TIER, 0.069 ether);
    }

    function test_RevertIf_SetUpdateFee_WhenLifeCycleStatusIsReadyToStart_ByNonOwnerOrAdmin() public {
        _lifeCycleStatusIsReadyToStart();

        vm.prank(address(0xBAD));
        vm.expectRevert(Unauthorized.selector);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
    }

    function test_RevertIf_SetUpdateFee_WhenLifeCycleStatusIsReadyToStart_IfFeeIsZero() public {
        _lifeCycleStatusIsReadyToStart();

        vm.prank(owner);
        vm.expectRevert(InvalidFee.selector);
        erc721TLCDrop.setUpdateFee(TIER, 0);
    }

    function test_SetUpdateFee_WhenLifeCycleStatusIsReadyToStart_IfFeeIsNonZero() public {
        _lifeCycleStatusIsReadyToStart();

        vm.prank(owner);
        vm.expectEmit();
        emit TokenLifeCycleFeeUpdate(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
    }

    function test_SetUpdateFee_WhenLifeCycleStatusIsReadyToStart_IfFeeIsEqualToMaxUint64Value() public {
        _lifeCycleStatusIsReadyToStart();

        vm.prank(owner);
        vm.expectEmit();
        emit TokenLifeCycleFeeUpdate(TIER, 18446744073709551615);
        erc721TLCDrop.setUpdateFee(TIER, 18446744073709551615);
    }

    function test_RevertIf_SetUpdateFee_WhenLifeCycleStatusIsReadyToStart_IfFeeIsGreaterThanMaxUint64Value() public {
        _lifeCycleStatusIsReadyToStart();

        vm.prank(owner);
        vm.expectRevert(InvalidFee.selector);
        erc721TLCDrop.setUpdateFee(TIER, 18446744073709551615 + 1); // 18.446744073709551616 ether
    }

    function test_RevertIf_SetUpdateFee_WhenLifeCycleStatusIsReadyToLive() public {
        _lifeCycleStatusIsReadyToLive();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setUpdateFee(TIER, 0.069 ether);
    }

    ////// Start of Life Cycle //////

    function test_RevertIf_SetStartOfLifeCycle_WhenLifeCycleStatusIsNotLive() public {
        vm.prank(owner);
        vm.expectRevert(UndefinedFee.selector);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);
    }

    function test_RevertIf_SetStartOfLifeCycle_WhenLifeCycleStatusIsReadyToStart_ByNonOwnerOrAdmin() public {
        _lifeCycleStatusIsReadyToStart();

        vm.prank(address(0xBAD));
        vm.expectRevert(Unauthorized.selector);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);
    }

    function test_RevertIf_SetStartOfLifeCycle_WhenLifeCycleStatusIsReadyToStart_IfUpdateFeeIsUndefined() public {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);

        vm.prank(owner);
        vm.expectRevert(UndefinedFee.selector);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);
    }

    function test_RevertIf_SetStartOfLifeCycle_WhenLifeCycleStatusIsReadyToStart_IfTimestampIsEqualToBlockTimestamp() public {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);

        vm.warp(START_OF_LIFE_CYCLE); // block.timestamp

        vm.prank(owner);
        vm.expectRevert(InvalidTimestamp.selector);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE); // Timestamp is equal to block.timestamp
    }

    function test_RevertIf_SetStartOfLifeCycle_WhenLifeCycleStatusIsReadyToStart_IfTimestampIsLessThanBlockTimestamp() public {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);

        vm.warp(START_OF_LIFE_CYCLE);

        vm.prank(owner);
        vm.expectRevert(InvalidTimestamp.selector);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE - 1 seconds); // 1 second before block.timestamp
    }

    function test_SetStartOfLifeCycle_WhenLifeCycleStatusIsReadyToStart_IfTimestampisGreaterThanBlockTimestamp() public {
        // Before
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);

        ERC721TLCDrop.LifeCycleStatus statusBefore = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusBefore), uint8(LifeCycleStatus.ReadyToStart));
        assertEq(erc721TLCDrop.startOfLifeCycle(TIER), 0);

        vm.warp(START_OF_LIFE_CYCLE - 1 seconds); // 1 second before start of life cycle

        vm.prank(owner);
        vm.expectEmit();
        emit StartOfLifeCycleUpdate(TIER, START_OF_LIFE_CYCLE);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE); // 1 second after block.timestamp

        // After
        ERC721TLCDrop.LifeCycleStatus statusAfter = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusAfter), uint8(LifeCycleStatus.ReadyToLive));
        assertEq(erc721TLCDrop.startOfLifeCycle(TIER), START_OF_LIFE_CYCLE);
    }

    function test_SetStartOfLifeCycle_WhenLifeCycleStatusIsReadyToStart_IfTimestampIsEqualToMaxUint40Value() public {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);

        vm.prank(owner);
        vm.expectEmit();
        emit StartOfLifeCycleUpdate(TIER,  1099511627775);
        erc721TLCDrop.setStartOfLifeCycle(TIER, 1099511627775); // Max value of uint40
    }

    function test_RevertIf_SetStartOfLifeCycle_WhenLifeCycleStatusIsReadyToStart_IfTimestampIsGreaterThanMaxUint40Value() public {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);

        vm.prank(owner);
        vm.expectRevert(InvalidTimestamp.selector);
        erc721TLCDrop.setStartOfLifeCycle(TIER, 1099511627775 + 1); // Max value of uint40 plus 1
    }

    function test_SetStartOfLifeCycle_WhenLifeCycleStatusIsReadyToLive() public {
        _lifeCycleStatusIsReadyToLive();

        // Before
        ERC721TLCDrop.LifeCycleStatus statusBefore = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusBefore), uint8(LifeCycleStatus.ReadyToLive));

        vm.warp(START_OF_LIFE_CYCLE + 1 seconds); // 1 second after start of life cycle

        vm.startPrank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.setLifeCycleToLive(TIER); 

        vm.expectEmit();
        emit StartOfLifeCycleUpdate(TIER, START_OF_LIFE_CYCLE + 2 seconds);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE + 2 seconds); // Re-defined start of life cycle
        vm.stopPrank();

        // After
        ERC721TLCDrop.LifeCycleStatus statusAfter = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusAfter), uint8(LifeCycleStatus.ReadyToLive));
    }

    /// Set Life Cycle to Live ///

    function test_RevertIf_SetLifeCycleToLive_WhenLifeCycleStatusIsNotLive() public {
        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setLifeCycleToLive(TIER);
    }

    function test_RevertIf_SetLifeCycleToLive_WhenLifeCycleStatusIsReadyToStart() public {
        _lifeCycleStatusIsReadyToStart();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setLifeCycleToLive(TIER);
    }

    function test_RevertIf_SetLifeCycleToLive_WhenLifeCycleStatusIsReadyToLive_ByNonOwnerOrAdmin() public {
        _lifeCycleStatusIsReadyToLive();

        vm.prank(address(0xBAD));
        vm.expectRevert(Unauthorized.selector);
        erc721TLCDrop.setLifeCycleToLive(TIER);
    }

    function test_RevertIf_SetLifeCycleToLive_WhenLifeCycleStatusIsReadyToLive_AndBlockTimestampIsGreaterThanStartOfLifeCycle() public {
        _lifeCycleStatusIsReadyToLive();

        vm.warp(START_OF_LIFE_CYCLE + 1 seconds); // 1 second after start of life cycle

        vm.prank(owner);
        vm.expectRevert(InvalidTimeToInitialize.selector);
        erc721TLCDrop.setLifeCycleToLive(TIER);
    }

    function test_SetLifeCycleToLive_WhenLifeCycleStatusIsReadyToLive_AndBlockTimestampIsLessThanStartOfLifeCycle() public {
        _lifeCycleStatusIsReadyToLive();

        // Before
        ERC721TLCDrop.LifeCycleStatus statusBefore = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusBefore), uint8(LifeCycleStatus.ReadyToLive));

        vm.warp(START_OF_LIFE_CYCLE - 1 seconds); // 1 second before start of life cycle
        vm.prank(owner);
        vm.expectEmit();
        emit LifeCycleIsLive(TIER, START_OF_LIFE_CYCLE - 1 seconds);
        erc721TLCDrop.setLifeCycleToLive(TIER);

        // After
        ERC721TLCDrop.LifeCycleStatus statusAfter = erc721TLCDrop.lifeCycleStatus(TIER);
        assertEq(uint8(statusAfter), uint8(LifeCycleStatus.Live));
    }

    function test_SetLifeCycleToLive_WhenLifeCycleStatusIsReadyToLive_AndTotalSupplyIsNotZero() public {
        _twoTokensMintedBeforeStartOfLifeCycle();

        vm.warp(START_OF_LIFE_CYCLE - 1 seconds); // 1 second before start of life cycle
        vm.prank(owner);
        vm.expectEmit();
        emit LifeCycleIsLive(TIER, START_OF_LIFE_CYCLE - 1 seconds);
        emit BatchMetadataUpdate(1, erc721TLCDrop.totalSupply());
        erc721TLCDrop.setLifeCycleToLive(TIER);
    }

    /// Pause Life Cycle ///

    function test_RevertIf_PauseLifeCycle_WhenLifeCycleStatusIsNotLive() public {
        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);
    }

    function test_RevertIf_PauseLifeCycle_WhenLifeCycleStatusIsReadyToStart() public {
        _lifeCycleStatusIsReadyToStart();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);
    }

    function test_RevertIf_PauseLifeCycle_WhenLifeCycleStatusIsReadyToLive() public {
        _lifeCycleStatusIsReadyToLive();
        
        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);
    }

    /// End of Life Cycle ///

    function test_RevertIf_SetEndOfLifeCycle_WhenLifeCycleStatusIsNotLive() public {
        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);
    }

    function test_RevertIf_SetEndOfLifeCycle_WhenLifeCycleStatusIsReadyToStart() public {
        _lifeCycleStatusIsReadyToStart();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);
    }

    function test_RevertIf_SetEndOfLifeCycle_WhenLifeCycleStatusIsReadyToLive() public {
        _lifeCycleStatusIsReadyToLive();
        
        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);
    }

    /// Finish Life Cycle ///

    function test_RevertIf_FinishLifeCycle_WhenLifeCycleStatusIsNotLive() public {
        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.finishLifeCycle(TIER);
    }

    function test_RevertIf_FinishLifeCycle_WhenLifeCycleStatusIsReadyToStart() public {
        _lifeCycleStatusIsReadyToStart();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.finishLifeCycle(TIER);
    }

    function test_RevertIf_FinishLifeCycle_WhenLifeCycleStatusIsReadyToLive() public {
        _lifeCycleStatusIsReadyToLive();

        vm.prank(owner);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.finishLifeCycle(TIER);
    }

    /// Token Status ///

    function test_Get_TokenStatus_WhenLifeCycleStatusIsNotLive() public {
        vm.expectRevert(TokenDoesNotExist.selector);
        erc721TLCDrop.tokenStatus(1); // Non-existent token ID
    }

    function test_Get_TokenStatus_WhenLifeCycleStatusIsReadyToStart() public {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setMintStatus(TIER);

        vm.prank(tokenOwner);
        erc721TLCDrop.publicMint(TIER);

        assertEq(erc721TLCDrop.tokenStatus(1), "Active"); // Default is "Active"
    }

    function test_Get_TokenStatus_WhenLifeCycleStatusIsReadyToLive() public {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setMintStatus(TIER);

        vm.warp(START_OF_LIFE_CYCLE - 1 days); // 1 day before start of life cycle
        vm.prank(tokenOwner);
        erc721TLCDrop.publicMint(TIER);

        vm.warp(START_OF_LIFE_CYCLE - 1 days + 1 seconds); // 1 second after 1 day before start of life cycle
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);

        assertEq(erc721TLCDrop.tokenStatus(1), "Active");
    }

    /// Start & End of Life Cycle Token ///

    function test_Get_StartOfLifeCycleToken_WhenLifeCycleStatusIsNotLive() public view {
        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), 0); // Non-existent token ID
    }

    function test_Get_EndOfLifeCycleToken_WhenLifeCycleStatusIsNotLive() public view {
        assertEq(erc721TLCDrop.endOfLifeCycleToken(1), 0); // Non-existent token ID
    }

    function test_Get_StartOfLifeCycleToken_WhenLifeCycleStatusIsReadyToStart() public {
        _lifeCycleStatusIsReadyToStart();
        erc721TLCDrop.setMintStatus(TIER);
        vm.prank(tokenOwner);
        erc721TLCDrop.publicMint(TIER);

        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), 0);
    }

    function test_Get_EndOfLifeCycleToken_WhenLifeCycleStatusIsReadyToStart() public {
        _lifeCycleStatusIsReadyToStart();
        erc721TLCDrop.setMintStatus(TIER);
        vm.prank(tokenOwner);
        erc721TLCDrop.publicMint(TIER);

        assertEq(erc721TLCDrop.endOfLifeCycleToken(1), 0);
    }

    function test_Get_StartOfLifeCycleToken_WhenLifeCycleStatusIsReadyToLive() public {
        _lifeCycleStatusIsReadyToLive();
        erc721TLCDrop.setMintStatus(TIER);
        vm.prank(tokenOwner);
        erc721TLCDrop.publicMint(TIER);

        assertEq(erc721TLCDrop.startOfLifeCycleToken(1), 0);
    }

    function test_Get_EndOfLifeCycleToken_WhenLifeCycleStatusIsReadyToLive() public {
        _lifeCycleStatusIsReadyToLive();
        erc721TLCDrop.setMintStatus(TIER);
        vm.prank(tokenOwner);
        erc721TLCDrop.publicMint(TIER);

        assertEq(erc721TLCDrop.endOfLifeCycleToken(1), 0);
    }

    /// Update Token Fee ///

    function test_Get_UpdateTokenFee_WhenLifeCycleStatusIsNotLive() public view {
        assertEq(erc721TLCDrop.updateTokenFee(1), 0); // Non-existent token ID
    }

    function test_Get_UpdateTokenFee_WhenLifeCycleStatusIsReadyToStart() public {
        _lifeCycleStatusIsReadyToStart();
        erc721TLCDrop.setMintStatus(TIER);
        vm.prank(tokenOwner);
        erc721TLCDrop.publicMint(TIER);

        assertEq(erc721TLCDrop.updateTokenFee(1), 0);
    }

    function test_Get_UpdateTokenFee_WhenLifeCycleStatusIsReadyToLive() public {
        _lifeCycleStatusIsReadyToLive();
        erc721TLCDrop.setMintStatus(TIER);
        vm.prank(tokenOwner);
        erc721TLCDrop.publicMint(TIER);

        assertEq(erc721TLCDrop.updateTokenFee(1), 0);
    }

    /// Update Token Life Cycle ///

    function test_RevertIf_UpdateTokenLifeCycle_WhenLifeCycleStatusIsNotLive() public {
        vm.prank(tokenOwner);
        vm.deal(tokenOwner, 1 ether);
        vm.expectRevert(TokenDoesNotExist.selector); // Non-existent token ID
        erc721TLCDrop.updateTokenLifeCycle{value: TOKEN_LIFECYCLE_UPDATE_FEE}(1);
    }

    function test_RevertIf_UpdateTokenLifeCycle_WhenLifeCycleStatusIsReadyToStart() public {
        _lifeCycleStatusIsReadyToStart();
        erc721TLCDrop.setMintStatus(TIER);
        vm.prank(tokenOwner);
        erc721TLCDrop.publicMint(TIER);

        vm.prank(tokenOwner);
        vm.deal(tokenOwner, 1 ether);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.updateTokenLifeCycle{value: TOKEN_LIFECYCLE_UPDATE_FEE}(1);
    }

    function test_RevertIf_UpdateTokenLifeCycle_WhenLifeCycleStatusIsReadyToLive() public {
        _lifeCycleStatusIsReadyToLive();
        erc721TLCDrop.setMintStatus(TIER);
        vm.prank(tokenOwner);
        erc721TLCDrop.publicMint(TIER);

        vm.prank(tokenOwner);
        vm.deal(tokenOwner, 1 ether);
        vm.expectRevert(InvalidLifeCycleStatus.selector);
        erc721TLCDrop.updateTokenLifeCycle{value: TOKEN_LIFECYCLE_UPDATE_FEE}(1);
    }
}