/**
 *Submitted for verification at Etherscan.io on 2022-09-20
*/

// Sources flattened with hardhat v2.11.2 https://hardhat.org

// File src/interfaces/IResolver.sol

// SPDX-License-Identifier: MIT
pragma solidity =0.8.6;

interface IResolver {
    enum PaymentToken {SENTINEL, WETH, DAI, USDC, USDT, TUSD, RENT}

    function getPaymentToken(uint8 _pt) external view returns (address);

    function setPaymentToken(uint8 _pt, address _v) external;
}


// File src/Resolver.sol


pragma solidity =0.8.6;

contract Resolver is IResolver {
    address private admin;
    mapping(uint8 => address) private addresses;

    constructor(address _admin) {
        admin = _admin;
    }

    function getPaymentToken(uint8 _pt)
        external
        view
        override
        returns (address)
    {
        return addresses[_pt];
    }

    function setPaymentToken(uint8 _pt, address _v) external override {
        require(_pt != 0, "ReNFT::cant set sentinel");
        require(
            addresses[_pt] == address(0),
            "ReNFT::cannot reset the address"
        );
        require(msg.sender == admin, "ReNFT::only admin");
        addresses[_pt] = _v;
    }
}