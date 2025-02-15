// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './SimpleStorage.sol';

// Goerli: 0x8359c7F6D829C72951694F5a1B248dA742c5D079

contract StorageFactory {
    SimpleStorage[] public simpleStorageArray; // array of deployed SimpleStorage contracts

    // deploy
    function createSimpleStorageContract() public {
        SimpleStorage simpleStorage = new SimpleStorage(); // deploys SimpleStorage contract and returns deployed address
        simpleStorageArray.push(simpleStorage);
    }

    // interact - ABI, address
    function sfStore(uint256 _simpleStorageIndex, uint256 _simpleStorageNum) public {
        SimpleStorage simpleStorage = simpleStorageArray[_simpleStorageIndex]; // 
        simpleStorage.store(_simpleStorageNum); // calls store func from Simple Storage
    }

    function sfGet(uint256 _simpleStorageIndex) public view returns(uint256) {
        SimpleStorage simpleStorage = simpleStorageArray[_simpleStorageIndex]; 
        return simpleStorage.retrieve();
    }


}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// Goerli: 0x00F16999832806Bcd68dFAB7108FF9515216AA07

contract SimpleStorage {
    // types: bool, uint, int, address

    // bool isFavNum = true;
    // uint8 favNum = 255; // 8 bits > 2 ^ 8 uints
    // int8 otherFavNum = -20;
    // address myAddr = 0xE6Df4B432E3f690B787e1e91f41aB531aA05238d;

    // string, bytes

    // string public favNumStr = 'five'; 
    // bytes32 public favNumber = 'five'; //  stores it in hex val
    
    uint256 favNum;
    
    // struct
    struct People {
        uint256 favNumber;
        string name;
    }
    // People public person = People(2, 'Ari'); // instance of struct

    // array
    People[] public person; // dynamic arr

    // mapping
    mapping(string => uint256) public nameToFavNum;

    function store(uint256 _favNum) public virtual { // virtual for overriding
        // costs gas coz changing state
        favNum = _favNum;
    }

    // view, pure
    // view - views state var - no gas
    // pure - can't even view state var - no gas
    function retrieve() public view returns(uint256) { 
        // doesn't cost gas / can cost gas when called by a function costing gas
        return favNum;
    }

    // storage, memory, calldata
    // arrays, mappings, struct - memory is needed explicitly
    // memory - temp var that can be changed
    // calldata - temp var that can be changed

    function addPerson(string memory _name, uint256 _favNumber) public { 
        person.push(People(_favNumber, _name)); // adds to array
        nameToFavNum[_name] = _favNumber; // adds mapping
    }

}