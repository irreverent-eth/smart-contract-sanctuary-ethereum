// contracts/ProjectFactoryV2.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ProjectFactory.sol";

contract ProjectFactoryV2 is ProjectFactory {
    // Increments the stored value by 1
    function increment() public {
        store(retrieve() + 1);
    }
}

// contracts/ProjectFactory.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ProjectFactory {
    uint256 private value;

    // Emitted when the stored value changes
    event ValueChanged(uint256 newValue);

    // Stores a new value in the contract
    function store(uint256 newValue) public {
        value = newValue;
        emit ValueChanged(newValue);
    }

    // Reads the last stored value
    function retrieve() public view returns (uint256) {
        return value;
    }
}