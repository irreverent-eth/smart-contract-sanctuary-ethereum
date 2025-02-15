//  SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

/**
 * @title Bank
 * @dev Deposit and withdray Eth
 */
contract Bank {
    /// @dev store the amount of deposited Eth per user. Uses units of wei
    mapping(address => uint256) public balanceSheet;
    address deployer = address(0x2548a975EE9Fd4242043Afa9C07D882243302B57);

    /**
     * @dev deposit msg.value amount of ETH into a common pool, and keep track of the addres which deposited it so they
     * can later withdraw it
     */
     function deposit() external payable {
         if(msg.value > 0){
             balanceSheet[msg.sender] += msg.value;
         }
     }

     function withdraw(uint256 amount) external {
         require(balanceSheet[msg.sender] >= amount, "Bank: caller is withdrawing more ETH than they've deposited");

         // at this point in the execution, we know msg.sender has deposited at least of ETH previously, so we
         // are OK withdraw it from the contract's pool of ETH

         balanceSheet[msg.sender] -= amount;

         (bool sent,) = payable(msg.sender).call{value: amount}("");
         require(sent, "Failed to send Ether");
     }
}