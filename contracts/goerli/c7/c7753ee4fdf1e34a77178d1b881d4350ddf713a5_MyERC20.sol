/**
 *Submitted for verification at Etherscan.io on 2022-10-17
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract ERC20_STD {
    function name() public view virtual returns (string memory);
    function symbol() public view virtual returns (string memory);
    function decimals() public view virtual returns (uint8);
    function totalSupply() public view virtual returns (uint256);
    function balanceOf(address _owner) public view virtual returns (uint256 balance);
    function transfer(address _to, uint256 _value) public virtual returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public virtual returns (bool success);
    function approve(address _spender, uint256 _value) public virtual returns (bool success);
    function allowance(address _owner, address _spender) public view virtual returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract Ownership {
    address public newOwner;
    address public contractOwner;

    event TransferOwnership(address indexed _from,address indexed _to);

    constructor() {
        contractOwner = msg.sender;
    }

    function changeOwner(address _to)public {
        require(msg.sender == contractOwner,'only owner of contract can execute');
        newOwner = _to;
    }

    function acceptOwner() public {
        require(msg.sender == newOwner,'only new owner of contract can  execute it');
        emit TransferOwnership(contractOwner,newOwner);
        contractOwner = newOwner;
        newOwner = address(0);
    }
}

contract MyERC20 is ERC20_STD,Ownership{
     string public _name;
     string public _symbol;
     uint8 public _decimals;
     uint256 public _totalSupply;

     mapping(address=>uint256) tokenBalances;

     mapping(address=>mapping(address=>uint256)) allowed;

     constructor (){
        _name = 'SkillSch Coin';
        _symbol = 'SKC';
        _totalSupply = 10000000;
        _decimals = 18;
        tokenBalances[msg.sender] = _totalSupply;
     }



    function name() public view override returns (string memory){
        return _name; 
    }

    function symbol() public view  override returns (string memory){
        return _symbol;
    }

    function decimals() public view override returns (uint8){
        return _decimals;
    }

    function totalSupply() public view override returns (uint256){
        return _totalSupply;
    }

     function balanceOf(address _owner) public view override returns (uint256 balance){
        return tokenBalances[_owner];

     }

    function transfer(address _to, uint256 _value) public override returns (bool success){
        require (tokenBalances[msg.sender] >= _value,'Insufficient balances');
        tokenBalances[msg.sender] -= _value;
        tokenBalances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool success){
        uint256 allowedBal  = allowed[_from][msg.sender];
        require (allowedBal >= _value,'Insufficient balances');
        tokenBalances[msg.sender] -= _value;
        tokenBalances[_to] += _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public override returns (bool success){
        require (tokenBalances[msg.sender] >= _value,'Insufficient Token');
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view override returns (uint256 remaining){
        return allowed[_owner][_spender];
    }
    
}