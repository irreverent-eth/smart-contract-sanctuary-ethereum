/**
 *Submitted for verification at Etherscan.io on 2022-11-18
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.7; // ^0.8.8 - use any version higher than specified //// >=0.8.8 <0.9 use between

contract SimpleStorage {
  uint256 favoriteNumber;

  mapping(string => uint256) public nameToFavoriteNumber;

  struct People {
    uint256 favoriteNumber;
    string name;
  }

  //uint256[] public favoriteNumbersList;
  People[] public people;

  function store(uint256 _favoriteNumber) public virtual {
    favoriteNumber = _favoriteNumber;
  }

  function retrieve() public view returns (uint256) {
    return favoriteNumber;
  }

  function addPerson(string memory _name, uint256 _favoriteNumber) public {
    People memory newPerson = People({
      favoriteNumber: _favoriteNumber,
      name: _name
    });
    people.push(newPerson);

    nameToFavoriteNumber[_name] = _favoriteNumber;
  }
}