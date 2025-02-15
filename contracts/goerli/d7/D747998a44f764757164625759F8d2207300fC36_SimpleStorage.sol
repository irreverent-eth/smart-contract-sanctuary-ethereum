// SPDX-License-Identifier: MIT

pragma solidity 0.8.8;

contract SimpleStorage {
    uint256 public favoriteNumber;

    struct People {
        uint256 favoriteNumber;
        string name;
    }

    People[] public people;

    mapping(string => uint256) public nameToFavoriteNumber;

    function store(uint256 _favoriteNumber) public virtual {
        favoriteNumber = _favoriteNumber;
        favoriteNumber = favoriteNumber + 1;
    }

    function retrieve() public view returns (uint256) {
        return favoriteNumber;
    }

    function addPerson(string memory _name, uint256 _favoriteNumber) public {
        People memory newPerson = People({
            favoriteNumber: _favoriteNumber,
            name: _name
        });
        //People memory newPerson = People(_favoriteNumber, _name);
        people.push(newPerson);
        nameToFavoriteNumber[_name] = _favoriteNumber;
    }
}