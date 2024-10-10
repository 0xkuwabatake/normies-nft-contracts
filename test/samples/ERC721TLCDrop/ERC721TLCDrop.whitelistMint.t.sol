// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../../src/samples/ERC721TLCDrop.sol";

contract ERC721TLCDropWhitelistMintTest is Test {
    ERC721TLCDrop erc721TLCDrop;

    uint256 constant WL_TIER_TO_MINT = 1;
    uint256 constant WL_TIER_TO_MINT_FEE = 0.042 ether;
    uint256 constant NOT_WL_TIER_TO_MINT = 2;
    uint256 constant LIFE_CYCLE = 30;

    // Merkle Root  : 0xc5f5fff0e907868734e97967cfff8763e6fe9aa97b9663827ac093a19289e2bd
    bytes32 constant WL_TIER_TO_MINT_ROOT = 0xc5f5fff0e907868734e97967cfff8763e6fe9aa97b9663827ac093a19289e2bd;
    // WL addr index #0   : 0xcfd86e16635486b2eCAf674A98F24ed12a15c3b4,1
    // WL addr index #1   : 0xac912225f59d840c700cc9F04CD5Ade96Bd009BF,1
    // WL addr index #2   : 0x67548737121A04CDf1A23C58E9B1F0B065C47c30,1
    // WL addr index #3   : 0x1F51eeB2F5e5B4B008AA4364268A0D31e8476e09,1
    address constant WL_ADDR_INDEX_ZERO = 0xcfd86e16635486b2eCAf674A98F24ed12a15c3b4;    
    address constant WL_ADDR_INDEX_ONE = 0xac912225f59d840c700cc9F04CD5Ade96Bd009BF;  
    
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event TierSet(uint256 indexed tokenId, uint256 indexed tierId, uint256 indexed atTimeStamp);

    error Paused();
    error InvalidTierId();
    error MintIsNotActive();
    error InvalidMerkleProof();
    error UndefinedLifeCycle();
    error InsufficientBalance();
    error ExceedsMaxNumberMinted();

    function setUp() public {
        erc721TLCDrop = new ERC721TLCDrop();
        erc721TLCDrop.setMerkleRoot(WL_TIER_TO_MINT, WL_TIER_TO_MINT_ROOT);
        erc721TLCDrop.setLifeCycle(WL_TIER_TO_MINT, LIFE_CYCLE);
        erc721TLCDrop.setMintStatus(WL_TIER_TO_MINT);
    }

    function test_Get_MerkleRoot() public view {
        assertEq(erc721TLCDrop.merkleRoot(WL_TIER_TO_MINT), WL_TIER_TO_MINT_ROOT);
    }

    function test_Get_IsMintActive() public view {
        assertTrue(erc721TLCDrop.isMintActive(WL_TIER_TO_MINT));
    }

    function test_RevertIf_WhitelistMint_IfTierIdIsZero() public {
        vm.prank(WL_ADDR_INDEX_ZERO);
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.whitelistMint(0, _wlAddrIndexZeroProofForTierOne());
    }

    function test_RevertIf_WhitelistMint_IfTierIdIsThree() public {
        vm.prank(WL_ADDR_INDEX_ZERO);
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.whitelistMint(3, _wlAddrIndexZeroProofForTierOne());
    }

    function test_RevertIf_WhitelistMint_NotWhitelistTierToMint_WithUndefinedLifeCycleAndMindStatusIsNotActive() public {
        vm.prank(WL_ADDR_INDEX_ZERO);
        vm.expectRevert(UndefinedLifeCycle.selector);
        erc721TLCDrop.whitelistMint(NOT_WL_TIER_TO_MINT, _wlAddrIndexZeroProofForTierOne());
    }

    function test_RevertIf_WhitelistMint_NotWhitelistTierToMint_WithDefinedLifeCycleAndMintStatusIsNotActive() public {
        erc721TLCDrop.setLifeCycle(NOT_WL_TIER_TO_MINT, LIFE_CYCLE);
        
        vm.prank(WL_ADDR_INDEX_ZERO);
        vm.expectRevert(MintIsNotActive.selector);
        erc721TLCDrop.whitelistMint(NOT_WL_TIER_TO_MINT, _wlAddrIndexZeroProofForTierOne());
    }

    function test_RevertIf_WhitelistMint_NotWhitelistTierToMint_WithDefinedLifeCycleAndMintStatusIsActive() public {
        erc721TLCDrop.setLifeCycle(NOT_WL_TIER_TO_MINT, LIFE_CYCLE);
        erc721TLCDrop.setMintStatus(NOT_WL_TIER_TO_MINT);

        vm.prank(WL_ADDR_INDEX_ZERO);
        vm.expectRevert(InvalidMerkleProof.selector);
        erc721TLCDrop.whitelistMint(NOT_WL_TIER_TO_MINT, _wlAddrIndexZeroProofForTierOne());
    }

    function test_RevertIf_WhitelistMint_WithFalseMerkleProof() public {
        vm.prank(WL_ADDR_INDEX_ZERO);
        vm.expectRevert(InvalidMerkleProof.selector);
        erc721TLCDrop.whitelistMint(WL_TIER_TO_MINT ,_wlAddrIndexOneProofForTierOne());
    }

    function test_RevertIf_WhitelistMint_ByNonWhitelistedAddress() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(InvalidMerkleProof.selector);
        erc721TLCDrop.whitelistMint(WL_TIER_TO_MINT, _wlAddrIndexZeroProofForTierOne());
    }

    function testFail_WhitelistMint_WithMintFee_WhenEtherBalanceIsLessThanFromMintFee() public {
        erc721TLCDrop.setMintFee(WL_TIER_TO_MINT, WL_TIER_TO_MINT_FEE);

        vm.prank(WL_ADDR_INDEX_ZERO);
        vm.deal(WL_ADDR_INDEX_ZERO, 0.041 ether); // Less than 0.042 ether
        vm.expectRevert(InsufficientBalance.selector);
        erc721TLCDrop.whitelistMint{value: WL_TIER_TO_MINT_FEE}(WL_TIER_TO_MINT, _wlAddrIndexZeroProofForTierOne());
    }

    function test_WhitelistMint_WithZeroMintFee() public {
        vm.prank(WL_ADDR_INDEX_ZERO);
        vm.expectEmit();
        emit Transfer(address(0), WL_ADDR_INDEX_ZERO, 1); // Token ID starts from 1 (one)
        emit TierSet(1, WL_TIER_TO_MINT, block.timestamp);
        erc721TLCDrop.whitelistMint(WL_TIER_TO_MINT, _wlAddrIndexZeroProofForTierOne());

        assertEq(erc721TLCDrop.tierId(1), WL_TIER_TO_MINT);
        assertEq(erc721TLCDrop.tokenTimestamp(1), block.timestamp);

        uint256[] memory expectedOwnedTokenId = erc721TLCDrop.tokensOfOwner(WL_ADDR_INDEX_ZERO);
        expectedOwnedTokenId[0] = 1;
        assertEq(expectedOwnedTokenId, expectedOwnedTokenId);

        uint256[] memory expectedOwnedTierId = erc721TLCDrop.tiersOfOwner(WL_ADDR_INDEX_ZERO);
        expectedOwnedTierId[0] = WL_TIER_TO_MINT;
        assertEq(expectedOwnedTierId, expectedOwnedTierId);
    }

    function test_WhitelistMint_WithNonZeroMintFee_WhenEtherBalanceIsGreaterThanMintFee() public {
        erc721TLCDrop.setMintFee(WL_TIER_TO_MINT, WL_TIER_TO_MINT_FEE);

        vm.prank(WL_ADDR_INDEX_ZERO);
        vm.deal(WL_ADDR_INDEX_ZERO, 1 ether);

        uint256 wlAddrZeroBalanceBeforeMint = WL_ADDR_INDEX_ZERO.balance;
        assertEq(wlAddrZeroBalanceBeforeMint, 1 ether);

        uint256 contractBalanceBeforeMint = address(erc721TLCDrop).balance;
        assertEq(contractBalanceBeforeMint, 0);

        vm.expectEmit();
        emit Transfer(address(0), WL_ADDR_INDEX_ZERO, 1);
        emit TierSet(1, WL_TIER_TO_MINT, block.timestamp);
        erc721TLCDrop.whitelistMint{value: WL_TIER_TO_MINT_FEE}(WL_TIER_TO_MINT, _wlAddrIndexZeroProofForTierOne());

        uint256 wlAddrZeroBalanceAfterMint = WL_ADDR_INDEX_ZERO.balance;
        assertEq(wlAddrZeroBalanceAfterMint, wlAddrZeroBalanceBeforeMint - WL_TIER_TO_MINT_FEE);

        uint256 contractBalanceAfterMint = address(erc721TLCDrop).balance;
        assertEq(contractBalanceAfterMint, WL_TIER_TO_MINT_FEE);
    }

    function test_RevertIf_WhitelistMint_IfWhitelistTierOwner_TryToMintSameTierTwice() public {
        // First mint
        vm.startPrank(WL_ADDR_INDEX_ZERO);
        erc721TLCDrop.whitelistMint(WL_TIER_TO_MINT, _wlAddrIndexZeroProofForTierOne());
        // Second trial
        vm.expectRevert(ExceedsMaxNumberMinted.selector);
        erc721TLCDrop.whitelistMint(WL_TIER_TO_MINT, _wlAddrIndexZeroProofForTierOne());
        vm.stopPrank();
    }

    function test_RevertIf_WhitelistMint_WhenStatusIsPaused() public {
        erc721TLCDrop.setPausedStatus();

        vm.prank(WL_ADDR_INDEX_ZERO);
        vm.expectRevert(Paused.selector);
        erc721TLCDrop.whitelistMint(WL_TIER_TO_MINT, _wlAddrIndexZeroProofForTierOne());
    }

    ///////// INTERNAL SETUPS //////////

    // Merkle Proof for WL addr index #0
    // [0x085cfce4666f58f44ff4b5c6b7ec5cdb72c2eb18f83600af9d2f9bd1636c6f1c,
    // 0x01f96fdc02e731bed05290ce1c01891d27b1d72e321310089f2ac64e87f07271]
    function _wlAddrIndexZeroProofForTierOne() internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x085cfce4666f58f44ff4b5c6b7ec5cdb72c2eb18f83600af9d2f9bd1636c6f1c;
        proof[1] = 0x01f96fdc02e731bed05290ce1c01891d27b1d72e321310089f2ac64e87f07271;
        return proof;
    }

    // Merkle Proof for WL addr index #1
    // [0x97ffde8f93071e7e114475c8259750d4f76de53b0fed8e9360280726f7de5481,
    // 0xd257f519dc9b1bf05f8672757f55f817eacd6569ddd95cec5f5f05a131d3d423]
    function _wlAddrIndexOneProofForTierOne() internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x97ffde8f93071e7e114475c8259750d4f76de53b0fed8e9360280726f7de5481;
        proof[1] = 0xd257f519dc9b1bf05f8672757f55f817eacd6569ddd95cec5f5f05a131d3d423;
        return proof;
    }
}