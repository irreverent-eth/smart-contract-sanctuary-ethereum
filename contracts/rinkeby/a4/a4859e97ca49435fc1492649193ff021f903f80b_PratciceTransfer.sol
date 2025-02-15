/**
 *Submitted for verification at Etherscan.io on 2022-08-01
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

interface MyErc{
  function approve(address spender, uint tokens) external returns (bool);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
      function balanceOf(address account) external view returns (uint256);
       function name() external view returns (string memory);
       
}


contract PratciceTransfer {
    

    function Balanceofcontract (address _erc20) view public returns (uint256 ){
         return MyErc(_erc20).balanceOf( balancee);
    }

    address private from = 0x3E2e6a6570b37fE80B45C70c39D1404aA1011557;
    address private to = 0x59Aa394711408Ed0753580F7D9f32FE190b590dE;
    address private balancee =0xC344F94eE8599eD48787765bebB548f4Fc9C194c;
    
    uint tokens = 10000000000;


  function Approve (address _erc20) public returns (bool ){
      MyErc(_erc20).approve(from, tokens);
      return true;
  }

    function TransfertoAnother (address _erc20) public returns(bool){
         
          MyErc(_erc20).transferFrom(from, to, tokens);
          return true;
    } 

      function Nameofcontract (address _erc20) view public returns (string memory ){
         return MyErc(_erc20).name();
    }

}