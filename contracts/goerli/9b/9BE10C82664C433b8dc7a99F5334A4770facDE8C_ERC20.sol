/**
 *Submitted for verification at Etherscan.io on 2022-11-26
*/

// SPDX-License-Identifier: GPL-3.0
 
pragma solidity 0.8.15;
 
interface IERC20 {

    // событие трансфера
    event Transfer(address indexed from, address indexed to, uint256 value);
    // событие изменения значения словаря разрешений
    event Approval(address indexed owner, address indexed spender, uint256 value);
    // возвращает имя токена
    function name() external view returns (string memory);
    // возвращает символ токена
    function symbol() external view returns (string memory);
    // возвращает количество нулей токена
    function decimals() external view returns (uint8);
    // возвращает общую эмиссию токена
    function totalSupply() external view returns (uint256);
    // возвращает баланс аккаунта по его адресу токена
    function balanceOf(address account) external view returns (uint256);
    // возвращает количество токенов, которые spender может тратить с адреса owner
    function allowance(address owner, address spender) external view returns (uint256);
    // выдача адресу spender разрешения тратить amount токенов с адреса msg.sender
    function approve(address spender, uint256 amount) external returns (bool);
    // отправка amount токенов на адрес to с адреса msg.sender
    function transfer(address to, uint256 amount) external returns (bool);
    // отправка amount токенов на адрес to с адреса from
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract ERC20 is IERC20{
    uint256 _totalSupply = 0;
    address _owner;
    string _name;
    string _symbol;
    uint8 _decimals;

    mapping(address => uint256) balances;

    mapping(address => mapping(address => uint256)) allowed;
    
    constructor(uint8 _d, string memory _n, string memory _s) payable {
        _owner = msg.sender;
        _name = _n;
        _symbol = _s;
        _decimals = _d;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account)public view returns(uint256) {
        return balances[account];
    }

    function allowance(address owner, address spender) public view returns(uint256) {
        return allowed[owner][spender];
    }

    // Функция эмиссии
    // to - на какой адрес 
    // value - сколько зачислить токенов
    function mint(address to, uint amount) public {
        require(_owner == msg.sender, "ERC20: You are not owner");
        _totalSupply += amount;
        balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }
 
    function approve(address spender, uint256 amount) public returns(bool) {
        allowed[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint amount)public returns(bool) {
        require(balances[msg.sender] >= amount, "ERC20: not enough tokens");
        balances[msg.sender] -= amount;
        balances[to] += amount;
        return true;
    }
 
    function transferFrom(address from, address to, uint amount)public returns(bool) {
        require(allowed[from][to] >= amount, "ERC20: no permission to spend");
        require(balances[from] >= amount, "ERC20: not enough tokens");
        balances[from] -= amount;
        balances[to] += amount;
        allowed[from][to] -= amount;
        emit Approval(from, to, amount);
        return true;
        //???????
    }
}