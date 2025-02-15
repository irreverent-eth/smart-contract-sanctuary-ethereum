/**
 *Submitted for verification at Etherscan.io on 2022-08-10
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

contract CrowdFundingStorage {
    struct Campaign {
        address payable receiver;
        uint numFunders;
        uint fundingGoal;
        uint totalAmount;
    }

    struct Funder {
        address addr;
        uint amount;
    }

    uint public numCampagins;
    mapping(uint => Campaign) campaigns;
    mapping(uint => Funder[]) funders;

    mapping(uint => mapping(address => bool)) public isParticipate;

    event CampaignLog(uint campaignID,address receiver,uint goal);

}

contract CrowdFunding is CrowdFundingStorage {
    address immutable owner;

    constructor() {
        owner = msg.sender;
    }

    modifier judgeParticipate(uint campaignID) {
        require(isParticipate[campaignID][msg.sender] == false);
        _;
    }

    modifier isOwner() {
        require(msg.sender == owner);
        _;
    }

    function newCampaign(address payable receiver, uint goal) external isOwner() returns(uint campaignID) {
        campaignID = numCampagins++;
        Campaign storage c = campaigns[campaignID];
        c.receiver = receiver;
        c.fundingGoal = goal;

        emit CampaignLog(campaignID,receiver,goal);
    }

    event BidLog(uint campaignID,address donator,uint value);

    function bid(uint campaignID) external payable judgeParticipate(campaignID) {
        Campaign storage c = campaigns[campaignID];

        c.totalAmount += msg.value;
        c.numFunders += 1;

        funders[campaignID].push(Funder({
            addr: msg.sender,
            amount: msg.value
        }));

        isParticipate[campaignID][msg.sender] = true;

        emit BidLog(campaignID,msg.sender,msg.value);
    }

    function withdraw(uint campaignID) external returns(bool reached) {
        Campaign storage c = campaigns[campaignID];

        if(c.totalAmount < c.fundingGoal) {
            return false;
        }

        uint amount = c.totalAmount;
        c.totalAmount = 0;
        c.receiver.transfer(amount);

        return true;
    }
}