// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../../src/samples/ERC721TLCDrop.sol";

contract ERC721TLCDropMintToAirdropTest is Test {
    ERC721TLCDrop erc721TLCDrop;

    uint256 constant TIER_TO_DROP = 9;
    uint256 constant MAX_AIRDROP_RECIPIENTS = 20;

    address owner;

    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event TierSet(uint256 indexed tokenId, uint256 indexed tierId, uint256 indexed atTimeStamp);

    error Paused();
    error Unauthorized();
    error InvalidTierId();
    error ExceedsMaxRecipients();
    error ExceedsMaxNumberMinted();

    function setUp() public {
        erc721TLCDrop = new ERC721TLCDrop();
        owner = address(erc721TLCDrop.owner());
        erc721TLCDrop.setLifeCycle(TIER_TO_DROP, 30);
    }

    function test_MintTo_ByNonOwnerOrAdmin() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(Unauthorized.selector);
        erc721TLCDrop.mintTo(address(0xDEAFBEEF), TIER_TO_DROP);
    }

    function test_MintTo_TierZero() public {
        vm.prank(owner);
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.mintTo(address(0xA11CE), 0);
    }

    function test_MintTo_TierEleven() public {
        vm.prank(owner);
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.mintTo(address(0xA11CE), 11);
    }

    function test_MintTo() public {
        vm.prank(owner);
        vm.expectEmit();
        emit Transfer(address(0), address(0xA11CE), 1);
        emit TierSet(1, TIER_TO_DROP, block.timestamp);
        erc721TLCDrop.mintTo(address(0xA11CE), TIER_TO_DROP);
    }

    function test_MintTo_SameTierToSameAddressTwice() public {
        vm.startPrank(owner);
        erc721TLCDrop.mintTo(address(0xA11CE), TIER_TO_DROP);
        vm.expectRevert(ExceedsMaxNumberMinted.selector);
        erc721TLCDrop.mintTo(address(0xA11CE), TIER_TO_DROP);
        vm.stopPrank();
    }

    function test_MintTo_WhenStatusIsPaused() public {
        erc721TLCDrop.setPausedStatus();

        vm.prank(owner);
        vm.expectRevert(Paused.selector);
        erc721TLCDrop.mintTo(address(0xA11CE), TIER_TO_DROP);
    }

    function test_Airdrop_ByNonOwnerOrAdmin() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(Unauthorized.selector);
        erc721TLCDrop.airdrop(_maxAirdropRecipients(), TIER_TO_DROP);
    }

    function test_Airdrop_TierZero() public {
        vm.prank(owner);
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.airdrop(_maxAirdropRecipients(), 0);
    }

    function test_Airdrop_TierEleven() public {
        vm.prank(owner);
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.airdrop(_maxAirdropRecipients(), 11);
    }

    function test_Airdrop_MaxRecipients() public {
        address[] memory recipients = _maxAirdropRecipients();
        
        vm.prank(owner);
        vm.expectEmit();
        // tokenId #1
        emit Transfer(address(0), recipients[0], 1);
        emit TierSet(1, TIER_TO_DROP, block.timestamp);
        // #2
        emit Transfer(address(0), recipients[1], 2);
        emit TierSet(2, TIER_TO_DROP, block.timestamp);
        // #3
        emit Transfer(address(0), recipients[2], 3);
        emit TierSet(3, TIER_TO_DROP, block.timestamp);
        // #4
        emit Transfer(address(0), recipients[3], 4);
        emit TierSet(4, TIER_TO_DROP, block.timestamp);
        // #5
        emit Transfer(address(0), recipients[4], 5);
        emit TierSet(5, TIER_TO_DROP, block.timestamp);
        // #6
        emit Transfer(address(0), recipients[5], 6);
        emit TierSet(6, TIER_TO_DROP, block.timestamp);
        // #7
        emit Transfer(address(0), recipients[6], 7);
        emit TierSet(7, TIER_TO_DROP, block.timestamp);
        // #8
        emit Transfer(address(0), recipients[7], 8);
        emit TierSet(8, TIER_TO_DROP, block.timestamp);
        // #9
        emit Transfer(address(0), recipients[8], 9);
        emit TierSet(9, TIER_TO_DROP, block.timestamp);
        // #10
        emit Transfer(address(0), recipients[9], 10);
        emit TierSet(10, TIER_TO_DROP, block.timestamp);
        // #11
        emit Transfer(address(0), recipients[10], 11);
        emit TierSet(11, TIER_TO_DROP, block.timestamp);
        // #12
        emit Transfer(address(0), recipients[11], 12);
        emit TierSet(12, TIER_TO_DROP, block.timestamp);
        // #13
        emit Transfer(address(0), recipients[12], 13);
        emit TierSet(13, TIER_TO_DROP, block.timestamp);
        // #14
        emit Transfer(address(0), recipients[13], 14);
        emit TierSet(14, TIER_TO_DROP, block.timestamp);
        // #15
        emit Transfer(address(0), recipients[14], 15);
        emit TierSet(15, TIER_TO_DROP, block.timestamp);
        // #16
        emit Transfer(address(0), recipients[15], 16);
        emit TierSet(16, TIER_TO_DROP, block.timestamp);
        // #17
        emit Transfer(address(0), recipients[16], 17);
        emit TierSet(17, TIER_TO_DROP, block.timestamp);
        // #18
        emit Transfer(address(0), recipients[17], 18);
        emit TierSet(18, TIER_TO_DROP, block.timestamp);
        // #19
        emit Transfer(address(0), recipients[18], 19);
        emit TierSet(19, TIER_TO_DROP, block.timestamp);
        // #20
        emit Transfer(address(0), recipients[19], 20);
        emit TierSet(20, TIER_TO_DROP, block.timestamp);

        erc721TLCDrop.airdrop(recipients, TIER_TO_DROP);
        assertEq(erc721TLCDrop.totalSupply(), 20);
    }

    function test_Airdrop_ExceedsMaxRecipients() public {
        vm.prank(owner);
        vm.expectRevert(ExceedsMaxRecipients.selector);
        erc721TLCDrop.airdrop(_maxAirdropRecipientsPlusOne(), TIER_TO_DROP);
    }

    function test_Airdrop_DoubleRecipientsInOneTx() public {
        address[] memory recipients = new address[](2);
        recipients[0] = 0xa74A9c716F60C7362a3909ca47E6362777C7EbcA;
        recipients[1] = 0xa74A9c716F60C7362a3909ca47E6362777C7EbcA;

        vm.prank(owner);
        vm.expectRevert(ExceedsMaxNumberMinted.selector);
        erc721TLCDrop.airdrop(recipients, TIER_TO_DROP);
    }

    function test_Airdrop_WhenStatusIsPaused() public {
        erc721TLCDrop.setPausedStatus();

        vm.prank(owner);
        vm.expectRevert(Paused.selector);
        erc721TLCDrop.airdrop(_maxAirdropRecipients(), TIER_TO_DROP);
    }


    ///////// INTERNAL SETUPS //////////

    function _maxAirdropRecipients() internal pure returns (address[] memory) {
        address[] memory recipients = new address[](MAX_AIRDROP_RECIPIENTS);
        recipients[0] = 0xa74A9c716F60C7362a3909ca47E6362777C7EbcA;
        recipients[1] = 0x364D1F67f71d976A317F65cD64Ebc1E6C48a14AA;
        recipients[2] = 0x4754393f17E07ACB5984a5CFF8fa29c294c76FbC;
        recipients[3] = 0x766582aA6cDB1b9076f0C66de634a2d84C9E9376;
        recipients[4] = 0x491af2C6E8a9843D915ADB04448Fa68cc9CDCAd2;
        recipients[5] = 0x17553fe85c45B5820Fd58E957F7A17B7948722dF;
        recipients[6] = 0xDb32083fC8A12516169Bd65901BA9ef1A85BEC4c;
        recipients[7] = 0x37Fa34cDA927b846FeE0D77A323dCF8c68C2A2D1;
        recipients[8] = 0x0793BC1E168599FD3dA14742090B0c27Bb535deb;
        recipients[9] = 0x4E753375650a7CeCE141d3165a8538ABFE19Ab9E;
        recipients[10] = 0x2b297fA9cD152F14CE1eA5865A6626B297815014;
        recipients[11] = 0x62Ed2411a7F0Ae00C7550D5ab71D805Be17b9806;
        recipients[12] = 0x04bFB5f17D526d09EBbD7bb46b094E763d771F4d;
        recipients[13] = 0x59fE1bf4f252090Dd9A351ea78E93D252a2FA529;
        recipients[14] = 0xb33512ce9C3b7606f5cE56C50D4E66543C38756B;
        recipients[15] = 0x687b0E8e8b3848E95f39c6616dC74b5b4d044f37;
        recipients[16] = 0x79c4580555D7158e3Ec648b8a7aA6A8eA098aC99;
        recipients[17] = 0xE3D0cD9AC285f63164bB7E64079051DED0253573;
        recipients[18] = 0x4510F7E683D1Df7dB5BF2a01aEA6f84757a2F0CC;
        recipients[19] = 0x39f9dBe4a60b5F017d95889eF9DC50B58cC543cA;
        return recipients;
    }

    function _maxAirdropRecipientsPlusOne() internal pure returns (address[] memory) {
        address[] memory recipients = new address[](MAX_AIRDROP_RECIPIENTS + 1); // Plus one
        recipients[0] = 0xa74A9c716F60C7362a3909ca47E6362777C7EbcA;
        recipients[1] = 0x364D1F67f71d976A317F65cD64Ebc1E6C48a14AA;
        recipients[2] = 0x4754393f17E07ACB5984a5CFF8fa29c294c76FbC;
        recipients[3] = 0x766582aA6cDB1b9076f0C66de634a2d84C9E9376;
        recipients[4] = 0x491af2C6E8a9843D915ADB04448Fa68cc9CDCAd2;
        recipients[5] = 0x17553fe85c45B5820Fd58E957F7A17B7948722dF;
        recipients[6] = 0xDb32083fC8A12516169Bd65901BA9ef1A85BEC4c;
        recipients[7] = 0x37Fa34cDA927b846FeE0D77A323dCF8c68C2A2D1;
        recipients[8] = 0x0793BC1E168599FD3dA14742090B0c27Bb535deb;
        recipients[9] = 0x4E753375650a7CeCE141d3165a8538ABFE19Ab9E;
        recipients[10] = 0x2b297fA9cD152F14CE1eA5865A6626B297815014;
        recipients[11] = 0x62Ed2411a7F0Ae00C7550D5ab71D805Be17b9806;
        recipients[12] = 0x04bFB5f17D526d09EBbD7bb46b094E763d771F4d;
        recipients[13] = 0x59fE1bf4f252090Dd9A351ea78E93D252a2FA529;
        recipients[14] = 0xb33512ce9C3b7606f5cE56C50D4E66543C38756B;
        recipients[15] = 0x687b0E8e8b3848E95f39c6616dC74b5b4d044f37;
        recipients[16] = 0x79c4580555D7158e3Ec648b8a7aA6A8eA098aC99;
        recipients[17] = 0xE3D0cD9AC285f63164bB7E64079051DED0253573;
        recipients[18] = 0x4510F7E683D1Df7dB5BF2a01aEA6f84757a2F0CC;
        recipients[19] = 0x39f9dBe4a60b5F017d95889eF9DC50B58cC543cA;
        recipients[20] = 0x2A0755D8016031c073494B056b17509c20dA4792; // Plus one
        return recipients;
    }
}