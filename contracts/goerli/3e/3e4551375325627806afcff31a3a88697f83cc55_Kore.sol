/**
 *Submitted for verification at Etherscan.io on 2022-11-14
*/

// SPDX-License-Identifier: CC-BY-ND-4.0

pragma solidity ^0.8.17;

// SECTION Defining a standard interface for Kore

interface iKore {
    // Methods
    function addLiquidity(address token_1, address token_2, uint256 amount_1, uint256 amount_2) external returns (bytes32 liquidity);
    function removeLiquidity(address token_1, address token_2, uint256 amount_1, uint256 amount_2) external;
    function swap(address token_1, address token_2, uint256 amount) external;
    function simulateSwap(bytes32 liquidity, address token_1, uint amount) external view returns (uint256 amount_2, uint256 fees_amount);
    function collectFees(address token_1, address token_2) external returns (bool success);
    function protocolCollectFees(address token_1, address token_2) external returns (bool success);
    function findLiquidityFromTokens(address token_1, address token_2) external view returns (bool exists, bytes32 liquidity);
    // Events
    event LiquidityAdded(bytes32 liquidity_id, address token_1, address token_2, uint256 amount_1, uint256 amount_2, address liquidity_provider);
    event LiquidityRemoved(bytes32 liquidity_id, address token_1, address token_2, uint256 amount_1, uint256 amount_2, address liquidity_provider);
    event LiquiditySwapped(bytes32 liquidity_id, address token_1, address token_2, uint256 amount_1, uint256 amount_2, address liquidity_provider);
}

// !SECTION Defining a standard interface for Kore

// SECTION Protection Contract

contract protected {
    mapping (address => bool) is_auth;
    function authorized(address addy) public view returns(bool) {
        return is_auth[addy];
    }
    function set_authorized(address addy, bool booly) public onlyAuth {
        is_auth[addy] = booly;
    }
    modifier onlyAuth() {
        require( is_auth[msg.sender] || msg.sender==owner, "not owner");
        _;
    }
    address owner;
    modifier onlyOwner() {
        require(msg.sender==owner, "not owner");
        _;
    }
    bool locked;
    modifier safe() {
        require(!locked, "reentrant");
        locked = true;
        _;
        locked = false;
    }
    function change_owner(address new_owner) public onlyAuth {
        owner = new_owner;
    }
    receive() external payable {}
    fallback() external payable {}
}

// !SECTION Protection Contract

// SECTION ERC20 Interfaces

interface IERC20 {
  function name() external view returns (string memory);
  function symbol() external view returns (string memory);
  function decimals() external view returns (uint8);
  function totalSupply() external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

// !SECTION ERC20 Interfaces

// SECTION Kore Contract

contract Kore is iKore, protected {

    // SECTION Structures and datatypes

    struct LIQUIDITY {
        address creator;
        address token_1;
        address token_2;
        uint256 amount_1;
        uint256 amount_2;
        mapping (address => uint16) liquidity_percentage_owned;
        uint256 creation_time;
        // Fees
        uint256 collected_fees_token_1;
        uint256 collected_fees_token_2;
        uint128 protocol_share;
        uint128 liquidity_provider_share;
        // Fees tracking
        mapping (address => uint256) already_claimed_fees_token_1;
        mapping (address => uint256) already_claimed_fees_token_2;
        uint256 protocol_claimed_fees_token_1;
        uint256 protocol_claimed_fees_token_2;
    }

    mapping (bytes32 => LIQUIDITY) public liquidities;

    // !SECTION Structures and datatypes

    constructor() {
        owner = msg.sender;
        is_auth[msg.sender] = true;
    }

    // SECTION Public methods



    // !SECTION Public methods

    function addLiquidity(address token_1, address token_2, 
                          uint amount_1, uint amount_2) 
                          external safe returns (bytes32 liquidity_id) {
        // Calculating liquidity hash
        (bool exists, bytes32 liquidity) = findLiquidityFromTokens(token_1, token_2);
        // Detecting if the liquidity has to be created
        bool toCreate = !exists;       
        if (!toCreate) {
            // If is not to create, let's ensure the ratio is ok (with a small margin)
            uint local_ratio = (amount_1 * 100) / amount_2;
            uint liq_ratio = _calculateRatio(liquidity);
            require(local_ratio >= liq_ratio - 1 && local_ratio <= liq_ratio + 1, "Ratio is not correct");  
            // Adding liquidity
            liquidities[liquidity].amount_1 += amount_1;
            liquidities[liquidity].amount_2 += amount_2;
            // Calculate the percentage of liquidity owned by the liquidity provider
            uint actual_owned_token_1;
            uint actual_owned_token_2;
            (actual_owned_token_1, actual_owned_token_2) = _percentageToOwnedTokens(liquidity, msg.sender);
            actual_owned_token_1 += amount_1;
            actual_owned_token_2 += amount_2;
            liquidities[liquidity].liquidity_percentage_owned[msg.sender] = _ownedTokensToPercentage(
                                                                                liquidity, 
                                                                                actual_owned_token_1, 
                                                                                actual_owned_token_2);

        } else {
            liquidity = keccak256(abi.encodePacked(token_1, token_2));
            // Creating the liquidity if is to create
            liquidities[liquidity].token_1 = token_1;
            liquidities[liquidity].token_2 = token_2;
            liquidities[liquidity].amount_1 = amount_1;
            liquidities[liquidity].amount_2 = amount_2;
            liquidities[liquidity].creator = msg.sender;
            liquidities[liquidity].creation_time = block.timestamp;
            liquidities[liquidity].protocol_share = 50;
            liquidities[liquidity].liquidity_provider_share = 50;
            // Assigning the whole percentage to the liquidity provider
            // REVIEW Should we set this to 10000 too?
            liquidities[liquidity].liquidity_percentage_owned[msg.sender] = 10000;
        }

        return liquidity;

    }

    function removeLiquidity(address token_1, address token_2, 
                             uint amount_1, uint amount_2) 
                             external override safe {
        // Calculating liquidity hash
        (bool exists, bytes32 liquidity) = findLiquidityFromTokens(token_1, token_2);
        require(exists, "Liquidity does not exist");
        // Checking if the liquidity exists
        require(liquidities[liquidity].token_1 != address(0), "Liquidity does not exist");
        // Checking if the liquidity provider owns enough tokens
        uint actual_owned_token_1;
        uint actual_owned_token_2;
        (actual_owned_token_1, actual_owned_token_2) = _percentageToOwnedTokens(liquidity, msg.sender);
        require(actual_owned_token_1 >= amount_1 && actual_owned_token_2 >= amount_2, "Not enough tokens");
        // Removing liquidity
        liquidities[liquidity].amount_1 -= amount_1;
        liquidities[liquidity].amount_2 -= amount_2;
        // Calculate the percentage of liquidity owned by the liquidity provider
        liquidities[liquidity].liquidity_percentage_owned[msg.sender] = _ownedTokensToPercentage(
                                                                            liquidity, 
                                                                            actual_owned_token_1 - amount_1, 
                                                                            actual_owned_token_2 - amount_2);
        // Emitting event
        emit LiquidityRemoved(liquidity, liquidities[liquidity].token_1, liquidities[liquidity].token_2, amount_1, amount_2, msg.sender);
    }

    /// @dev Swaps the provided token if is in the provided liquidity
    /// @param token_1 The token to swap
    /// @param token_2 The token to receive
    /// @param amount the amount to send
    function swap(address token_1,
                  address token_2, 
                  uint amount) 
                  external safe {
        // Checking if the liquidity exists
        (bool exists, bytes32 liquidity) = findLiquidityFromTokens(token_1, token_2);
        require(exists, "Liquidity does not exist");
        IERC20 erc20_in = IERC20(token_1);
        // Simulating the swap feasibility
        uint amountOut;
        uint feesCollected;
        (amountOut, feesCollected) = simulateSwap(liquidity, token_1, amount);
        // Transferring the tokens
        bool success = erc20_in.transferFrom(msg.sender, address(this), amount);
        require(success, "KORE: In transfer failed");
        // Updating the pool values
        liquidities[liquidity].token_1 == token_1 ? 
            liquidities[liquidity].amount_1 += amount : 
            liquidities[liquidity].amount_2 += amount;
        liquidities[liquidity].token_1 == token_1 ?
            liquidities[liquidity].amount_2 -= amountOut :
            liquidities[liquidity].amount_1 -= amountOut;
        // Updating the fees
        liquidities[liquidity].token_1 == token_1 ?
            liquidities[liquidity].collected_fees_token_1 += feesCollected :
            liquidities[liquidity].collected_fees_token_2 += feesCollected;
        // Sending the tokens to the user
        IERC20 erc20_out = IERC20(liquidities[liquidity].token_1 == token_1 ? 
                                  liquidities[liquidity].token_2 : 
                                  liquidities[liquidity].token_1);
        success = erc20_out.transfer(msg.sender, amountOut);
        require(success, "KORE: Out transfer failed");
        // Emitting the event
        emit LiquiditySwapped(liquidity, 
                              liquidities[liquidity].token_1, 
                              liquidities[liquidity].token_2, 
                              amount, 
                              amountOut, 
                              msg.sender);
    }

    /// @dev Simulates a swap
    /// @param liquidity The liquidity to swap
    /// @param token_in the token to send
    /// @param amount the amount to send
    /// @return out_simulated the tokens to receive
    /// @return fees_simulated the fees collected
    function simulateSwap(bytes32 liquidity, 
                  address token_in,
                  uint amount) public override view 
                  returns (uint out_simulated, uint fees_simulated) { 
        // Ensuring the liquidity exists
        require(liquidities[liquidity].token_1 == token_in || 
                liquidities[liquidity].token_2 == token_in, 
                "KORE: Token in not in liquidity pool");
        require(amount > 0, "KORE: Amount must be greater than 0");
        IERC20 erc20_in = IERC20(token_in);
        // Ensuring funds are there
        require(erc20_in.balanceOf(msg.sender) >= amount, "KORE: Not enough balance");
        // Getting the pool values
        uint reserveIn = liquidities[liquidity].token_1 == token_in ? 
                         liquidities[liquidity].amount_1 : 
                         liquidities[liquidity].amount_2;
        uint reserveOut = liquidities[liquidity].token_1 == token_in ? 
                          liquidities[liquidity].amount_2 : 
                          liquidities[liquidity].amount_1;
        // Simulating the swap
        uint amountOut;
        uint feesCollected;
        (amountOut, feesCollected) = _getAmountOut(amount, reserveIn, reserveOut);
        // Checking if the liquidity can handle the swap
        require(amountOut > 0, "KORE: Not enough liquidity");
        require(amountOut <= reserveOut, "KORE: Not enough liquidity");
        return (amountOut, feesCollected);
    }

    /// @dev Collecting fees accrued as liquidity provider
    /// @param token_1 The first token of the liquidity
    /// @param token_2 The second token of the liquidity
    /// @return collected The success of the collection
    function collectFees(address token_1, address token_2) external safe returns (bool collected) {
        // Calculating liquidity hash
        (bool exists, bytes32 liquidity) = findLiquidityFromTokens(token_1, token_2);
        require(exists, "Liquidity does not exist");
        // Checking if has fees to collect
        (uint tkn_1_dued, uint tkn_2_dued) = _calculateOwnedFees(liquidity, msg.sender);
        require(tkn_1_dued > 0 || tkn_2_dued > 0, "KORE: No fees to collect");
        // Updating the fees
        liquidities[liquidity].collected_fees_token_1 -= tkn_1_dued;
        liquidities[liquidity].collected_fees_token_2 -= tkn_2_dued;
        // Sending the tokens to the user
        IERC20 erc20_1 = IERC20(liquidities[liquidity].token_1);
        IERC20 erc20_2 = IERC20(liquidities[liquidity].token_2);
        bool success = erc20_1.transfer(msg.sender, tkn_1_dued);
        require(success, "KORE: Out transfer failed");
        success = erc20_2.transfer(msg.sender, tkn_2_dued);
        require(success, "KORE: Out transfer failed");
        // Updating the fees collected
        liquidities[liquidity].already_claimed_fees_token_1[msg.sender] += tkn_1_dued;
        liquidities[liquidity].already_claimed_fees_token_2[msg.sender] += tkn_2_dued;
        // Returning boolean
        return true;
    }

    /// @dev Collecting fees accrued as protocol
    /// @param token_1 The first token of the liquidity
    /// @param token_2 The second token of the liquidity
    /// @return collected The success of the collection
    function protocolCollectFees(address token_1, address token_2) external onlyAuth returns (bool collected) {
        // Calculating liquidity hash
        (bool exists, bytes32 liquidity) = findLiquidityFromTokens(token_1, token_2);
        require(exists, "Liquidity does not exist");
        // Checking if has fees to collect
        (uint tkn_1_dued, uint tkn_2_dued) = _calculateProtocolOwnedFees(liquidity);
        require(tkn_1_dued > 0 || tkn_2_dued > 0, "KORE: No fees to collect");
        // Updating the fees
        liquidities[liquidity].collected_fees_token_1 -= tkn_1_dued;
        liquidities[liquidity].collected_fees_token_2 -= tkn_2_dued;
        // Sending the tokens to the user
        IERC20 erc20_1 = IERC20(liquidities[liquidity].token_1);
        IERC20 erc20_2 = IERC20(liquidities[liquidity].token_2);
        bool success = erc20_1.transfer(msg.sender, tkn_1_dued);
        require(success, "KORE: Out transfer failed");
        success = erc20_2.transfer(msg.sender, tkn_2_dued);
        require(success, "KORE: Out transfer failed");
        // Updating the fees collected
        liquidities[liquidity].protocol_claimed_fees_token_1 += tkn_1_dued;
        liquidities[liquidity].protocol_claimed_fees_token_1 += tkn_2_dued;
        // Returning boolean
        return true;
    }

    // SECTION Internal methods

    /// @dev Calculates the result of a swap based on input value and reserves of the liquidity pool
    /// @param amountIn Amount of tokens to swap
    /// @param reserveIn Amount of token in in the liquidity pool
    /// @param reserveOut Amount of token out in the liquidity pool
    /// @return _amountOut of tokens to receive
    /// @return feesCollected the fees collected by this trade
    function _getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) 
                           internal pure returns (uint _amountOut, uint feesCollected) {
        require(amountIn > 0, 'KORE: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'KORE: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * (997);
        // Track fees
        uint feeCollected = amountIn - amountInWithFee;
        uint numerator = amountInWithFee * (reserveOut);
        uint denominator = reserveIn * (1000) + (amountInWithFee);
        uint amountOut = numerator / denominator;
        return (amountOut, feeCollected);
    }

    /// @dev Returns the actual amount of tokens owned by the provider based on its percentage
    /// @param liquidity the liquidity we refer to 
    /// @param provider the address that provided liquidity
    /// @return _amount_1 the amount of token_1 owned
    /// @return _amount_2 the amount of token_2 owned
    function _percentageToOwnedTokens(bytes32 liquidity, address provider)
                                      internal view returns (uint _amount_1, uint _amount_2) {
        uint percentage = liquidities[liquidity].liquidity_percentage_owned[provider];
        uint amount_1 = liquidities[liquidity].amount_1;
        uint amount_2 = liquidities[liquidity].amount_2;
        // Using 10000 to enable decimals
        uint amount_1_owned = amount_1 * percentage / 100000;
        uint amount_2_owned = amount_2 * percentage / 100000;
        return (amount_1_owned, amount_2_owned);
    }

    /// @dev Returns the actual percentage of liqudity owned by the provider based on its tokens
    /// @param liquidity the liquidity we refer to 
    /// @param amount_1 the amount of token_1 owned
    /// @param amount_2 the amount of token_2 owned
    /// @return _percentage the liquidity percentage owned
    function _ownedTokensToPercentage(bytes32 liquidity, uint amount_1, uint amount_2)
                                      internal view returns (uint16 _percentage) {
        uint amount_1_owned = liquidities[liquidity].amount_1;
        uint amount_2_owned = liquidities[liquidity].amount_2;
        // Using 10000 to enable decimals
        uint percentage_1 = amount_1 * 100000 / amount_1_owned;
        uint percentage_2 = amount_2 * 100000 / amount_2_owned;
        // REVIEW Is this true?
        require(percentage_1 == percentage_2, "KORE: PERCENTAGE MISMATCH");
        return uint16(percentage_1);
    }

    /// @dev Returns the fees owned by a provider based on the accrued fees in the liquidity pool
    /// @param liquidity the liquidity we refer to
    /// @param provider the address that provided liquidity
    /// @return tkn_1 the fees owned in token_1
    /// @return tkn_2 the fees owned in token_2
    function _calculateOwnedFees(bytes32 liquidity, address provider) 
                                 internal view returns (uint tkn_1, uint tkn_2) {
        uint percentage = liquidities[liquidity].liquidity_percentage_owned[provider];
        uint fees_1 = liquidities[liquidity].collected_fees_token_1;
        uint fees_2 = liquidities[liquidity].collected_fees_token_2;
        // Using 10000 to enable decimals
        uint fees_1_owned = ((fees_1 * percentage) / 100000) - 
                            liquidities[liquidity].already_claimed_fees_token_1[provider];
        uint fees_2_owned = ((fees_2 * percentage) / 100000) -
                            liquidities[liquidity].already_claimed_fees_token_2[provider];
        return (fees_1_owned, fees_2_owned);
    }

    /// @dev Returns the fees owned by the protocol based on the accrued fees in the liquidity pool
    /// @param liquidity the liquidity we refer to
    /// @return tkn_1 the fees owned in token_1
    /// @return tkn_2 the fees owned in token_2
    function _calculateProtocolOwnedFees(bytes32 liquidity) 
                                 internal view returns (uint tkn_1, uint tkn_2) {
        uint fees_1 = liquidities[liquidity].collected_fees_token_1;
        uint fees_2 = liquidities[liquidity].collected_fees_token_2;
        uint fees_1_owned = fees_1 - liquidities[liquidity].protocol_claimed_fees_token_1;
        uint fees_2_owned = fees_2 - liquidities[liquidity].protocol_claimed_fees_token_2;
        return (fees_1_owned, fees_2_owned);
    }
    

    // !SECTION Internal methods


    // SECTION Utilities

    /// @dev Returns the current ratio of a liquidity pool
    /// @param liquidity the liquidity we refer to
    /// @return _ratio the ratio of the liquidity pool (0 if is empty of course)
    function _calculateRatio(bytes32 liquidity) 
                             internal view 
                             returns (uint256 _ratio) {
        uint256 total_liquidity = liquidities[liquidity].amount_1 + liquidities[liquidity].amount_2;
        uint ratio = (liquidities[liquidity].amount_1 * 100) / total_liquidity;
        return ratio;
    }

    /// @dev Returns the liquidity hash from a pair of tokens
    /// @param token_1 the first token
    /// @param token_2 the second token
    /// @return exists if the liquidity exists
    /// @return liquidity the liquidity hash
    function findLiquidityFromTokens(address token_1, address token_2) 
                                      public override view returns (bool exists, bytes32 liquidity) {

        bytes32 possible_liquidity_1 = keccak256(abi.encodePacked(token_1, token_2));
        bytes32 possible_liquidity_2 = keccak256(abi.encodePacked(token_2, token_1));
        if (liquidities[possible_liquidity_1].token_1 != address(0)) {
            return (true, possible_liquidity_1);
        } else if (liquidities[possible_liquidity_2].token_1 != address(0)) {
            return (true, possible_liquidity_2);
        } else {
            return (false, 0x0);
        }
    }
    

    // !SECTION Utilities
    
}

// !SECTION Kore Contract