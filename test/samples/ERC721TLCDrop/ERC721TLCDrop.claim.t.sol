// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "solady/utils/EIP712.sol";
import "../../../src/samples/ERC721TLCDrop.sol";
import "../../../src/extensions/ERC2771Context.sol";
import "../../../src/extensions/MinimalForwarder.sol";

contract ERC721TLCDropClaimTest is Test {
    ERC721TLCDrop erc721TLCDrop;
    MinimalForwarder forwarder;

    // `keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")`.
    bytes32 constant DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    // `keccak256("ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)")`.
    bytes32 constant TYPEHASH = 0xdd8f4b70b0f4393e889bd39128a30628a78b61816a9eb8199759e7a349657e48;

    uint256 constant CLAIM_TIER_TO_MINT = 8;
    uint256 constant NOT_CLAIM_TIER_TO_MINT = 9;

    uint256 relayerPrivKey;
    uint256 signerPrivKey;

    address relayer;
    address signer;

    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event TierSet(uint256 indexed tokenId, uint256 indexed tierId, uint256 indexed atTimeStamp);

    error Paused();
    error InvalidTierId();
    error UndefinedLifeCycle();
    error UnauthorizedRelayer();
    error UnauthorizedForwarder();
    error SignatureDoesNotMatchRequest();

    function setUp() public {
        erc721TLCDrop = new ERC721TLCDrop();
        forwarder = new MinimalForwarder();

        relayerPrivKey = 0xA11CE;
        signerPrivKey = 0xB0B;
        relayer = vm.addr(relayerPrivKey);
        signer = vm.addr(signerPrivKey);

        erc721TLCDrop.setTrustedForwarder(address(forwarder));
        erc721TLCDrop.setLifeCycle(CLAIM_TIER_TO_MINT, 30);
        forwarder.setRelayer(address(relayer));
    }

    function test_Get_TrustedForwarder() public view {
        assertEq(erc721TLCDrop.trustedForwarder(), address(forwarder));
    }

    function test_Get_IsTrustedForwarder() public view {
        assertTrue(erc721TLCDrop.isTrustedForwarder(address(forwarder)));
    }

    function test_Get_IsAuthorizedRelayer_FromForwarderContract() public view {
        assertTrue(forwarder.isAuthorizedRelayer(relayer));
    }

    function test_Get_Verify_FromForwarderContract() public view {
        assertTrue(forwarder.verify(_validRequest(), _validSignature()));
    }

    function test_GetNonce_FromForwarderContract() public {
        assertEq(forwarder.getNonce(signer), 0);

        vm.prank(relayer); 
        forwarder.execute(_validRequest(), _validSignature());

        assertEq(forwarder.getNonce(signer), 1);
    }

    function test_RevertIf_Claim_IfTierIdIsZero() public {
        vm.prank(relayer);
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.claim(signer, 0); // Relayer try to call claim for tier #0 directly
    }

    function test_RevertIf_Claim_IfTierIdIsSeven() public {
        vm.prank(relayer);
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.claim(signer, 7); 
    }

    function test_RevertIf_Claim_IfTierIdIsEleven() public {
        vm.prank(relayer);
        vm.expectRevert(InvalidTierId.selector);
        erc721TLCDrop.claim(signer, 11); 
    }

    function test_RevertIf_Claim_IfNotTierToClaim() public {
        vm.prank(relayer);
        vm.expectRevert(UndefinedLifeCycle.selector);
        erc721TLCDrop.claim(signer, NOT_CLAIM_TIER_TO_MINT);
    }

    function test_RevertIf_Claim_NotByTrustedForwarder() public {
        vm.prank(relayer); 
        vm.expectRevert(UnauthorizedForwarder.selector);
        erc721TLCDrop.claim(signer, CLAIM_TIER_TO_MINT); // Authorized relayer can't directly call claim function
    }

    function test_RevertIf_Execute_ByForwarderContract_ByUnautorizedRelayer() public {
        hoax(address(0xBAD)); 
        vm.expectRevert(UnauthorizedRelayer.selector);
        forwarder.execute(_validRequest(), _validSignature()); // Unauthorized relayer try to execute the request
    }

    function test_RevertIf_Execute_ByForwarderContract_IfSignatureDoesNotMatchRequest() public {
        vm.prank(relayer);
        vm.expectRevert(SignatureDoesNotMatchRequest.selector);
        forwarder.execute(_invalidNonceAtRequest(), _validSignature());
    }

    function testFail_Execute_ByForwarderContract_WhenStatusIsPaused() public {
        erc721TLCDrop.setPausedStatus();

        vm.prank(relayer);
        vm.expectRevert();
        forwarder.execute(_validRequest(), _validSignature());
    }

    function test_Execute_ByForwarderContract() public {
        vm.prank(relayer); // Relayer accepts the signer's request
        vm.expectEmit();
        emit Transfer(address(0), signer, 1);
        emit TierSet(1, CLAIM_TIER_TO_MINT, block.timestamp);
        forwarder.execute(_validRequest(), _validSignature()); // Forwarder executes the signer's request
    }

    ///////// INTERNAL CONFIGS //////////

    // Valid signature
    function _validSignature() internal view returns (bytes memory signature) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivKey, _validDigest());
        // console.logBytes32(r);
        // console.logBytes32(s);
        // console.logUint(v);    
        return abi.encodePacked(r,s,v);
        // console.logBytes(signature);
    }

    // Valid digest
    function _validDigest() internal view returns (bytes32 digest) {
        bytes32 domainSeparator = _domainSeparator();
        bytes32 structHash = _structHash();

        /// @solidity memory-safe-assembly
        assembly {
            // Compute the digest.
            mstore(0x00, 0x1901000000000000) // Store "\x19\x01".
            mstore(0x1a, domainSeparator) // Store the domain separator.
            mstore(0x3a, structHash) // Store the struct hash.
            digest := keccak256(0x18, 0x42)
            // Restore the part of the free memory slot that was overwritten.
            mstore(0x3a, 0)
        }
    }

    // Separator
    function _domainSeparator() internal view returns (bytes32 separator) {
        bytes32 nameHash = keccak256(bytes("MinimalForwarder"));
        bytes32 versionHash = keccak256(bytes("0.0.1"));
        uint256 _forwarder = uint256(uint160(address(forwarder)));

        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) 
            mstore(m, DOMAIN_TYPEHASH)
            mstore(add(m, 0x20), nameHash)
            mstore(add(m, 0x40), versionHash)
            mstore(add(m, 0x60), chainid())
            mstore(add(m, 0x80), _forwarder) 
            separator := keccak256(m, 0xa0)
        }
    }

    // Valid struct hash
    function _structHash() internal view returns (bytes32 structHash) {
        MinimalForwarder.ForwardRequest memory request = _validRequest();

        return keccak256(
            abi.encode(
                TYPEHASH,
                request.from,
                request.to,
                request.value,
                request.gas,
                request.nonce,
                keccak256(request.data)
            )
        );
    }

    // Valid request
    function _validRequest() internal view returns (MinimalForwarder.ForwardRequest memory) {
        bytes memory _calldata = abi.encodeWithSignature("claim(address,uint256)", signer, CLAIM_TIER_TO_MINT);
        // console.logBytes(_calldata);
        return MinimalForwarder.ForwardRequest ({
            from: signer,
            to: address(erc721TLCDrop), 
            value: 0,
            gas: 200000,
            nonce: 0,
            data: _calldata
        });
    }

    // Invalid nonce at request
    function _invalidNonceAtRequest() internal view returns (MinimalForwarder.ForwardRequest memory) {
        bytes memory _calldata = abi.encodeWithSignature("claim(address,uint256)", signer, CLAIM_TIER_TO_MINT);
        
        return MinimalForwarder.ForwardRequest ({
            from: signer,
            to: address(erc721TLCDrop), 
            value: 0,
            gas: 200000,
            nonce: 1,   // Nonce should be zero
            data: _calldata
        });
    }
}