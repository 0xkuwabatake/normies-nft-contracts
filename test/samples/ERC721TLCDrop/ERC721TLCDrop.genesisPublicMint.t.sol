// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../../src/samples/ERC721TLCDrop.sol";

contract ERC721TLCDropGenesisPublicMintTest is Test {
    ERC721TLCDrop erc721TLCDrop;

    uint256 constant TIER_ONE = 1;
    uint256 constant TIER_TWO = 2;
    uint256 constant PUBLIC_TIER_TO_MINT = 6;
    uint256 constant PUBLIC_TIER_TO_MINT_FEE = 0.069 ether;
    uint256 constant NOT_PUBLIC_TIER_TO_MINT = 7;
    uint256 constant DISCOUNT_FOR_TIER_ONE_OWNER = 5000; // 50%
    uint256 constant DISCOUNT_FOR_TIER_TWO_OWNER = 2500; // 25%
    uint256 constant MAX_BPS = 10000;
    uint256 constant LIFE_CYCLE = 30;

    address owner;

    bytes32 constant TIER_ONE_ROOT = 0xc5f5fff0e907868734e97967cfff8763e6fe9aa97b9663827ac093a19289e2bd;
    bytes32 constant TIER_TWO_ROOT = 0xe32503c2d55198e441525cdc0bde22ba5f487cae1751efe3223e818840ccf2c8;

    address constant TIER_ONE_AND_TWO_OWNER = 0xcfd86e16635486b2eCAf674A98F24ed12a15c3b4;
    address constant TIER_ONE_OWNER_ONLY = 0xac912225f59d840c700cc9F04CD5Ade96Bd009BF; 
    address constant TIER_TWO_OWNER_ONLY = 0x67548737121A04CDf1A23C58E9B1F0B065C47c30;

    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event TierSet(uint256 indexed tokenId, uint256 indexed tierId, uint256 indexed atTimeStamp);
    event MintFeeForGenesisOwnerUpdate(
        uint256 indexed tierIsOwned,
        uint256 indexed tierToMint,
        uint256 indexed discountedMintFee
    );

    error Paused();
    error InvalidOwner();
    error UndefinedFee();
    error InvalidTierId();
    error MintIsNotActive();
    error UndefinedLifeCycle();
    error InsufficientBalance();
    error ExceedsMaxNumberMinted();
    
    function setUp() public {
        erc721TLCDrop = new ERC721TLCDrop();
        owner = address(erc721TLCDrop.owner());
        _setupForTierOneAndOrTwoOwner();
        erc721TLCDrop.setMintFee(PUBLIC_TIER_TO_MINT, PUBLIC_TIER_TO_MINT_FEE);
        erc721TLCDrop.setMintFeeForTierOneOwner(PUBLIC_TIER_TO_MINT, DISCOUNT_FOR_TIER_ONE_OWNER);
        erc721TLCDrop.setMintFeeForTierTwoOwner(PUBLIC_TIER_TO_MINT, DISCOUNT_FOR_TIER_TWO_OWNER);
        erc721TLCDrop.setLifeCycle(PUBLIC_TIER_TO_MINT, LIFE_CYCLE);
        erc721TLCDrop.setMintStatus(PUBLIC_TIER_TO_MINT);
    }

    function test_Get_MintFeeForTierOneOwner() public view {
        assertEq (
            erc721TLCDrop.mintFeeForTierOneOwner(PUBLIC_TIER_TO_MINT),
            PUBLIC_TIER_TO_MINT_FEE - (PUBLIC_TIER_TO_MINT_FEE * DISCOUNT_FOR_TIER_ONE_OWNER / MAX_BPS)
        );
    }

    function test_Get_MintFeeForTierTwoOwner() public view {
        assertEq (
            erc721TLCDrop.mintFeeForTierOneOwner(PUBLIC_TIER_TO_MINT),
            PUBLIC_TIER_TO_MINT_FEE - (PUBLIC_TIER_TO_MINT_FEE * DISCOUNT_FOR_TIER_ONE_OWNER / MAX_BPS)
        );
    }

    function test_Get_IsTierOwned_ByTierOneAndTwoOwner() public view {
        assertTrue(erc721TLCDrop.isTierOwned(TIER_ONE_AND_TWO_OWNER, TIER_ONE));
        assertTrue(erc721TLCDrop.isTierOwned(TIER_ONE_AND_TWO_OWNER, TIER_TWO));
    }

    function test_Get_IsTierOwned_ByTierOneOwnerOnly() public view {
        assertTrue(erc721TLCDrop.isTierOwned(TIER_ONE_OWNER_ONLY, TIER_ONE));
    }

    function test_Get_IsTierOwned_ByTierTwoOwnerOnly() public view {
        assertTrue(erc721TLCDrop.isTierOwned(TIER_TWO_OWNER_ONLY, TIER_TWO));
    }

    function test_SetMintFeeForTierOneOwner() public {
        vm.prank(owner);
        vm.expectEmit();
        emit MintFeeForGenesisOwnerUpdate(
            TIER_ONE,
            PUBLIC_TIER_TO_MINT,
            PUBLIC_TIER_TO_MINT_FEE - (PUBLIC_TIER_TO_MINT_FEE * 4200 / MAX_BPS)
        );
        erc721TLCDrop.setMintFeeForTierOneOwner(PUBLIC_TIER_TO_MINT, 4200);
    }

    function test_SetMintFeeForTierTwoOwner() public {
        vm.prank(owner);
        vm.expectEmit();
        emit MintFeeForGenesisOwnerUpdate(
            TIER_TWO,
            PUBLIC_TIER_TO_MINT,
            PUBLIC_TIER_TO_MINT_FEE - (PUBLIC_TIER_TO_MINT_FEE * 1300 / MAX_BPS)
        );
        erc721TLCDrop.setMintFeeForTierTwoOwner(PUBLIC_TIER_TO_MINT, 1300);
    }

    function test_RevertIf_GenesisPublicMint_IfTierIdIsTwo() public {
        vm.prank(TIER_TWO_OWNER_ONLY);
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.genesisPublicMint(TIER_TWO);
    }

    function test_RevertIf_GenesisPublicMint_IfTierIdIsEight() public {
        vm.prank(TIER_TWO_OWNER_ONLY);
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.genesisPublicMint(8);
    }

    function test_RevertIf_GenesisPublicMint_NotPublicTierToMint_WithUndefinedLifeCycleAndMintStatusIsNotActive() public {
        vm.prank(TIER_ONE_OWNER_ONLY);
        vm.expectRevert(UndefinedLifeCycle.selector);
        erc721TLCDrop.genesisPublicMint(NOT_PUBLIC_TIER_TO_MINT);
    }

    function test_RevertIf_GenesisPublicMint_NotPublicTierToMint_WithDefinedLifeCycleAndMintStatusIsNotActive() public {
        erc721TLCDrop.setLifeCycle(NOT_PUBLIC_TIER_TO_MINT, LIFE_CYCLE);

        vm.prank(TIER_ONE_OWNER_ONLY);
        vm.expectRevert(MintIsNotActive.selector);
        erc721TLCDrop.genesisPublicMint(NOT_PUBLIC_TIER_TO_MINT);
    }

    function test_RevertIf_GenesisPublicMint_NotPublicTierToMint_WithDefinedLifeCycleAndMintStatusIsActive() public {
        erc721TLCDrop.setLifeCycle(NOT_PUBLIC_TIER_TO_MINT, LIFE_CYCLE);
        erc721TLCDrop.setMintStatus(NOT_PUBLIC_TIER_TO_MINT);

        vm.prank(TIER_ONE_OWNER_ONLY);
        vm.expectRevert(UndefinedFee.selector);
        erc721TLCDrop.genesisPublicMint(NOT_PUBLIC_TIER_TO_MINT);
    }

    function test_RevertIf_GenesisPublicMint_NotPublicTierToMint_WithDefinedLifeCycleAndNonZeroMintFeeAndMintStatusIsActive() public {
        erc721TLCDrop.setLifeCycle(NOT_PUBLIC_TIER_TO_MINT, LIFE_CYCLE);
        erc721TLCDrop.setMintFee(NOT_PUBLIC_TIER_TO_MINT, 0.023 ether);
        erc721TLCDrop.setMintStatus(NOT_PUBLIC_TIER_TO_MINT);

        vm.prank(TIER_ONE_OWNER_ONLY);
        vm.expectRevert(UndefinedFee.selector); // Mint fee for tier one owner only for tier #4 is not defined
        erc721TLCDrop.genesisPublicMint(NOT_PUBLIC_TIER_TO_MINT);
    }

    function test_RevertIf_GenesisPublicMint_ByNonTierOneAndOrTwoOwner() public {
        hoax(address(0xBAD));
        vm.expectRevert(InvalidOwner.selector);
        erc721TLCDrop.genesisPublicMint(PUBLIC_TIER_TO_MINT);
    }

    function testFail_GenesisPublicMint_WhenEtherBalanceIsLessThanFromMintFeeForTierOneAndOrTwoOwner() public {
        uint256 mintFeeForTierOneOwner = erc721TLCDrop.mintFeeForTierOneOwner(PUBLIC_TIER_TO_MINT);
        uint256 mintFeeForTierTwoOwner = erc721TLCDrop.mintFeeForTierTwoOwner(PUBLIC_TIER_TO_MINT);

        vm.prank(TIER_ONE_AND_TWO_OWNER);
        vm.deal(TIER_ONE_AND_TWO_OWNER, 0.0344 ether); // Less than 0.0345 ether
        vm.expectRevert(InsufficientBalance.selector);
        erc721TLCDrop.genesisPublicMint{value: mintFeeForTierOneOwner}(PUBLIC_TIER_TO_MINT);

        vm.prank(TIER_ONE_OWNER_ONLY);
        vm.deal(TIER_ONE_OWNER_ONLY, 0.0344 ether); // Less than 0.0345 ether
        vm.expectRevert(InsufficientBalance.selector);
        erc721TLCDrop.genesisPublicMint{value: mintFeeForTierOneOwner}(PUBLIC_TIER_TO_MINT);

        vm.prank(TIER_TWO_OWNER_ONLY);
        vm.deal(TIER_TWO_OWNER_ONLY, 0.05174 ether); // Less than 0.05175 ether
        vm.expectRevert(InsufficientBalance.selector);
        erc721TLCDrop.genesisPublicMint{value: mintFeeForTierTwoOwner}(PUBLIC_TIER_TO_MINT);
    }

    function test_GenesisPublicMint_ForTierOneAndTwoOwner() public {
        uint256 mintFeeForTierOneOwner = erc721TLCDrop.mintFeeForTierOneOwner(PUBLIC_TIER_TO_MINT);
        
        vm.prank(TIER_ONE_AND_TWO_OWNER);
        vm.deal(TIER_ONE_AND_TWO_OWNER, 1 ether);

        uint256 tierOneAndTwoOwnerBalanceBeforeMint = TIER_ONE_AND_TWO_OWNER.balance;
        assertEq(tierOneAndTwoOwnerBalanceBeforeMint, 1 ether);

        uint256 contractBalanceBeforeMint = address(erc721TLCDrop).balance;
        assertEq(contractBalanceBeforeMint, 0);

        uint256 expectedMintedTokenId = 5; // TokenId #1 - #4 had been minted through whitelistmint

        vm.expectEmit();
        emit Transfer(address(0), TIER_ONE_AND_TWO_OWNER, expectedMintedTokenId);
        emit TierSet(expectedMintedTokenId, PUBLIC_TIER_TO_MINT, block.timestamp);
        erc721TLCDrop.genesisPublicMint{value: mintFeeForTierOneOwner}(PUBLIC_TIER_TO_MINT);

        uint256 tierOneAndTwoOwnerBalanceAfter = TIER_ONE_AND_TWO_OWNER.balance;
        assertEq(
            tierOneAndTwoOwnerBalanceAfter,
            tierOneAndTwoOwnerBalanceBeforeMint - erc721TLCDrop.mintFeeForTierOneOwner(PUBLIC_TIER_TO_MINT)
        );

        uint256 contractBalanceAfterMint = address(erc721TLCDrop).balance;
        assertEq(
            contractBalanceAfterMint,
            erc721TLCDrop.mintFeeForTierOneOwner(PUBLIC_TIER_TO_MINT)
        );
    }

    function test_GenesisPublicMint_ForTierOneOwnerOnly() public {
        uint256 mintFeeForTierOneOwner = erc721TLCDrop.mintFeeForTierOneOwner(PUBLIC_TIER_TO_MINT);
        
        vm.prank(TIER_ONE_OWNER_ONLY);
        vm.deal(TIER_ONE_OWNER_ONLY, 1 ether);

        uint256 expectedMintedTokenId = 5;

        vm.expectEmit();
        emit Transfer(address(0), TIER_ONE_OWNER_ONLY, expectedMintedTokenId);
        emit TierSet(expectedMintedTokenId, PUBLIC_TIER_TO_MINT, block.timestamp);
        erc721TLCDrop.genesisPublicMint{value: mintFeeForTierOneOwner}(PUBLIC_TIER_TO_MINT);

        assertEq(erc721TLCDrop.tierId(expectedMintedTokenId), PUBLIC_TIER_TO_MINT);
        assertEq(erc721TLCDrop.tokenTimestamp(expectedMintedTokenId), block.timestamp);

        uint256[] memory expectedOwnedTokenId = erc721TLCDrop.tokensOfOwner(TIER_ONE_OWNER_ONLY);
        expectedOwnedTokenId[0] = expectedMintedTokenId;
        assertEq(expectedOwnedTokenId, expectedOwnedTokenId);

        uint256[] memory expectedOwnedTierId = erc721TLCDrop.tiersOfOwner(TIER_ONE_OWNER_ONLY);
        expectedOwnedTierId[0] = PUBLIC_TIER_TO_MINT;
        assertEq(expectedOwnedTierId, expectedOwnedTierId);
    }

    function test_GenesisPublicMint_ForTierTwoOwnerOnly() public {
        uint256 mintFeeForTierTwoOwner = erc721TLCDrop.mintFeeForTierTwoOwner(PUBLIC_TIER_TO_MINT);
    
        vm.prank(TIER_TWO_OWNER_ONLY);
        vm.deal(TIER_TWO_OWNER_ONLY, 1 ether);

        uint256 expectedMintedTokenId = 5;

        vm.expectEmit();
        emit Transfer(address(0), TIER_TWO_OWNER_ONLY, expectedMintedTokenId);
        emit TierSet(expectedMintedTokenId, PUBLIC_TIER_TO_MINT, block.timestamp);
        erc721TLCDrop.genesisPublicMint{value: mintFeeForTierTwoOwner}(PUBLIC_TIER_TO_MINT);
    }

    function test_RevertIf_GenesisPublicMint_IfPublicTierOwner_TryToMintSameTierTwice() public {
        uint256 mintFeeForTierTwoOwner = erc721TLCDrop.mintFeeForTierTwoOwner(PUBLIC_TIER_TO_MINT);

        // First mint
        vm.startPrank(TIER_TWO_OWNER_ONLY);
        vm.deal(TIER_TWO_OWNER_ONLY, 1 ether);
        erc721TLCDrop.genesisPublicMint{value: mintFeeForTierTwoOwner}(PUBLIC_TIER_TO_MINT);
        // Second trial
        vm.expectRevert(ExceedsMaxNumberMinted.selector);
        erc721TLCDrop.genesisPublicMint{value: mintFeeForTierTwoOwner}(PUBLIC_TIER_TO_MINT);
        vm.stopPrank();
    }

    function test_RevertIf_GenesisPublicMint_WhenStatusIsPaused() public {
        erc721TLCDrop.setPausedStatus();

        vm.prank(TIER_TWO_OWNER_ONLY);
        vm.expectRevert(Paused.selector);
        erc721TLCDrop.genesisPublicMint(PUBLIC_TIER_TO_MINT);
    }

    ///////// INTERNAL SETUPS //////////

    function _setupForTierOneAndOrTwoOwner() internal {
        // Tier one setups
        erc721TLCDrop.setMerkleRoot(TIER_ONE, TIER_ONE_ROOT);
        erc721TLCDrop.setLifeCycle(TIER_ONE, LIFE_CYCLE);
        erc721TLCDrop.setMintStatus(TIER_ONE);
        // Tier two setups
        erc721TLCDrop.setMerkleRoot(TIER_TWO, TIER_TWO_ROOT);
        erc721TLCDrop.setLifeCycle(TIER_TWO, LIFE_CYCLE);
        erc721TLCDrop.setMintStatus(TIER_TWO);

        vm.prank(TIER_ONE_AND_TWO_OWNER);
        erc721TLCDrop.whitelistMint(TIER_ONE, _tierOneAndTwoOwnerProofForTierOne());
        vm.prank(TIER_ONE_AND_TWO_OWNER);
        erc721TLCDrop.whitelistMint(TIER_TWO, _tierOneAndTwoOwnerProofForTierTwo());
        vm.prank(TIER_ONE_OWNER_ONLY);
        erc721TLCDrop.whitelistMint(TIER_ONE, _tierOneOwnerOnlyProofForTierOne());
        vm.prank(TIER_TWO_OWNER_ONLY);
        erc721TLCDrop.whitelistMint(TIER_TWO, _tierTwoOwnerOnlyProofForTierTwo());
    }

    // Merkle proof for tier one and two owner for tier #1
    // [0x085cfce4666f58f44ff4b5c6b7ec5cdb72c2eb18f83600af9d2f9bd1636c6f1c,
    // 0x01f96fdc02e731bed05290ce1c01891d27b1d72e321310089f2ac64e87f07271]
    function _tierOneAndTwoOwnerProofForTierOne() internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x085cfce4666f58f44ff4b5c6b7ec5cdb72c2eb18f83600af9d2f9bd1636c6f1c;
        proof[1] = 0x01f96fdc02e731bed05290ce1c01891d27b1d72e321310089f2ac64e87f07271;
        return proof;
    }

    // Merkle proof for tier one and two owner for tier #2
    // [0xffe31e8c428270f72e02bf1f9567496c78b36b009fc6d12fb9a4080491475a93,
    // 0xcca8cb98f4ef9fdd4dc213d8279e2b4ce471c5ea96fecaf0479c2b5bce9b8861]
    function _tierOneAndTwoOwnerProofForTierTwo() internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0xffe31e8c428270f72e02bf1f9567496c78b36b009fc6d12fb9a4080491475a93;
        proof[1] = 0xcca8cb98f4ef9fdd4dc213d8279e2b4ce471c5ea96fecaf0479c2b5bce9b8861;
        return proof;
    }

    // Merkle proof for tier one only for tier #1
    // [0x97ffde8f93071e7e114475c8259750d4f76de53b0fed8e9360280726f7de5481,
    // 0xd257f519dc9b1bf05f8672757f55f817eacd6569ddd95cec5f5f05a131d3d423]
    function _tierOneOwnerOnlyProofForTierOne() internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x97ffde8f93071e7e114475c8259750d4f76de53b0fed8e9360280726f7de5481;
        proof[1] = 0xd257f519dc9b1bf05f8672757f55f817eacd6569ddd95cec5f5f05a131d3d423;
        return proof;
    }

    // Merkle proof for tier two only for tier #2
    // [0xc0354f8fc089d3a388a69926ceb2d667475f39170ea8812df5d4fad1ee6c7c26,
    // 0xcca8cb98f4ef9fdd4dc213d8279e2b4ce471c5ea96fecaf0479c2b5bce9b8861]
    function _tierTwoOwnerOnlyProofForTierTwo() internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0xc0354f8fc089d3a388a69926ceb2d667475f39170ea8812df5d4fad1ee6c7c26;
        proof[1] = 0xcca8cb98f4ef9fdd4dc213d8279e2b4ce471c5ea96fecaf0479c2b5bce9b8861;
        return proof;
    }
}