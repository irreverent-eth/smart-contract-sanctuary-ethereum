/**
 *Submitted for verification at Etherscan.io on 2022-09-14
*/

pragma solidity >= 0.7.0 < 0.9.0;

contract Bienvenida {
   constructor() public{
   } 
   function getResult() public view returns(uint){
       uint a = 1;
       uint b = 2;
       uint result = a + b;
       return result;
   }
}