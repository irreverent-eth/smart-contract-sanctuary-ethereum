/**
 *Submitted for verification at Etherscan.io on 2022-08-27
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

contract EscribirEnLaBlockchain{

    string texto;

    function Escribir(string calldata _texto) public {
        texto = _texto;
    }

    function Leer() public view returns(string memory) {
        return texto;
    }

}