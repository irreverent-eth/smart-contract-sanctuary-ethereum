// contracts/Test1.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract Test2 {
  function get() external pure returns(uint a) {
      a = 2;
  }
  uint public x;
  function add() external {
    x++;
  }
}