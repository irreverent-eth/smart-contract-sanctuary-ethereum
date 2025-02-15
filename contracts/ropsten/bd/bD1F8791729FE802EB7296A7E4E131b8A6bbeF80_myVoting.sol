/**
 *Submitted for verification at Etherscan.io on 2022-08-07
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract myVoting{
    
    address public owner;
    struct condidate{
        uint id;
        string name;
        uint128 voteCount;
    }
    mapping (uint=>condidate) condidates;
    mapping (address=>bool) participants;
    uint128 public condidateCount;
    constructor(){
        owner=msg.sender;
    }
    modifier onlyOwner(){
        require(msg.sender==owner,"Only owner is allowed");
        _;
    }
    function AddCondid(string memory _name)public onlyOwner returns(string memory) {
        condidates[condidateCount]=condidate({
            id:condidateCount,
            name:_name,
            voteCount:0
        });
        condidateCount++;
        return "succes";
    }
    function vote(uint _id)public returns(string memory){
        require(participants[msg.sender]==false,"You have voted once");
        require(_id<=condidateCount && _id>=0,"There is no such candidate");
        participants[msg.sender]=true;
        condidates[_id].voteCount++;
        return "Your vote has been successfully registered";
    }

    function condidateList() public view returns (condidate[] memory)
   {
      condidate [] memory list=new condidate[](condidateCount);
      for (uint256 i=0;i<condidateCount;i++){
          condidate memory condid=condidates[i];
          list[i]=condid;
      }
      return list;
   }

    function showWinner()public view returns(condidate memory){
        condidate memory winner;
        uint128 winnerCount=0;
        for(uint i=0;i<condidateCount;i++){
            if(condidates[i].voteCount>winnerCount){
                winnerCount= condidates[i].voteCount;
                winner=condidates[i];                
            }
        }
        return winner;
    }
}