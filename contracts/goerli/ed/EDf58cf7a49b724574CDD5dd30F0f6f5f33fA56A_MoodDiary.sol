/**
 *Submitted for verification at Etherscan.io on 2022-09-09
*/

// SPDX-License-Identifier: MIT

//specify the version of solidity
pragma solidity 0.8.7;

/// a simple set and get function for mood defined: 

//define the contract
contract MoodDiary{
    
    //create a variable called mood
    string mood;
    
    //create a function that writes a mood to the smart contract
    function setMood(string memory _mood) public{
        mood = _mood;
    }
    
    //create a function the reads the mood from the smart contract
    function getMood() public view returns(string memory){
        return mood;
    }
}