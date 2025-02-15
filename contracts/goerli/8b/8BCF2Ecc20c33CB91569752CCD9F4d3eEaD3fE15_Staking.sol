// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "./Token.sol";

contract Staking {

    address public owner;
    address public token;

    mapping (address => uint256) public balanceOf;
    mapping (address => uint256) public lastClaim;

    uint256 public constant blocksUntilReward = 10;

    uint256 public totalSupply;

    constructor (
        address token_
    ) {
        token = token_;
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function pendingRewards (
        address account
    )
        public
        view
        returns (uint256)
    {
        uint256 balance = balanceOf[account];
        if (balance > 0) {
            uint256 blocks = block.number - lastClaim[account];
            uint256 units = blocks / blocksUntilReward;
            uint256 rewards = balance * units;
            return rewards;
        } else {
            return 0;
        }
    }

    function claim ()
        public
    {
        uint256 rewards = pendingRewards(msg.sender);
        require(rewards > 0, "Nothing to claim");
        lastClaim[msg.sender] = block.number;
        Token(token).mint(
            msg.sender,
            rewards
        );
    }

    function deposit (
        uint256 amount
    )
        public
    {
        if (pendingRewards(msg.sender) > 0) {
            claim();
        }
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        Token(token).transferFrom (
            msg.sender,
            address(this),
            amount
        );
    }

    function withdraw (
        uint256 amount
    )
        public
    {
        if (pendingRewards(msg.sender) > 0) {
            claim();
        }
        require(amount <= balanceOf[msg.sender], "Amount exceeds balance");
        balanceOf[msg.sender] -= amount;
        Token(token).transfer (
            msg.sender,
            amount
        );
    }

}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

contract Token {

    event Transfer(address from, address to, uint256 amount);

    string public name;
    string public symbol;

    uint256 public totalSupply;
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    mapping (address => bool) isMinter;

    address public owner;

    constructor (
        string memory name_,
        string memory symbol_
    ) {
        name = name_;
        symbol = symbol_;
        owner = msg.sender;
        isMinter[owner] = true;
    }

    modifier onlyOwner {
        require (msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyMinter {
        require (isMinter[msg.sender], "Only minter");
        _;
    }

    function _transfer (
        address from,
        address to,
        uint256 amount
    )
        private
    {
        if (from == address(0)) {
            balanceOf[to] += amount;     
        } else if (to == address(0)) {
            balanceOf[from] -= amount;
        } else {
            balanceOf[from] -= amount;
            balanceOf[to] += amount; 
        }
        emit Transfer(from, to, amount);
    }

    function transfer (
        address to,
        uint256 amount
    )
        public
    {
        _transfer (
            msg.sender,
            to,
            amount
        );
    }

    function transferFrom (
        address from,
        address to,
        uint256 amount
    )
        public
    {
        require (allowance[from][msg.sender] >= amount, "Amount exceeds allowance");
        _transfer (
            from,
            to,
            amount
        );
    }

    function mint (
        address account,
        uint256 amount
    )
        public
        onlyMinter
    {
        totalSupply += amount;
        _transfer(address(0), account, amount);
    }

    function burn (
        uint256 amount
    )
        public
    {
        totalSupply -= amount;
        _transfer(msg.sender, address(0), amount);
    }

    function approve (
        address account,
        uint256 amount
    )
        public
    {
        allowance[msg.sender][account] += amount;
    }

    function grantMinterRole (
        address account
    )
        public
        onlyOwner
    {
        isMinter[account] = true;
    }
}