/**
 *Submitted for verification at Etherscan.io on 2022-11-04
*/

// SPDX-License-Identifier: MIT
// specify the version of complier
pragma solidity ^0.8.0; 

// define our own contract
contract MyToken {
  // total supply of token
  uint256 constant supply = 1000000;

  // event to be emitted on transfer
  // first/second variable: which account we transfer the token from/to; third variable: amount of transfer
  event Transfer(address indexed _from, address indexed _to, uint256 _value);

  // event to be emitted on approval
  event Approval(
    address indexed _owner,
    address indexed _spender,
    uint256 _value
  );

  // TODO: create mapping for balances
  mapping(address => uint) public balances;

  // TODO: create mapping for allowances
  // allowances: allow people to use the balances
  mapping(address=> mapping(address => uint256)) public allowances;

  constructor() {
    // TODO: set sender's balance to total supply
    // the sender gets a supply of 100,0000
    balances[msg.sender] = supply;
  }

  function totalSupply() public pure returns (uint256) {
    // TODO: return total supply
    return supply;
  }

  function balanceOf(address _owner) public view returns (uint256) {
    // TODO: return the balance of _owner
    return balances[_owner];
  }

  function transfer(address _to, uint256 _value) public returns (bool) {
    // TODO: transfer `_value` tokens from sender to `_to`
    // NOTE: sender needs to have enough tokens
    // sender's money is deducted and the receiver's money is added
    require(balances[msg.sender] >= _value);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    emit Transfer(msg.sender,_to,_value);
    return true;
  }

  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  ) public returns (bool) {
    // TODO: transfer `_value` tokens from `_from` to `_to`
    // NOTE: `_from` needs to have enough tokens and to have allowed sender to spend on his behalf
    require(balances[_from] >= _value);
    require(allowances[_from][msg.sender] >=_value);
    balances[_from] -= _value;
    balances[_to] += _value;
    allowances[_from][msg.sender] -= _value;
    emit Transfer(_from,_to,_value);
    return true;
  }

  function approve(address _spender, uint256 _value) public returns (bool) {
    // TODO: allow `_spender` to spend `_value` on sender's behalf
    // NOTE: if an allowance already exists, it should be overwritten
    allowances[msg.sender][_spender] = _value;

    // create an event lock on the cntract
    emit Approval(msg.sender,_spender,_value);
    return true;
  }

  function allowance(address _owner, address _spender)
    public
    view
    returns (uint256 remaining)
  {
    // TODO: return how much `_spender` is allowed to spend on behalf of `_owner`
    // capture how much can the sender can spend 
    return allowances[_owner][_spender];
  }
}