// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

contract BoxV2 {

    uint public val;

    //will also have Box contract implementation
    // function initialize(uint _val) external {
    //     val = _val;
    // }

    function inc() external {
        val += 1;
    }
}