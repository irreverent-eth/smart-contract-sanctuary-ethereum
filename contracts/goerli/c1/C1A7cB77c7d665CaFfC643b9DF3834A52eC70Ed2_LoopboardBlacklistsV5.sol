/**
 *Submitted for verification at Etherscan.io on 2022-11-21
*/

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract LoopboardBlacklistsV5 {
    mapping(address => uint256[]) private nftIDs;
    mapping(address => string[]) private creators;

    function addNFT(uint256 id) public returns (bool) {
        uint256[] storage ownNftIDs = nftIDs[msg.sender];
        bool isExisting = false;
        for (uint256 index = 0; index < ownNftIDs.length; index++) {
            if (ownNftIDs[index] == id) {
                isExisting = true;
            }
        }
        if (isExisting) {
            return false;
        }

        ownNftIDs.push(id);
        return true;
    }

    function addCreator(string memory minterAddress) public returns (bool) {
        string[] storage ownCreators = creators[msg.sender];
        bytes32 idHash = keccak256(abi.encode(minterAddress));
        bool isExisting = false;
        for (uint256 index = 0; index < ownCreators.length; index++) {
            if (keccak256(abi.encode(ownCreators[index])) == idHash) {
                isExisting = true;
            }
        }
        if (isExisting) {
            return false;
        }

        ownCreators.push(minterAddress);
        return true;
    }

    function getBlacklistedNftIDsLength(address adminAddress)
        public
        view
        returns (uint256)
    {
        return nftIDs[adminAddress].length;
    }

    function getBlacklistedNftID(address adminAddress, uint256 index)
        public
        view
        returns (uint256)
    {
        return nftIDs[adminAddress][index];
    }

    function getBlacklistedNftIDs(address adminAddress, uint256 offset)
        public
        view
        returns (uint256[64] memory)
    {
        uint256[64] memory ids;
        for (uint256 i = 0; i < 64; i++) {
            if (i < nftIDs[adminAddress].length + offset) {
                ids[i] = nftIDs[adminAddress][i + offset];
            } else {
                ids[i] = 0;
            }
            ids[i] = nftIDs[adminAddress][i + offset];
        }
        return ids;
    }

    function getAllBlacklistedNftIDs(address adminAddress)
        public
        view
        returns (uint256[] memory)
    {
        return nftIDs[adminAddress];
    }

    function getBlacklistedCreatorsLength(address adminAddress)
        public
        view
        returns (uint256)
    {
        return creators[adminAddress].length;
    }

    function getBlacklistedCreator(address adminAddress, uint256 index)
        public
        view
        returns (string memory)
    {
        return creators[adminAddress][index];
    }

    function getBlacklistedCreators(address adminAddress, uint256 offset)
        public
        view
        returns (string[64] memory)
    {
        string[64] memory ids;
        for (uint256 i = 0; i < 64; i++) {
            if (i < creators[adminAddress].length + offset) {
                ids[i] = creators[adminAddress][i + offset];
            } else {
                ids[i] = "";
            }
        }
        return ids;
    }

    function getAllBlacklistedCreators(address adminAddress)
        public
        view
        returns (string[] memory)
    {
        return creators[adminAddress];
    }
}