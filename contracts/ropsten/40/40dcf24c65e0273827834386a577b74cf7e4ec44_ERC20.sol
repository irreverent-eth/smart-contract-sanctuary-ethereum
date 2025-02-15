/**
 *Submitted for verification at Etherscan.io on 2022-08-15
*/

/*
Implements EIP20 token standard: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
.*/

pragma solidity ^0.5.0;


contract ERC20 {

    uint256 constant private MAX_UINT256 = 2**256 - 1; //the maximum integer value
    mapping (address => uint256) private balances;     //the token balance of all the users of this contract
    mapping (address => mapping (address => uint256)) private allowed; //the amount of tokens that can be taken the owner (first address) by the second address (spender)
    string public name;                                //name of the token
    uint8 public decimals;                             //How many decimals to show for this token
    string public symbol;                              //This token's identifier
    uint256 public totalSupply;                        //all the tokens the smart contract contains
    
    event Transfer(address indexed _from, address indexed _to, uint256 _value);   //to be fired when a transfer of tokens occurs
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);  //to be fired when an owner approvers a new spender 

    constructor(uint256 _initialAmount, string memory _tokenName, uint8 _decimalUnits, string memory _tokenSymbol) public {
        balances[msg.sender] = _initialAmount;          // Give the creator all initial tokens
        totalSupply = _initialAmount;                   // Update total supply
        name = _tokenName;                              // Set the name for display purposes
        decimals = _decimalUnits;                       // Amount of decimals for display purposes
        symbol = _tokenSymbol;                          // Set the symbol for display purposes
    }
    
    /** 
    * @param _owner The address from which the balance will be retrieved
    * @return The balance
    */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    /**
    * @notice send `_value` number of tokens to `_to` from `msg.sender`
    * @param _to The address of the recipient
    * @param _value The amount of token to be transferred
    * @return Whether the transfer was successful or not
    */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
    	emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /** 
    * @notice `msg.sender` approves `_spender` to spend `_value` number of tokens
    * @param _spender The address of the account able to transfer the tokens
    * @param _value The amount of tokens to be approved for transfer
    * @return Whether the approval was successful or not
    */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value); 
        return true;
    }

    /**
    * @param _owner The address of the account owning tokens
    * @param _spender The address of the account able to transfer the tokens
    * @return Amount of remaining tokens allowed to spent
    */
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    /**
    * @notice send `_value` number of tokens to `_to` from `_from` on the condition it is approved by `_from`
    * @param _from The address of the sender
    * @param _to The address of the recipient
    * @param _value The amount of token to be transferred
    * @return Whether the transfer was successful or not
    */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        uint256 availableAllowance = allowed[_from][msg.sender];
        require(balances[_from] >= _value && availableAllowance >= _value);
        balances[_to] += _value;
        balances[_from] -= _value;
        if (availableAllowance < MAX_UINT256) {
            allowed[_from][msg.sender] -= _value;
        }
        emit Transfer(_from, _to, _value); 
        return true;
    }
}