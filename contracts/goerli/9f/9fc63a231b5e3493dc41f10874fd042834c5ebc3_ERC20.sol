// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./Math.sol";

// TODO: Auction
// TODO: Oracle for dollar prices.

// Gotchas:
// 1. money locked in contract unless you provide a payout mechanism.  
// 2. tx.origin vs msg.sender:  tx.origin gives address of initiator, msg.sender is whatever contract is interacting with this one.
// 3. Base class vs child class - who has the money?
// 4. Everything is in wei internally!  1 szabo = 10^12 wei.  1000 Gwei = 1 szabo.  1 szabo = 1 micro eth. 

// import xxxxx
// erc20 address = xxxxxx

contract ERC20 {
    
    // Basic Functionality:
    //   mint -> create new token from nothing
    //   buyToken, sellToken  -> interact with contract token balance
    //   send  ->  Transfer from one user to another. 
    //   ownerPayout -> Claim any ETH in contract
    //   track owner list
    //   

    // State Variables 
    address payable owner;
    string public symbol;

    address[] public sub_owners;

    address[] public hodlers;
    uint256 public hodlerCount;
    uint256 public total_tokens;
    uint256 public tokens_remaining;

    mapping(address => uint256) public balances;

   constructor()
    {
        symbol = "qiwen";
        tokens_remaining = 1000000;
        total_tokens = tokens_remaining;
        owner = payable(msg.sender);
        sub_owners.push(owner);
    }

    event MessageLog(
        string comment
    );


    // Modifiers
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier onlySubOwner(){
        bool isSubOwner = false;
        for (uint i = 0; i < sub_owners.length; i++) {
            if (sub_owners[i] == msg.sender) {
                isSubOwner = true;
                break;
            }
        }
        if (isSubOwner == false) {
            require(false);
        } else {
            require(true);
        }
        _;
    }

    // Functions
    function addOwner(address subowner) public onlySubOwner {
        sub_owners.push(subowner);
    }

    function getOwners() public view returns(address[] memory) {
        return sub_owners;
    }

    function deleteOwner(address subowner) public onlyOwner {
        require(subowner != owner);
        for (uint i = 0; i < sub_owners.length; i++) {
            if (sub_owners[i] == subowner) {
                sub_owners[i] = sub_owners[sub_owners.length - 1];
                sub_owners.pop();
                i -= 1; // since we guarantee the first subowner will always be the original owner
            }
        }
    }

    function mint(uint256 amount) public onlyOwner {
        total_tokens += amount;
        tokens_remaining += amount;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function ownerPayout() public payable onlyOwner {

        owner.transfer( getBalance() );
    }

    function compute_token_value() public pure virtual returns(uint256)
    {
        return 1000000000000;
    }

    function buyToken() public payable {
        uint256 token_value = compute_token_value();
        uint256 num_tokens = Math.divide(msg.value, token_value);

        require(num_tokens > 0);

        if (num_tokens >= tokens_remaining){
            num_tokens = tokens_remaining;
             emit MessageLog("You bought everything!");
        }

        uint256 cost = token_value * num_tokens;
        uint256 change = uint256((msg.value - cost));

        // This contract doesn't have the funds to transfer! 
        payable(msg.sender).transfer(change);

        balances[msg.sender] += num_tokens;
        tokens_remaining -= num_tokens;

        hodlerCount ++;
        hodlers.push(msg.sender);
    }


    function sellToken(uint256 num_tokens) public payable{
        uint256 token_balance = balances[msg.sender];
        require(num_tokens <= token_balance);
        require(num_tokens > 0);
        balances[msg.sender] -= num_tokens;
        tokens_remaining += num_tokens;

        payable(msg.sender).transfer(num_tokens * compute_token_value());
    }

    function send(address wallet, uint256 amount) public {
        require(amount <= balances[msg.sender]);
        balances[msg.sender] -= amount;
        balances[wallet] += amount;
        hodlerCount ++;
        hodlers.push(wallet);
    }
}