// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ICreatorToken {
    event TransferValidatorUpdated(address oldValidator, address newValidator);
    function getTransferValidationFunction() external view returns (bytes4 functionSignature, bool isViewFunction);
    function getTransferValidator() external view returns (address validator);
    function setTransferValidator(address validator) external;
}

/// @notice ERC721 Contract extension for specific ERC721 validation transfer.
/// @author 0xkuwabatake(@0xkuwabatake)
/// @author Modified from ProjectOpenSea
/// (https://github.com/ProjectOpenSea/seadrop/blob/main/src/lib/ERC721TransferValidator.sol)
abstract contract ERC721TransferValidator is ICreatorToken {

    ///////// STORAGE /////////////////////////////////////////////////////////////////////////////O-'

    /// @dev Transfer validator address.
    address internal _transferValidator;

    ///////// PUBLIC GETTER FUNCTIONS /////////////////////////////////////////////////////////////O-'

    /// @dev Returns the currently active transfer validator.
    function getTransferValidator() public view returns (address) {
        return _transferValidator;
    }

    /// @dev Returns the transfer validation function used.
    function getTransferValidationFunction()
        public
        pure
        returns (bytes4 functionSignature, bool isViewFunction)
    {
        functionSignature = 0xcaee23ea;
        isViewFunction = true;
    }

    ///////// INTERNAL SETTER FUNCTION ////////////////////////////////////////////////////////////O-'
    
    /// @dev Sets `validator` as transfer validator.
    function _setTransferValidator(address validator) internal {
        _transferValidator = validator;
        emit TransferValidatorUpdated(_transferValidator, validator);
    }

    /// @dev Reset transfer validator back to zero address (default).
    function _resetTransferValidator() internal {
        _transferValidator = address(0);
        emit TransferValidatorUpdated(_transferValidator, address(0));
    }
}