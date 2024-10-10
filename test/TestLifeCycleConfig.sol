// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/samples/ERC721TLCDrop.sol";

contract TestLifeCycleConfig is Test {
    ERC721TLCDrop erc721TLCDrop;

    enum LifeCycleStatus {
        NotLive,
        ReadyToStart,
        ReadyToLive,
        Live,
        Paused,
        Ending,
        Finished
    }
    
    uint256 constant TIER = 3;
    uint256 constant LIFE_CYCLE = 30; // 30 days
    uint256 constant TOKEN_LIFECYCLE_UPDATE_FEE = 0.042 ether;
    uint256 constant START_OF_LIFE_CYCLE = 1725667200; // Sat Sep 07 2024 00:00:00 GMT+0000
    uint256 constant END_OF_FIRST_LIFE_CYCLE_PERIOD = START_OF_LIFE_CYCLE + LIFE_CYCLE * 86400;
    uint256 constant PAUSE_OF_LIFE_CYCLE = 1729555200; // Tue Oct 22 2024 00:00:00 GMT+0000
    uint256 constant END_OF_LIFE_CYCLE = 1729555200; // Tue Oct 22 2024 00:00:00 GMT+0000
    uint256 constant PAUSE_OF_LIFE_CYCLE_2 = 1731024000; // Fri Nov 08 2024 00:00:00 GMT+0000
    uint256 constant END_OF_LIFE_CYCLE_2 = 1731024000; // Fri Nov 08 2024 00:00:00 GMT+0000

    address owner;
    address tokenOwner;

    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event TierSet(uint256 indexed tokenId, uint256 indexed tierId, uint256 indexed atTimeStamp);
    event LifeCycleUpdate(uint256 indexed tierId, uint256 indexed totalSeconds);
    event StartOfLifeCycleUpdate(uint256 indexed tierId, uint256 indexed timestamp);
    event LifeCycleIsLive(uint256 indexed tierId, uint256 indexed atTimestamp);
    event LifeCycleIsPaused(uint256 indexed tierId, uint256 indexed atTimestamp);
    event LifeCycleIsUnpaused(uint256 indexed tierId, uint256 indexed atTimestamp);
    event EndOfLifeCycleSet(uint256 indexed tierId, uint256 indexed timestamp);
    event LifeCycleIsFinished(uint256 indexed tierId, uint256 indexed atTimestamp);
    event TokenLifeCycleFeeUpdate(uint256 indexed tierId, uint256 indexed fee);
    event MetadataUpdate(uint256 tokenId);
    event BatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId);
    event TokenLifeCycleUpdate (
        uint256 indexed tokenId,
        uint256 indexed tierId,
        uint256 indexed currentTimeStamp,
        uint256 currentLifeCycle
    );
    
    error Paused();
    error InvalidFee();
    error InvalidOwner();
    error UndefinedFee();
    error Unauthorized();
    error InvalidTierId();
    error InvalidTimestamp();
    error TokenDoesNotExist();
    error UndefinedLifeCycle();
    error InvalidNumberOfDays();
    error InvalidTimeToUpdate();
    error InsufficientBalance();
    error InvalidLifeCycleStatus();
    error InvalidTimeToInitialize();
    
    function setUp() public virtual {
        erc721TLCDrop = new ERC721TLCDrop();
        owner = address(erc721TLCDrop.owner());
        tokenOwner = address(0xA11CE);
    }

    function _lifeCycleStatusIsReadyToStart() internal {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
    }

    function _lifeCycleStatusIsReadyToLive() internal {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);
    }

    function _lifeCycleStatusIsLive() internal {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);

        vm.warp(START_OF_LIFE_CYCLE - 1 days); // 1 day before start of life cycle
        erc721TLCDrop.setLifeCycleToLive(TIER);
    }

    function _lifeCycleStatusIsPaused() internal {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);

        vm.warp(START_OF_LIFE_CYCLE - 1 days); // 1 day before start of life cycle
        erc721TLCDrop.setLifeCycleToLive(TIER);

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        erc721TLCDrop.pauseLifeCycle(TIER, PAUSE_OF_LIFE_CYCLE);
    }

    function _lifeCycleStatusIsEnding() internal {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);

        vm.warp(START_OF_LIFE_CYCLE - 1 days); // 1 day before start of life cycle
        erc721TLCDrop.setLifeCycleToLive(TIER);

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);
    }

    function _lifeCycleStatusIsFinished() internal {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);

        vm.warp(START_OF_LIFE_CYCLE - 1 days); // 1 day before start of life cycle
        erc721TLCDrop.setLifeCycleToLive(TIER);

        vm.warp(END_OF_FIRST_LIFE_CYCLE_PERIOD); // At end of first life cycle period
        erc721TLCDrop.setEndOfLifeCycle(TIER, END_OF_LIFE_CYCLE);

        vm.warp(END_OF_LIFE_CYCLE + 1 seconds); // 1 second after life cycle is finished
        erc721TLCDrop.finishLifeCycle(TIER);
    }

    function _tokenMintedBeforeStartOfLifeCycle() internal {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setMintStatus(TIER);

        vm.warp(START_OF_LIFE_CYCLE - 1 days); // 1 day before start of life cycle
        vm.prank(tokenOwner);
        erc721TLCDrop.publicMint(TIER);

        vm.warp(START_OF_LIFE_CYCLE - 1 days + 1 seconds); // 1 second after 1 day before start of life cycle
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);
        erc721TLCDrop.setLifeCycleToLive(TIER);
    }

    function _tokenMintedAfterStartOfLifeCycle() internal {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);

        vm.warp(START_OF_LIFE_CYCLE - 1 days); // 1 day before start of life cycle
        erc721TLCDrop.setLifeCycleToLive(TIER);
        erc721TLCDrop.setMintStatus(TIER);

        vm.warp(START_OF_LIFE_CYCLE + 1 seconds); // 1 second after start of life cycle
        vm.prank(tokenOwner);
        erc721TLCDrop.publicMint(TIER);
    }

    function _twoTokensMintedBeforeStartOfLifeCycle() internal {
        erc721TLCDrop.setLifeCycle(TIER, LIFE_CYCLE);
        erc721TLCDrop.setMintStatus(TIER);

        vm.warp(START_OF_LIFE_CYCLE - 1 days); // 1 day before start of life cycle
        vm.prank(tokenOwner);
        erc721TLCDrop.publicMint(TIER); // Token Id #1
        vm.prank(address(0xB0B));
        erc721TLCDrop.publicMint(TIER); // Token Id #2

        vm.warp(START_OF_LIFE_CYCLE - 1 days + 1 seconds); // 1 second after 1 day before start of life cycle
        erc721TLCDrop.setUpdateFee(TIER, TOKEN_LIFECYCLE_UPDATE_FEE);
        erc721TLCDrop.setStartOfLifeCycle(TIER, START_OF_LIFE_CYCLE);
    }
}