// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC721.sol";
import "./Ownable.sol";
import "./Strings.sol";

contract InfNNNNTest2 is ERC721, Ownable {

    uint256 public totalSupply;

    //metadatas
    string public baseURI = "https://server.wagmi-studio.com/metadata/test/infTest/";

    constructor()
    ERC721("Inf NNNN TEST 2", "INFNNN")
        {
        }


    function mint(address to, uint256 quantity) external onlyOwner {
        unchecked {
            for(uint256 i = 0;i<quantity;i++){
                _owners[++totalSupply] = to;
                emit Transfer(address(0), to, totalSupply);
            }
            _balances[to] = _balances[to] + quantity;
        }
    }

    function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

    function tokenURI(uint256 tokenId) public view override
        returns (string memory)
    {
        require(_exists(tokenId), "URI query for nonexistent token");
        // Concatenate the baseURI and the tokenId as the tokenId should
        // just be appended at the end to access the token metadata
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId), ".json"));
    }


}