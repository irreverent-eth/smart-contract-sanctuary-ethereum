/**
 *Submitted for verification at Etherscan.io on 2022-08-31
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bank{
    mapping (address => uint) _balances;
    uint _totalSupply;

    function deposit () public payable {
        _balances[msg.sender] += msg.value;
        _totalSupply += msg.value;
    }

    function withdraw(uint amount) public payable {
        // ที่ต้อง require เพราะเงินที่ถอนเป็นของ sm (กองกลาง)
        require (amount <= _balances[msg.sender],"not enough money ");
        payable(msg.sender).transfer(amount);
        _balances[msg.sender] -= amount;
        _totalSupply -= amount;

    }

    function checkBalance ()public view returns (uint balance){
        return  _balances[msg.sender];
    }
    function checkTotalSupply() public view returns (uint totallSupply){
        return _totalSupply;
    }
}

// payable ใช้กับ msg.value