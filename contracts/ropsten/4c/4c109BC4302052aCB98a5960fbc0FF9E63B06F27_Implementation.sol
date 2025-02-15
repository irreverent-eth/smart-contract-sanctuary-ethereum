// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0 < 0.9.0;

contract Implementation {
    uint public x;
    bool public isBase;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "ERROR: Only Owner");
        _;
    }

    constructor() {
        isBase = true;
    }

    function initialize(address _owner) external {
        require(isBase == false, "ERROR: This is the base contract, cannot initialize");
        require(owner == address(0), "ERROR: Contract already initialized");
        owner = _owner;
    }

    function setX(uint _newX) external onlyOwner {
        x = _newX;
    }
}