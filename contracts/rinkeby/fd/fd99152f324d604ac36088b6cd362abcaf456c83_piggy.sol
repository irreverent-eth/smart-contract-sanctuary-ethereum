/**
 *Submitted for verification at Etherscan.io on 2022-08-05
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract piggy{
    uint public goal;
    constructor(uint _goal) {
        goal=_goal;
    }
    receive() external payable{}
     function getmybalance() public view returns(uint){
        return address(this).balance;
    }

    function withdraw() public {
        if(getmybalance() > goal) {
            selfdestruct(payable(msg.sender));
        }
    }
}