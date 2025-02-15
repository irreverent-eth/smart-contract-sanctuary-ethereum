// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './PriceConverter.sol';

error FundMe__NotOwner();

contract FundMe {
  using PriceConverter for uint256;

  uint256 public constant MINIMUM_USD = 50 * 1e18; // 1 * 10 ** 18
  // 21,415 gas - constant
  // 23,515 gas - non-constant
  // 21,415 * 141000000000 = $9,058545
  // 23,515 * 141000000000 = $9,946845

  address[] private s_funders;
  mapping(address => uint256) private s_addressToAmountFunded; // s_ - storage

  address private immutable i_owner; // i_ - immutable

  // 21,508 gas - immutable
  // 23,644 gas - non-immutable

  AggregatorV3Interface private s_priceFeed;

  constructor(address priceFeed) {
    s_priceFeed = AggregatorV3Interface(priceFeed);
    i_owner = msg.sender;
  }

  // msg.value (uint): number of wei sent with the message
  // msg.sender (address): sender of the message (current call)
  function fund() public payable {
    // getConversionRate(msg.value);
    // msg.value.getConversionRate();

    // require(msg.value > 1e18, "You need to spend more ETH!"); // 1e18 = 1 * 10 ** 18 = 1000000000000000000
    require(
      msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
      'You need to spend more ETH!'
    ); // 1e18 = 1 * 10 ** 18 = 1000000000000000000
    s_funders.push(msg.sender);
    s_addressToAmountFunded[msg.sender] = msg.value;
  }

  function withdraw() public onlyOwner {
    // starting index
    // ending index
    // step amount
    for (
      uint256 funderIndex = 0;
      funderIndex < s_funders.length;
      funderIndex++
    ) {
      address funder = s_funders[funderIndex];
      s_addressToAmountFunded[funder] = 0;
    }

    // reset the array
    s_funders = new address[](0);

    // msg.sender = address
    // payable(msg.sender) = payable address

    // transfer
    // payable(msg.sender).transfer(address(this).balance);

    // send
    // bool sendSuccess = payable(msg.sender).send(address(this).balance);
    // require(sendSuccess, "Send failed");

    // call
    (bool callSuccess, ) = payable(msg.sender).call{
      value: address(this).balance
    }('');
    require(callSuccess, 'Call failed');
  }

  function cheaperWithdraw() public payable onlyOwner {
    address[] memory funders = s_funders;

    for (uint256 funderIndex = 0; funderIndex < funders.length; funderIndex++) {
      address funder = funders[funderIndex];
      s_addressToAmountFunded[funder] = 0;
    }

    s_funders = new address[](0);
    (bool success, ) = i_owner.call{value: address(this).balance}('');
    require(success);
  }

  modifier onlyOwner() {
    // require(msg.sender == i_owner, 'Sender is not owner!'); // 1
    if (msg.sender != i_owner) {
      revert FundMe__NotOwner();
    }
    _; // 2 (all code in withdraw())
  }

  fallback() external payable {
    fund();
  }

  receive() external payable {
    fund();
  }

  function getOwner() public view returns (address) {
    return i_owner;
  }

  function getFunder(uint256 index) public view returns (address) {
    return s_funders[index];
  }

  function getAddressToAmountFunded(address funder)
    public
    view
    returns (uint256)
  {
    return s_addressToAmountFunded[funder];
  }

  function getPriceFeed() public view returns (AggregatorV3Interface) {
    return s_priceFeed;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

library PriceConverter {
  function getPrice(AggregatorV3Interface priceFeed)
    internal
    view
    returns (uint256)
  {
    // ABI
    // Address 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e

    // AggregatorV3Interface priceFeed = AggregatorV3Interface(
    //   0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
    // );

    // (uint80 roundID, int price, uint startedAt, uint timeStamp, uint80 answeredInRound) = priceFeed.latestRoundData();
    (, int256 price, , , ) = priceFeed.latestRoundData();

    // ETH in terms of USD
    // 3000.00000000
    return uint256(price * 1e10); // 1**10 = 10000000000
  }

  function getVersion() internal view returns (uint256) {
    AggregatorV3Interface priceFeed = AggregatorV3Interface(
      0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
    );
    return priceFeed.version();
  }

  function getConversionRate(uint256 ethAmount, AggregatorV3Interface priceFeed)
    internal
    view
    returns (uint256)
  {
    uint256 ethPrice = getPrice(priceFeed);
    uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1000000000000000000; // 1e18;
    return ethAmountInUsd;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}