// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {Ownable} from "../facets/access/ownable/Ownable.sol";
import {OwnableStorage} from "../facets/access/ownable/OwnableStorage.sol";
import {IERC173} from "../facets/access/ownable/IERC173.sol";
import {ERC165, IERC165, ERC165Storage} from "../facets/introspection/ERC165.sol";
import {DiamondCut, IDiamondCut} from "../facets/diamond/DiamondCut.sol";
import {DiamondLoupe, IDiamondLoupe} from "../facets/diamond/DiamondLoupe.sol";

import {DiamondStorage} from "./DiamondStorage.sol";

contract DiamondInherited is Ownable, ERC165, DiamondCut, DiamondLoupe {
    using ERC165Storage for ERC165Storage.Layout;
    using OwnableStorage for OwnableStorage.Layout;

    constructor(address owner_) {
        ERC165Storage.Layout storage erc165 = ERC165Storage.layout();

        // register DiamondCut

        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = IDiamondCut.diamondCut.selector;

        erc165.setSupportedInterface(type(IDiamondCut).interfaceId, true);

        // register DiamondLoupe

        selectors[1] = IDiamondLoupe.facets.selector;
        selectors[2] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[3] = IDiamondLoupe.facetAddresses.selector;
        selectors[4] = IDiamondLoupe.facetAddress.selector;

        erc165.setSupportedInterface(type(IDiamondLoupe).interfaceId, true);

        // register ERC173 (Ownable)

        selectors[5] = IERC173.owner.selector;
        selectors[6] = IERC173.transferOwnership.selector;

        erc165.setSupportedInterface(type(IERC173).interfaceId, true);

        // register ERC165 (supportsInterface)

        selectors[7] = IERC165.supportsInterface.selector;

        erc165.setSupportedInterface(type(IERC165).interfaceId, true);

        // execute the first ever diamond cut

        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);

        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(this),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        DiamondStorage.diamondCut(facetCuts, address(0), "");

        // set owner

        OwnableStorage.layout().setOwner(owner_);
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        DiamondStorage.Layout storage l;
        bytes32 position = DiamondStorage.DIAMOND_STORAGE_POSITION;
        // get diamond storage
        assembly {
            l.slot := position
        }

        // get facet from function selector
        address facet = l.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "BAD_FUNC");

        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

import {IDiamondCut} from "../facets/diamond/IDiamondCut.sol";

// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

library DiamondStorage {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    struct Layout {
        // maps function selector to the facet address and
        // the position of the selector in the facetFunctionSelectors.selectors array
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // facet addresses
        address[] facetAddresses;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }

    event DiamondCut(
        IDiamondCut.FacetCut[] _diamondCut,
        address _init,
        bytes _calldata
    );

    // Internal function version of diamondCut
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (
            uint256 facetIndex;
            facetIndex < _diamondCut.length;
            facetIndex++
        ) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else {
                revert("LibDiamondCut: Incorrect FacetCutAction");
            }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(
            _functionSelectors.length > 0,
            "LibDiamondCut: No selectors in facet to cut"
        );
        Layout storage l = layout();
        require(
            _facetAddress != address(0),
            "LibDiamondCut: Add facet can't be address(0)"
        );
        uint96 selectorPosition = uint96(
            l.facetFunctionSelectors[_facetAddress].functionSelectors.length
        );
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(l, _facetAddress);
        }
        for (
            uint256 selectorIndex;
            selectorIndex < _functionSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = l
                .selectorToFacetAndPosition[selector]
                .facetAddress;
            require(
                oldFacetAddress == address(0),
                "LibDiamondCut: Can't add function that already exists"
            );
            addFunction(l, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function replaceFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(
            _functionSelectors.length > 0,
            "LibDiamondCut: No selectors in facet to cut"
        );
        Layout storage l = layout();
        require(
            _facetAddress != address(0),
            "LibDiamondCut: Add facet can't be address(0)"
        );
        uint96 selectorPosition = uint96(
            l.facetFunctionSelectors[_facetAddress].functionSelectors.length
        );
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(l, _facetAddress);
        }
        for (
            uint256 selectorIndex;
            selectorIndex < _functionSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = l
                .selectorToFacetAndPosition[selector]
                .facetAddress;
            require(
                oldFacetAddress != _facetAddress,
                "LibDiamondCut: Can't replace function with same function"
            );
            removeFunction(l, oldFacetAddress, selector);
            addFunction(l, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function removeFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(
            _functionSelectors.length > 0,
            "LibDiamondCut: No selectors in facet to cut"
        );
        Layout storage l = layout();
        // if function does not exist then do nothing and return
        require(
            _facetAddress == address(0),
            "LibDiamondCut: Remove facet address must be address(0)"
        );
        for (
            uint256 selectorIndex;
            selectorIndex < _functionSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = l
                .selectorToFacetAndPosition[selector]
                .facetAddress;
            removeFunction(l, oldFacetAddress, selector);
        }
    }

    function addFacet(Layout storage l, address _facetAddress) internal {
        // enforceHasContractCode(
        //     _facetAddress,
        //     "LibDiamondCut: New facet has no code"
        // );
        l.facetFunctionSelectors[_facetAddress].facetAddressPosition = l
            .facetAddresses
            .length;
        l.facetAddresses.push(_facetAddress);
    }

    function addFunction(
        Layout storage l,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _facetAddress
    ) internal {
        l
            .selectorToFacetAndPosition[_selector]
            .functionSelectorPosition = _selectorPosition;
        l.facetFunctionSelectors[_facetAddress].functionSelectors.push(
            _selector
        );
        l.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(
        Layout storage l,
        address _facetAddress,
        bytes4 _selector
    ) internal {
        require(
            _facetAddress != address(0),
            "LibDiamondCut: Can't remove function that doesn't exist"
        );
        // an immutable function is a function defined directly in a diamond
        require(
            _facetAddress != address(this),
            "LibDiamondCut: Can't remove immutable function"
        );
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = l
            .selectorToFacetAndPosition[_selector]
            .functionSelectorPosition;
        uint256 lastSelectorPosition = l
            .facetFunctionSelectors[_facetAddress]
            .functionSelectors
            .length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = l
                .facetFunctionSelectors[_facetAddress]
                .functionSelectors[lastSelectorPosition];
            l.facetFunctionSelectors[_facetAddress].functionSelectors[
                    selectorPosition
                ] = lastSelector;
            l
                .selectorToFacetAndPosition[lastSelector]
                .functionSelectorPosition = uint96(selectorPosition);
        }
        // delete the last selector
        l.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete l.selectorToFacetAndPosition[_selector];

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = l.facetAddresses.length - 1;
            uint256 facetAddressPosition = l
                .facetFunctionSelectors[_facetAddress]
                .facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = l.facetAddresses[
                    lastFacetAddressPosition
                ];
                l.facetAddresses[facetAddressPosition] = lastFacetAddress;
                l
                    .facetFunctionSelectors[lastFacetAddress]
                    .facetAddressPosition = facetAddressPosition;
            }
            l.facetAddresses.pop();
            delete l.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata)
        internal
    {
        if (_init == address(0)) {
            require(
                _calldata.length == 0,
                "LibDiamondCut: _init is address(0) but_calldata is not empty"
            );
        } else {
            require(
                _calldata.length > 0,
                "LibDiamondCut: _calldata is empty but _init is not address(0)"
            );
            // if (_init != address(this)) {
            //     enforceHasContractCode(
            //         _init,
            //         "LibDiamondCut: _init address has no code"
            //     );
            // }
            (bool success, bytes memory error) = _init.delegatecall(_calldata);
            if (!success) {
                if (error.length > 0) {
                    // bubble up the error
                    revert(string(error));
                } else {
                    revert("LibDiamondCut: _init function reverted");
                }
            }
        }
    }

    // function enforceHasContractCode(
    //     address _contract,
    //     string memory _errorMessage
    // ) internal view {
    //     uint256 contractSize;
    //     assembly {
    //         contractSize := extcodesize(_contract)
    //     }
    //     require(contractSize > 0, _errorMessage);
    // }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {IERC173Event} from "./IERC173Event.sol";

/**
 * @title Contract ownership standard interface
 * @dev see https://eips.ethereum.org/EIPS/eip-173
 */
interface IERC173 is IERC173Event {
    /**
     * @notice get the ERC173 contract owner
     * @return conrtact owner
     */
    function owner() external view returns (address);

    /**
     * @notice transfer contract ownership to new account
     * @param account address of new owner
     */
    function transferOwnership(address account) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

/**
 * @title Contract ownership standard interface (event only)
 * @dev see https://eips.ethereum.org/EIPS/eip-173
 */
interface IERC173Event {
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {IERC173} from "./IERC173.sol";
import {OwnableInternal} from "./OwnableInternal.sol";

/**
 * @title Ownership access control based on ERC173
 */
contract Ownable is IERC173, OwnableInternal {
    /**
     * @inheritdoc IERC173
     */
    function owner() public view virtual returns (address) {
        return _owner();
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @inheritdoc IERC173
     */
    function transferOwnership(address account) public virtual onlyOwner {
        _transferOwnership(account);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {OwnableStorage} from "./OwnableStorage.sol";
import {IERC173Event} from "./IERC173Event.sol";

abstract contract OwnableInternal is IERC173Event {
    using OwnableStorage for OwnableStorage.Layout;

    modifier onlyOwner() {
        require(msg.sender == _owner(), "Ownable: sender must be owner");
        _;
    }

    function _owner() internal view virtual returns (address) {
        return OwnableStorage.layout().owner;
    }

    function _transferOwnership(address account) internal virtual {
        OwnableStorage.layout().setOwner(account);
        emit OwnershipTransferred(msg.sender, account);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

library OwnableStorage {
    struct Layout {
        address owner;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("openzeppelin.contracts.storage.Ownable");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function setOwner(Layout storage l, address owner) internal {
        l.owner = owner;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

import {IDiamondCut} from "./IDiamondCut.sol";
import {DiamondStorage} from "../../core/DiamondStorage.sol";
import {OwnableInternal} from "../access/ownable/OwnableInternal.sol";

// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

contract DiamondCut is IDiamondCut, OwnableInternal {
    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override onlyOwner {
        DiamondStorage.diamondCut(_diamondCut, _init, _calldata);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {DiamondStorage} from "../../core/DiamondStorage.sol";
import {IDiamondLoupe} from "./IDiamondLoupe.sol";

// The functions in DiamondLoupe MUST be added to a diamond.
// The EIP-2535 Diamond standard requires these functions.

contract DiamondLoupe is IDiamondLoupe {
    /// @notice Gets all facets and their selectors.
    /// @return facets_ Facet
    function facets() external view override returns (Facet[] memory facets_) {
        DiamondStorage.Layout storage l = DiamondStorage.layout();
        uint256 numFacets = l.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = l.facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = l
                .facetFunctionSelectors[facetAddress_]
                .functionSelectors;
        }
    }

    /// @notice Gets all the function selectors provided by a facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet)
        external
        view
        override
        returns (bytes4[] memory facetFunctionSelectors_)
    {
        DiamondStorage.Layout storage l = DiamondStorage.layout();
        facetFunctionSelectors_ = l
            .facetFunctionSelectors[_facet]
            .functionSelectors;
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses()
        external
        view
        override
        returns (address[] memory facetAddresses_)
    {
        DiamondStorage.Layout storage l = DiamondStorage.layout();
        facetAddresses_ = l.facetAddresses;
    }

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector)
        external
        view
        override
        returns (address facetAddress_)
    {
        DiamondStorage.Layout storage l = DiamondStorage.layout();
        facetAddress_ = l
            .selectorToFacetAndPosition[_functionSelector]
            .facetAddress;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

interface IDiamondCut {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }
    // Add=0, Replace=1, Remove=2

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

// A loupe is a small magnifying glass used to look at diamonds.
// These functions look at diamonds
interface IDiamondLoupe {
    /// These functions are expected to be called frequently
    /// by tools.

    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Gets all facet addresses and their four byte function selectors.
    /// @return facets_ Facet
    function facets() external view returns (Facet[] memory facets_);

    /// @notice Gets all the function selectors supported by a specific facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet)
        external
        view
        returns (bytes4[] memory facetFunctionSelectors_);

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses()
        external
        view
        returns (address[] memory facetAddresses_);

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector)
        external
        view
        returns (address facetAddress_);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {IERC165} from "./IERC165.sol";
import {ERC165Storage} from "./ERC165Storage.sol";

/**
 * @title ERC165 implementation
 */
contract ERC165 is IERC165 {
    using ERC165Storage for ERC165Storage.Layout;

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return ERC165Storage.layout().isSupportedInterface(interfaceId);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

library ERC165Storage {
    struct Layout {
        mapping(bytes4 => bool) supportedInterfaces;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("openzeppelin.contracts.storage.ERC165");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function isSupportedInterface(Layout storage l, bytes4 interfaceId)
        internal
        view
        returns (bool)
    {
        return l.supportedInterfaces[interfaceId];
    }

    function setSupportedInterface(
        Layout storage l,
        bytes4 interfaceId,
        bool status
    ) internal {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        l.supportedInterfaces[interfaceId] = status;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

/**
 * @title ERC165 interface registration interface
 * @dev see https://eips.ethereum.org/EIPS/eip-165
 */
interface IERC165 {
    /**
     * @notice query whether contract has registered support for given interface
     * @param interfaceId interface id
     * @return bool whether interface is supported
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}