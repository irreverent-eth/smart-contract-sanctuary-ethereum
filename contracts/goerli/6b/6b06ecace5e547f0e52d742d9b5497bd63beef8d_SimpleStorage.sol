/**
 *Submitted for verification at Etherscan.io on 2022-11-28
*/

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract SimpleStorage {
  uint storedData;

  function set(uint x) public {
    storedData = x;
  }

  function get() public view returns (uint) {
    return storedData;
  }
}