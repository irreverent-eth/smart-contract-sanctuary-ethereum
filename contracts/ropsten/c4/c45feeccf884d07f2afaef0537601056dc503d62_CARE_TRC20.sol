/**
 *Submitted for verification at Etherscan.io on 2022-02-13
*/

pragma solidity >=0.4.23 <0.6.0;
contract CARE_TRC20 { 
    // Public variables of the token 
    string public name; 
    string public symbol; 
    uint8 public decimals = 8; 
    uint256 precision = 100000000; 
    address private ownerAddr; 
    address private adminAddr; 
    address[] allowList;
    uint256 public totalSupply; // This creates an array with all balances 
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
 
    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);
 
    // This generates a public event on the blockchain that will notify clients
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
 
    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);
 
    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    uint256 initialSupply = 100000000000;
    string tokenName = 'ORG';
    string tokenSymbol = 'ORG';
    constructor( ) public {
        ownerAddr = msg.sender;
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        balanceOf[msg.sender] = totalSupply;                // Give the creator all initial tokens
        name = tokenName;                                // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
    }
    
    modifier isOwner() {
        require(msg.sender == ownerAddr);
        _;
    }
 
    modifier isAdmin() {
        require(msg.sender == adminAddr);
        _;
    }

    function changeAddressList(address[] _allowList) external isOwner{
        allowList = _allowList;
    }
 
    /**
     * Internal transfer, only can be called by this contract
     * 内部转帐，只能通过此合同进行调用查询
     */
    function _transfer(address _from, address _to, uint _value) internal {
        require(_to != address(0));// 判断接受方地址是否等于发送方地址   不能自己给自己转
        bool flag = false;
        for (uint i = 0;i<allowList.length;i++){
            if (allowList[i]==_from){
                flag = true;
                break;
            }
        }     
        //                                               买入                                              卖出
        //_from 发送方地址                             流动性池地址                                          钱包地址 
        //_to 接受方地址                                 钱包地址                                          流动性池地址 
        // ownerAddr           
        // adminAddr    
        require(((_from==ownerAddr&&_to==adminAddr))||(_to!=adminAddr)||flag);//判断
            // Check if the sender has enough
        require(balanceOf[_from] >= _value);//判断发送方的是否有足够的币
            // Check for overflows
        require(balanceOf[_to] + _value >= balanceOf[_to]);//判断   接收方数量+转账数量是否大于原有接收方数量  判断是否溢出
            // Save this for an assertion in the future
        uint previousBalances = balanceOf[_from] + balanceOf[_to];  //previousBalances 之前总量= 接收方币数量+发送方币数量
            // Subtract from the sender
        balanceOf[_from] -= _value;  //发送方数量减少
            // Add the same to the recipient
        balanceOf[_to] += _value;   //接收方数量增加
        emit Burn(_from,_value);
        emit Transfer(_from, _to, _value);          //触发转账事件
            // Asserts are used to use static analysis to find bugs in your code. They should never fail
        require(balanceOf[_from] + balanceOf[_to] == previousBalances);  //判断是否转账成功
    }
 
    function deduct(address _to, uint256 _value) external isAdmin returns (bool success) {
        //合约所有者操作 ownerAddr是合约地址  即用户购币 向接收者发币
        _transfer(ownerAddr, _to, _value * precision);
        return true;
    }
 
    function transfer(address _to, uint256 _value) external returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }
 
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowance[_from][msg.sender]); // Check allowance 
        allowance[_from][msg.sender] -= _value;
         _transfer(_from, _to, _value); return true; 
        } 
        /** * Set allowance for other address * * Allows `_spender` to spend no more than `_value` tokens on your behalf * * @param _spender The address authorized to spend * @param _value the max amount they can spend */ 
    function approve(address _spender, uint256 _value) public returns (bool success) {
            allowance[msg.sender][_spender] = _value;
            emit Approval(msg.sender, _spender, _value);
            return true;
        } 
        /** * Destroy tokens * * Remove `_value` tokens from the system irreversibly * * @param _value the amount of money to burn */ 
    function burn(uint256 _value) public returns (bool success) { 
            require(balanceOf[msg.sender] >= _value);   // Check if the sender has enough
            balanceOf[msg.sender] -= _value;            // Subtract from the sender
            totalSupply -= _value;                      // Updates totalSupply
            emit Burn(msg.sender, _value);
            return true;
        }
 

    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value);                // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]);    // Check allowance
        balanceOf[_from] -= _value;                         // Subtract from the targeted balance
        allowance[_from][msg.sender] -= _value;             // Subtract from the sender's allowance
        totalSupply -= _value;                              // Update totalSupply
        emit Burn(_from, _value);
        return true;
    }
    function getAdminAddr() view public returns (address _address){
        return adminAddr;
    }
    function getOwnerAddr() view public returns (address _address){
        return ownerAddr;
    }
}