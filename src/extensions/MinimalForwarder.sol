// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "solady/utils/ECDSA.sol";
import "solady/utils/EIP712.sol";
import "solady/auth/Ownable.sol";

/// @notice Minimal Trusted Forwarder contract for meta transaction based on ERC-2771.
/// @author 0xkuwabatake(@0xkuwabatake)
/// @author Modified from Openzeppelin
/// (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/metatx/MinimalForwarder.sol)
contract MinimalForwarder is EIP712, Ownable {
    using ECDSA for bytes32;

    ///////// CONSTANT ////////////////////////////////////////////////////////////////////////////O-'

    /// @dev `keccak256("ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)")`.
    bytes32 private constant _TYPEHASH =
        0xdd8f4b70b0f4393e889bd39128a30628a78b61816a9eb8199759e7a349657e48;

    ///////// CUSTOM TYPE /////////////////////////////////////////////////////////////////////////O-'

    /// @dev Custom type for ForwardRequest.
    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
    }

    ///////// STORAGE /////////////////////////////////////////////////////////////////////////////O-'

    /// @dev Mapping from transaction signer to transaction count (nonce).
    mapping(address => uint256) private _nonces;

    /// @dev The authorized gas relay (relayer) address.
    address public relayer;

    ///////// CUSTOM ERRORS ///////////////////////////////////////////////////////////////////////O-'

    /// @dev Caller is unauthorized relayer.
    error UnauthorizedRelayer();

    /// @dev Signer's request does not match with its signature.
    error SignatureDoesNotMatchRequest();

    ///////// MODIFIER ////////////////////////////////////////////////////////////////////////////O-'

    /// @dev Only authorized gas relay (relayer).
    modifier onlyAuthorizedRelayer() {
        if (msg.sender != relayer) _revert(UnauthorizedRelayer.selector);
        _;
    }

    ///////// CONSTRUCTOR /////////////////////////////////////////////////////////////////////////O-'

    constructor() EIP712() {
        address _owner = tx.origin;
        _initializeOwner(_owner);
    }

    ///////// EXTERNAL FUNCTIONS //////////////////////////////////////////////////////////////////O-'

    /// @dev Sets `gasRelay` for authorized `relayer`.
    function setRelayer(address gasRelay) external onlyOwner {
        relayer = gasRelay;
    }

    /// @dev Reset relayer back to address zero (default).
    function resetRelayer() external onlyOwner {
        relayer = address(0);
    }

    ///////// PUBLIC FUNCTIONS ////////////////////////////////////////////////////////////////////O-'

    /// @dev Returns the next unused nonce from transaction `signer`.
    function getNonce(address signer) public view returns (uint256) {
        return _nonces[signer];
    }

    /// @dev Indicates whether any particular `gasRelay` address is the authorized relayer.
    function isAuthorizedRelayer(address gasRelay) public view returns (bool) {
        return gasRelay == relayer;
    }

    /**
     * @dev Returns `true` if a `request` is valid for a provided `signature`.
     * @param request The ForwardRequest from transaction signer.
     * @param signature The signed ForwardRequest from transaction signer.
     */
    function verify(ForwardRequest calldata request, bytes calldata signature) 
        public
        view
        onlyAuthorizedRelayer
        returns (bool) 
    {
        address signer = _hashTypedData(
            keccak256(
                abi.encode(
                    _TYPEHASH,
                    request.from,
                    request.to,
                    request.value,
                    request.gas,
                    request.nonce,
                    keccak256(request.data)
                )
            )
        ).recover(signature);

        return _nonces[request.from] == request.nonce && signer == request.from;
    }

    /**
     * @dev Executes a `request` on behalf of `signature`'s signer using the ERC-2771 protocol.
     * @param request The ForwardRequest from transaction signer.
     * @param signature The signed ForwardRequest from transaction signer.
     */
    function execute(ForwardRequest calldata request, bytes calldata signature)
        public
        payable
        returns (bool, bytes memory) 
    {
        if (!verify(request, signature)) _revert(SignatureDoesNotMatchRequest.selector);

        _nonces[request.from] = request.nonce + 1;

        // Extract transaction signer's address
        // Ref: https://eips.ethereum.org/EIPS/eip-2771#extracting-the-transaction-signer-address
        (bool success, bytes memory returndata) = request.to.call{gas: request.gas, value: request.value}(
            abi.encodePacked(request.data, request.from)
        );

        // Validate that the relayer has sent enough gas for the call
        // See https://ronan.eth.limo/blog/ethereum-gas-dangers/
        if (gasleft() <= request.gas / 63) {
            // We explicitly trigger invalid opcode to consume all gas and bubble-up the effects,
            // since neither revert or assert consume all gas since Solidity 0.8.0
            /// @solidity memory-safe-assembly
            assembly {
                invalid()
            }
        }

        return (success, returndata);
    }

    ///////// INTERNAL FUNCTION ///////////////////////////////////////////////////////////////////O-'
    
    /// @dev See {EIP712 - _domainNameAndVersion}.
    function _domainNameAndVersion()
        internal
        view
        virtual
        override
        returns (string memory name, string memory version)
    {
        name = "MinimalForwarder";
        version = "0.0.1";
    }

    ///////// PRIVATE FUNCTION ////////////////////////////////////////////////////////////////////O-'

    /// @dev Helper function for more efficient reverts.
    function _revert(bytes4 errorSelector) private pure {
        assembly {
            mstore(0x00, errorSelector)
            revert(0x00, 0x04)
        }
    }
}