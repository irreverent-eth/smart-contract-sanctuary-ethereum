/**
 *Submitted for verification at Etherscan.io on 2022-09-22
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.8.2;

contract C {
    
    function add(uint a, uint b) public view returns(uint) {
        return a + b;
    }

    function sub(int a, int b) public view returns(int) {
        return a - b;
    }

    function mult(uint a, uint b) public view returns(uint) {
        return a * b;
    }

    function div(uint a, uint b) public view returns(uint, uint) {
            return (a / b, a % b);
    }
}