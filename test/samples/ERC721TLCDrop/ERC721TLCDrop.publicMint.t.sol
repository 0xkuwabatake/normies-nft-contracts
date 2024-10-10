// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../../src/samples/ERC721TLCDrop.sol";

contract ERC721TLCDropPublicMintTest is Test {
    ERC721TLCDrop erc721TLCDrop;

    uint256 constant PUBLIC_TIER_TO_MINT = 3;
    uint256 constant PUBLIC_TIER_TO_MINT_FEE = 0.069 ether;
    uint256 constant NOT_PUBLIC_TIER_TO_MINT = 4;
    uint256 constant LIFE_CYCLE = 30;

    address owner;
    
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event TierSet(uint256 indexed tokenId, uint256 indexed tierId, uint256 indexed atTimeStamp);
    event MintFeeUpdate(uint256 indexed tierId, uint256 indexed mintFee);

    error Paused();
    error InvalidFee();
    error Unauthorized();
    error InvalidTierId();
    error MintIsNotActive();
    error UndefinedLifeCycle();
    error InsufficientBalance();
    error ExceedsMaxNumberMinted();
    
    function setUp() public {
        erc721TLCDrop = new ERC721TLCDrop();
        owner = address(erc721TLCDrop.owner());
        erc721TLCDrop.setMintFee(PUBLIC_TIER_TO_MINT, PUBLIC_TIER_TO_MINT_FEE);
        erc721TLCDrop.setLifeCycle(PUBLIC_TIER_TO_MINT, LIFE_CYCLE);
        erc721TLCDrop.setMintStatus(PUBLIC_TIER_TO_MINT);
    }

    function test_Get_MintFee() public view {
        assertEq(erc721TLCDrop.mintFee(PUBLIC_TIER_TO_MINT), PUBLIC_TIER_TO_MINT_FEE);
    }

    function test_RevertIf_SetMintFee_ByNonOwnerOrAdmin() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(Unauthorized.selector);
        erc721TLCDrop.setMintFee(PUBLIC_TIER_TO_MINT, 0.042 ether);
    }

    function test_SetMintFee_IfFeeIsNonZero() public {
        vm.prank(owner);
        vm.expectEmit();
        emit MintFeeUpdate(PUBLIC_TIER_TO_MINT, 0.042 ether);
        erc721TLCDrop.setMintFee(PUBLIC_TIER_TO_MINT, 0.042 ether);
    }

    function test_SetMintFee_IfFeeIsZero() public {
        vm.prank(owner);
        vm.expectEmit();
        emit MintFeeUpdate(PUBLIC_TIER_TO_MINT, 0);
        erc721TLCDrop.setMintFee(PUBLIC_TIER_TO_MINT, 0);
    }

    function test_SetMintFee_IfFeeIsEqualToMaxUint64Value() public {
        vm.prank(owner);
        vm.expectEmit();
        emit MintFeeUpdate(PUBLIC_TIER_TO_MINT,18446744073709551615);
        erc721TLCDrop.setMintFee(PUBLIC_TIER_TO_MINT, 18446744073709551615);
    }

    function test_RevertIf_SetMintFee_IfFeeIsGreaterThanMaxUint64Value() public {
        vm.prank(owner);
        vm.expectRevert(InvalidFee.selector);
        erc721TLCDrop.setMintFee(PUBLIC_TIER_TO_MINT, 18446744073709551615 + 1); // 18.446744073709551616 ether
    }

    function test_RevertIf_PublicMint_IfTierIdIsTwo() public {
        vm.prank(address(0xA11CE));
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.publicMint(2);
    }

    function test_RevertIf_PublicMint_IfTierIdIsEight() public {
        vm.prank(address(0xB0B));
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.publicMint(8);
    }

    function test_RevertIf_PublicMint_NotPublicTierToMint_WithUndefinedLifeCycleAndMintStatusIsNotActive() public {
        vm.prank(address(0xCAFE));
        vm.expectRevert(UndefinedLifeCycle.selector);
        erc721TLCDrop.publicMint(NOT_PUBLIC_TIER_TO_MINT);
    }

    function test_RevertIf_PublicMint_NotPublicTierToMint_WithDefinedLifeCycleAndMintStatusIsNotActive() public {
        erc721TLCDrop.setLifeCycle(NOT_PUBLIC_TIER_TO_MINT, LIFE_CYCLE);

        vm.prank(address(0xDEAD));
        vm.expectRevert(MintIsNotActive.selector);
        erc721TLCDrop.publicMint(NOT_PUBLIC_TIER_TO_MINT);
    }

    function testFail_PublicMint_WithNonZeroMintFee_WhenEtherBalanceIsLessThanFromMintFee() public {
        hoax(address(0xF00), 0.068 ether);
        vm.expectRevert(InsufficientBalance.selector);
        erc721TLCDrop.publicMint{value: PUBLIC_TIER_TO_MINT_FEE}(PUBLIC_TIER_TO_MINT);
    }

    function test_PublicMint_WithNonZeroMintFee() public {
        hoax(address(0xDEAFBEEF), 1 ether);
        
        uint256 publicMinterBalanceBeforeMint = address(0xDEAFBEEF).balance;
        assertEq(publicMinterBalanceBeforeMint, 1 ether);

        uint256 contractBalanceBeforeMint = address(erc721TLCDrop).balance;
        assertEq(contractBalanceBeforeMint, 0);

        vm.expectEmit();
        emit Transfer(address(0), address(0xDEAFBEEF), 1);
        emit TierSet(1, PUBLIC_TIER_TO_MINT, block.timestamp);
        erc721TLCDrop.publicMint{value: PUBLIC_TIER_TO_MINT_FEE}(PUBLIC_TIER_TO_MINT);

        uint256 publicMinterBalanceAfterMint = address(0xDEAFBEEF).balance;
        assertEq(publicMinterBalanceAfterMint, publicMinterBalanceBeforeMint - PUBLIC_TIER_TO_MINT_FEE);

        uint256 contractBalanceAfterMint = address(erc721TLCDrop).balance;
        assertEq(contractBalanceAfterMint,PUBLIC_TIER_TO_MINT_FEE);
    }

    function test_PublicMint_WithZeroMintFee() public {
        erc721TLCDrop.setMintFee(PUBLIC_TIER_TO_MINT, 0); // Set mint fee to zero

        hoax(address(0xDEAFBEEF), 1 ether);
        vm.expectEmit();
        emit Transfer(address(0), address(0xDEAFBEEF), 1);
        emit TierSet(1, PUBLIC_TIER_TO_MINT, block.timestamp);
        erc721TLCDrop.publicMint(PUBLIC_TIER_TO_MINT);

        assertEq(erc721TLCDrop.tierId(1), PUBLIC_TIER_TO_MINT);
        assertEq(erc721TLCDrop.tokenTimestamp(1), block.timestamp);

        uint256[] memory expectedOwnedTokenId = erc721TLCDrop.tokensOfOwner(address(0xDEAFBEEF));
        expectedOwnedTokenId[0] = 1;
        assertEq(expectedOwnedTokenId, expectedOwnedTokenId);

        uint256[] memory expectedOwnedTierId = erc721TLCDrop.tiersOfOwner(address(0xDEAFBEEF));
        expectedOwnedTierId[0] = PUBLIC_TIER_TO_MINT;
        assertEq(expectedOwnedTierId, expectedOwnedTierId);
    }

    function test_RevertIf_PublicMint_IfPublicTierOwner_TryToMintSameTierTwice() public {
        // First mint
        vm.startPrank(address(0xDEAFBEEF));
        vm.deal(address(0xDEAFBEEF), 1 ether);
        erc721TLCDrop.publicMint{value: PUBLIC_TIER_TO_MINT_FEE}(PUBLIC_TIER_TO_MINT);
        // Second trial
        vm.expectRevert(ExceedsMaxNumberMinted.selector);
        erc721TLCDrop.publicMint{value: PUBLIC_TIER_TO_MINT_FEE}(PUBLIC_TIER_TO_MINT);
        vm.stopPrank();
    }

    // Public mint when status is paused
    function test_RevertIf_PublicMint_WhenStatusIsPaused() public {
        erc721TLCDrop.setPausedStatus();
        hoax(address(0xDEAFBEEF));
        vm.expectRevert(Paused.selector);
        erc721TLCDrop.publicMint(PUBLIC_TIER_TO_MINT);
    }
}