// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

contract BoxV2 {
    uint public val;

    // function initialize(uint _val) external {
    //     val = _val;
    // }

    function inc() external {
        val += 1;
    }
}