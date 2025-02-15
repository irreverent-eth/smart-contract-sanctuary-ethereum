/**
 *Submitted for verification at Etherscan.io on 2022-11-11
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Flyweight {
    struct Order {
        uint id;
        OrderState orderState;
        string tokenIn;
        string tokenOut;
        string tokenInTriggerPrice;
        OrderTriggerDirection direction;
        uint tokenInAmount;
    }
    struct Price {
        string token0;
        string token1;
        string price;
        string unixTimestamp;
    }

    enum OrderState { UNTRIGGERED, TRIGGERED }
    enum OrderTriggerDirection { BELOW, EQUAL, ABOVE }

    uint public ordersCount;
    uint public pricesCount;
    mapping(uint => Order) public orders;
    mapping(uint => Price) public prices;

    function addNewOrder(string calldata tokenIn, string calldata tokenOut, string calldata tokenInTriggerPrice, OrderTriggerDirection direction, uint tokenInAmount) external returns(uint) {
        uint id = ordersCount;
        orders[id] = Order({
            id: id,
            orderState: OrderState.UNTRIGGERED,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            tokenInTriggerPrice: tokenInTriggerPrice,
            direction: direction,
            tokenInAmount: tokenInAmount
        });

        ordersCount++;
        return id;
    }

    function storePricesAndProcessTriggeredOrderIds(Price[] calldata newPrices, uint[] calldata newTriggeredOrderIds) external {
        for (uint i = 0; i < newPrices.length; i++) {
            prices[pricesCount] = newPrices[i];
            pricesCount++;
        }

        for (uint i = 0; i < newTriggeredOrderIds.length; i++) {
            uint orderId = newTriggeredOrderIds[i];
            orders[orderId].orderState = OrderState.TRIGGERED;
        }
    }

    function processTriggeredOrderIds(uint[] calldata newTriggeredOrderIds) private {
        // todo uniswap
    }
}