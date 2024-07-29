// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Contract Extension to provide context based on ERC-2771.
/// @author 0xkuwabatake(@0xkuwabatake)
/// @author Modified from OpenZeppelin
/// (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/metatx/ERC2771Context.sol)
abstract contract ERC2771Context {

    ///////// STORAGE /////////////////////////////////////////////////////////////////////////////O-'

    /// @dev The address of trusted forwarder.
    address internal _trustedForwarder;

    ///////// CUSTOM ERROR ////////////////////////////////////////////////////////////////////////O-'

    /// @dev Caller is unauthorized trusted forwarder.
    error UnauthorizedForwarder();

    ///////// MODIFIER ////////////////////////////////////////////////////////////////////////////O-'

    /// @dev Only trusted forwarder.
    modifier onlyTrustedForwarder() {
        if (msg.sender != _trustedForwarder) revert UnauthorizedForwarder();
        _;
    }

    ///////// PUBLIC GETTER FUNCTIONS /////////////////////////////////////////////////////////////O-'

    /// @dev Returns the currently active trusted forwarder.
    function trustedForwarder() public view returns (address) {
        return _trustedForwarder;
    }

    /// @dev Indicates whether any particular address is the trusted forwarder.
    /// See: https://eips.ethereum.org/EIPS/eip-2771#protocol-support-discovery-mechanism
    function isTrustedForwarder(address forwarder) public view returns (bool) {
        return forwarder == trustedForwarder();
    }

    ///////// INTERNAL SETTER FUNCTIONS ///////////////////////////////////////////////////////////O-'

    /// @dev Sets `forwarder` as trusted torwarder.
    function _setTrustedForwarder(address forwarder) internal {
        _trustedForwarder = forwarder;
    }

    /// @dev Reset trusted forwarder back to zero address (default).
    function _resetTrustedForwarder() internal {
        _trustedForwarder = address(0);
    }

    ///////// INTERNAL GETTER FUNCTIONS ///////////////////////////////////////////////////////////O-'

    /**
     * @dev Override for `msg.sender`. Defaults to the original `msg.sender` whenever
     * a call is not performed by the trusted forwarder or the calldata length is less than
     * 20 bytes (an address length).
     */
    function _msgSender() internal view returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return msg.sender;
        }
    }

    /**
     * @dev Override for `msg.data`. Defaults to the original `msg.data` whenever
     * a call is not performed by the trusted forwarder or the calldata length is less than
     * 20 bytes (an address length).
     */
    function _msgData() internal view returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return msg.data;
        }
    }
}