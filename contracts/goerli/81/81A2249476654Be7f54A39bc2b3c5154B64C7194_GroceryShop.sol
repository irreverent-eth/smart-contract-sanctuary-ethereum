/**
 *Submitted for verification at Etherscan.io on 2022-10-24
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract GroceryShop {

    event Added(GroceryType groceryType, uint256 numberAdded);
    event Bought(uint256 purchaseId, GroceryType groceryType, uint256 numberOfUnitBought);

    enum GroceryType { Bread, Egg, Jam }

    address public owner;
    uint256 private purchaseId;

    struct Grocery {
        string name;
        uint256 numberOfItems;
    }

    struct PurchaseDetail {
        address buyerAddress;
        GroceryType itemType;
        uint256 numberOfUnitBought;
    }

    mapping (GroceryType => Grocery) public groceryItem;
    mapping (uint256 => PurchaseDetail) private purchaseReceipt;

    constructor(uint256 _breadCount, uint256 _eggCount, uint256 _jamCount) {
        groceryItem[GroceryType.Bread] = Grocery("Bread", _breadCount);
        groceryItem[GroceryType.Egg] = Grocery("Egg", _eggCount);
        groceryItem[GroceryType.Jam] = Grocery("Jam", _jamCount);
        purchaseId = 0;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only Owner allowed make a call");
        _;
    }

    function add(GroceryType _groceryType, uint256 _numberAdded) public onlyOwner {
        require(_numberAdded > 0, "Number must be greater than zero");
        groceryItem[_groceryType].numberOfItems += _numberAdded;
        emit Added(_groceryType, _numberAdded);
    }

    function buy(GroceryType _groceryType, uint256 _numberToBought) public payable {
        require(msg.value > 0, "You must sent some ether");
        require(groceryItem[_groceryType].numberOfItems >= _numberToBought, "Not enough items");
        
        uint256 total = _numberToBought * (0.01 ether);
        require(msg.value >= total, "Invalid amount");

        purchaseId++;
        groceryItem[_groceryType].numberOfItems -= _numberToBought;
        purchaseReceipt[purchaseId] = PurchaseDetail(msg.sender, _groceryType, _numberToBought);
        emit Bought(purchaseId, _groceryType, _numberToBought);
    }

    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function cashRegister(uint256 _purchaseId) public view onlyOwner returns (address, GroceryType, uint256) {
        require(_purchaseId <= purchaseId, "Invalid Purchase ID");

        address buyer = purchaseReceipt[_purchaseId].buyerAddress;
        uint256 numBought = purchaseReceipt[_purchaseId].numberOfUnitBought;

        return (
            buyer,
            purchaseReceipt[_purchaseId].itemType,
            numBought
        );
    }
}