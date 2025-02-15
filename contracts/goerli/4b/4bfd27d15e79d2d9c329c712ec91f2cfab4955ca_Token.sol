/**
 *Submitted for verification at Etherscan.io on 2022-08-25
*/

pragma solidity^0.8.7;
//SPDX-License-Identifier: MIT

contract Token{
    string public name; //= "Jodge Coin";
    string public symbol; //= "JC";
    uint public decimals; //= 18;
    uint public totalSupply; //= 69420;

    //Keeping track of balances and allowances that are approved.
    mapping(address=>uint) public balanceOf;
    mapping(address=>mapping(address=>uint256)) public allowance;

    //Events
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);

    constructor(string memory _name, string memory _symbol, uint _decimals, uint _totalSupply){
        name= _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address _to, uint _value) external returns (bool success){
        require(balanceOf[msg.sender] >= _value);
        _transfer(msg.sender, _to, _value);
        return true;
    }
    function _transfer(address _from, address _to, uint _value) internal{
        require(_to != address(0));
        //changed from to msg.sender
        balanceOf[_from]= balanceOf[_from] - (_value);
        balanceOf[_to] = balanceOf[_to] +(_value);
        emit Transfer(_from, _to, _value);
    }

    function approve(address _spender, uint _value) external returns(bool){
        require(_spender != address(0));
        allowance[msg.sender][_spender]=_value;
        emit Approval (msg.sender, _spender, _value);
        return true;
    }
    function transferFrom(address _from, address _to, uint _value) external returns(bool){
        require(_value <= balanceOf[_from]);
        require(_value <= allowance[_from][msg.sender]);
        allowance[_from][msg.sender]= allowance[_from][msg.sender]-(_value);
        _transfer(_from, _to, _value);
        return true;
    }
   
}