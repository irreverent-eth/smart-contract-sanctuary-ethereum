/**
 *Submitted for verification at Etherscan.io on 2022-08-28
*/

// SPDX-License-Identifier: MIT

// Create a cryptocurrency
// Store it in wallet
// List it on decentralised exchange

pragma solidity  ^0.8.6;

contract Token {
    string public name; // name of cryptocurrency
    string public symbol; // symbol of cryptocurrency
    uint256 public decimals;
    uint256 public totalSupply;

    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    event transfer(address indexed from, address indexed to, uint256 value);
    event approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint256  _decimals, uint256 _totalSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = totalSupply;
    }

    function internalTransfer(address _from, address _to, uint256 _value) internal {

        require(_to != address(0));
        balanceOf[_from] = balanceOf[_from] - (_value);
        balanceOf[_to] = balanceOf[_to] + (_value);
        emit transfer(_from, _to, _value);

    }  

    function Transfer(address _to, uint256 _value) external returns (bool success) {
        require(balanceOf[msg.sender] >= _value);
        internalTransfer(msg.sender, _to, _value);
        return true;

    }

    function approve(address _spender, uint256 _value) external returns (bool){
        require(_spender != address(0));

        allowance[msg.sender][_spender] = _value;
        emit approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool){
        require(balanceOf[_from] >= _value);
        require(allowance[_from][msg.sender] >= _value);
        allowance[_from][msg.sender] = allowance[_from][msg.sender] - (_value);
        internalTransfer(_from, _to, _value);
        return true;
    }

}