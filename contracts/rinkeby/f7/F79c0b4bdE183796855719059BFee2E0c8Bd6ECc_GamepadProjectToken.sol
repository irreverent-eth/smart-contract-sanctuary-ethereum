// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "./interfaces/IPoolAllocV3.sol";
import "./utils/EmergencyWithdraw.sol";

contract GamepadProjectToken is
  OwnableUpgradeable,
  EmergencyWithdraw,
  ReentrancyGuardUpgradeable,
  AccessControlUpgradeable,
  EIP712Upgradeable
{
  struct WhitelistInput {
    address wallet;
    uint256 maxPayableAmount;
  }

  struct Whitelist {
    address wallet;
    uint256 amount;
    uint256 maxPayableAmount;
    uint256 rewardedAmount;
    bool whitelist;
    uint256 redeemed;
  }

  struct VestInfo {
    uint rate;
    uint timestamp;
  }

  // Percentage nominator: 1% = 100
  uint256 private constant _RATE_NOMINATOR = 10_000;

  // The signer who has VALIDATOR_ROLE can allow user to be in whitelist
  bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

  // Private
  IERC20Metadata private _token;
  IERC20Metadata private _acceptingToken;

  // Whitelist map
  mapping(address => Whitelist) private whitelist;
  address[] public whitelistUsers;

  // Vesting config
  VestInfo[] private _vestConfig;

  // Public
  uint256 public startTime;
  uint256 public tokenRate;
  uint256 public soldAmount;
  uint256 public totalRaise;
  uint256 public totalParticipant;
  uint256 public totalRedeemed;
  uint256 public totalRewardTokens;
  bool public isFinished;
  bool public isClosed;
  bool public isFailedSale;
  uint256 public maxPublicPayableAmount;
  mapping(address => bool) public publicSaleList;
  mapping(address => bool) public refundedList;
  uint256 public publicTime;
  uint256 public publicTimeHolder;
  uint256 public reduceTokenAmount;
  // Staking pool to calculate alloc. address(0) mean disable auto calculate
  address public allocPool;

  // Events
  event ESetAcceptedTokenAddress(string _name, string _symbol, uint8 _decimals, uint256 _totalSupply);
  event ESetTokenAddress(string _name, string _symbol, uint8 _decimals, uint256 _totalSupply);
  event ESetTokenRate(uint256 _tokenRate);
  event EOpenSale(uint256 _startTime, bool _isStart);
  event EBuyTokens(
    address _sender,
    uint256 _value,
    uint256 _totalToken,
    uint256 _rewardedAmount,
    uint256 _senderTotalAmount,
    uint256 _senderTotalRewardedAmount,
    uint256 _senderSoldAmount,
    uint256 _senderTotalRise,
    uint256 _totalParticipant,
    uint256 _totalRedeemed
  );
  event ECloseSale(bool _isClosed);
  event EFinishSale(bool _isFinished);
  event ERedeemTokens(address _wallet, uint256 _rewardedAmount);
  event ERefund(address _wallet, uint256 _refundedAmount);
  event EAddWhiteList(WhitelistInput[] _addresses);
  event ERemoveWhiteList(address[] _addresses);
  event EWithdrawBNBBalance(address _sender, uint256 _balance);
  event EWithdrawRemainingTokens(address _sender, uint256 _remainingAmount);
  event EWithdrawAcceptingTokens(address _sender, uint256 _amount);
  event EAddRewardTokens(address _sender, uint256 _amount, uint256 _remaingRewardTokens);

  /**
   * @dev Upgradable initializer
   */
  function __GamepadProjectToken_init() public initializer {
    __Ownable_init();
    __AccessControl_init();
    __ReentrancyGuard_init();
    __EIP712_init("WhitelistSig", "1.0.0");
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    // Default token rate is 0.01
    tokenRate = 1e16;
  }

  // Read: Get token address
  function getTokenAddress() public view returns (address tokenAddress) {
    return address(_token);
  }

  // Read: Get token address
  function getAcceptingTokenAddress() public view returns (address tokenAddress) {
    return address(_acceptingToken);
  }

  // Read: Get Total Token
  function getTotalToken() public view returns (uint256) {
    return _token.balanceOf(address(this));
  }

  function isInitialized() public view returns (bool) {
    return startTime != 0;
  }

  // Read: Is Sale Start
  function isStart() public view returns (bool) {
    return isInitialized() && startTime > 0 && block.timestamp >= startTime;
  }

  //read token in Accepting Token
  function getTokenInAcceptingToken(uint256 tokens) public view returns (uint256) {
    uint256 tokenDecimal = 10**uint256(_token.decimals());
    return (tokens * tokenRate) / tokenDecimal;
  }

  // Read: Calculate Token
  function calculateAmount(uint256 acceptedAmount) public view returns (uint256) {
    uint256 tokenDecimal = 10**uint256(_token.decimals());
    return (acceptedAmount * tokenDecimal) / tokenRate;
  }

  // Read: Get max payable amount against whitelisted address
  function getMaxPayableAmount(address _address) public view returns (uint256) {
    Whitelist memory whitelistWallet = whitelist[_address];
    return whitelistWallet.maxPayableAmount;
  }

  // Read: Get whitelist wallet
  function getWhitelist(address _address)
    public
    view
    returns (
      address _wallet,
      uint256 _amount,
      uint256 _maxPayableAmount,
      uint256 _rewardedAmount,
      uint256 _redeemed,
      bool _whitelist
    )
  {
    Whitelist memory whitelistWallet = whitelist[_address];
    return (
      _address,
      whitelistWallet.amount,
      whitelistWallet.maxPayableAmount,
      whitelistWallet.rewardedAmount,
      whitelistWallet.redeemed,
      whitelistWallet.whitelist
    );
  }

  //Read return remaining reward
  function getRemainingReward() public view returns (uint256) {
    return totalRewardTokens - soldAmount - reduceTokenAmount;
  }

  // Read return whitelistUsers length
  function getWhitelistUsersLength() external view returns (uint256) {
    return whitelistUsers.length;
  }

  //Read return whitelist paging
  function getUsersPaging(uint _offset, uint _limit)
    public
    view
    returns (
      Whitelist[] memory users,
      uint nextOffset,
      uint total
    )
  {
    uint totalUsers = whitelistUsers.length;
    if (_limit == 0) {
      _limit = 1;
    }

    if (_limit > totalUsers - _offset) {
      _limit = totalUsers - _offset;
    }

    Whitelist[] memory values = new Whitelist[](_limit);
    for (uint i = 0; i < _limit; i++) {
      values[i] = whitelist[whitelistUsers[_offset + i]];
    }

    return (values, _offset + _limit, totalUsers);
  }

  /*
   * @dev Set new vest config
   */
  function setVestConfig(VestInfo[] memory _config) external onlyOwner {
    delete _vestConfig;

    // 100%
    uint256 totalRate_ = _RATE_NOMINATOR;
    for (uint i = 0; i < _config.length; i++) {
      totalRate_ -= _config[i].rate;
      require(_config[i].rate >= 0, "Rate must not zero");
      require(totalRate_ >= 0, "Invalid total rate");
      _vestConfig.push(VestInfo(_config[i].rate, _config[i].timestamp));
    }
    require(totalRate_ == 0, "Total rate must be 100");
  }

  /*
   * @dev Get vest config
   */
  function getVestConfig() external view returns (VestInfo[] memory) {
    return _vestConfig;
  }

  /*
   * @dev Get redeemable amount
   */
  function getTotalRedeemable(address _user) public view returns (uint256) {
    uint256 validRate_ = 0;
    for (uint i = 0; i < _vestConfig.length; i++) {
      if (block.timestamp < _vestConfig[i].timestamp) break;
      else {
        validRate_ += _vestConfig[i].rate;
      }
    }
    return (validRate_ * whitelist[_user].rewardedAmount) / _RATE_NOMINATOR;
  }

  /*
   * @notice Update pool address
   * Set to address(0) to disable auto allocation
   */
  function setAllocPool(address _allocPool) external onlyOwner {
    allocPool = _allocPool;
  }

  // Write: Token Address
  function setTokenAddress(IERC20Metadata token) external onlyOwner {
    _token = token;
    // Emit event
    emit ESetTokenAddress(token.name(), token.symbol(), token.decimals(), token.totalSupply());
  }

  // Write: Accepting Token Address
  function setAcceptingTokenAddress(IERC20Metadata token) external onlyOwner {
    require(startTime == 0, "Must before sale");

    _acceptingToken = token;
    // Emit event
    emit ESetTokenAddress(token.name(), token.symbol(), token.decimals(), token.totalSupply());
  }

  // Write: Owner set exchange rate
  function setTokenRate(uint256 _tokenRate) external onlyOwner {
    require(!isInitialized(), "Initialized");
    require(_tokenRate > 0, "Not zero");

    tokenRate = _tokenRate;
    // Emit event
    emit ESetTokenRate(tokenRate);
  }

  // Write: Open sale
  // Ex _startTime = 1618835669
  function openSale(uint256 _startTime) external onlyOwner {
    require(!isInitialized(), "Initialized");
    require(_startTime >= block.timestamp, "Must >= current time");
    require(getTokenAddress() != address(0), "Token address is empty");
    require(getAcceptingTokenAddress() != address(0), "No accepting token");
    require(totalRewardTokens > 0, "Total token != zero");

    startTime = _startTime;
    isClosed = false;
    isFinished = false;
    // Emit event
    emit EOpenSale(startTime, isStart());
  }

  // Enable public sale with max amount
  function setMaxPublicPayableAmount(uint256 _maxAmount) external onlyOwner {
    maxPublicPayableAmount = _maxAmount;
  }

  // Set reduce token amount on total reward tokens
  function setReduceTokenAmount(uint256 _amount) external onlyOwner {
    require(_amount <= (totalRewardTokens - soldAmount), "Wrong amount");
    reduceTokenAmount = _amount;
  }

  // Set public sale time.
  // In public sale, only holder can not during this time
  function setPublicTime(uint256 _publicTime, uint256 _publicTimeHolder) external onlyOwner {
    publicTime = _publicTime;
    publicTimeHolder = _publicTimeHolder;
  }

  // Check public sale
  function isPublicSale() public view returns (bool) {
    return maxPublicPayableAmount > 0 && block.timestamp >= publicTime;
  }

  // Check ico is raise
  function isICORaising() external view returns (bool) {
    return isStart() && !isClosed && !isFinished && !isPublicSale();
  }

  ///////////////////////////////////////////////////
  // IN SALE
  // Write: User buy token by sending tokens
  // Convert Accepted bnb to Sale token
  function buyTokens(
    uint256 _amount,
    bool _useValidator,
    uint256 _maxAmount,
    bytes calldata _signature
  ) external nonReentrant {
    address payable senderAddress = payable(_msgSender());
    uint256 acceptedAmount = _amount;

    // Asserts
    require(isStart(), "Sale is not started yet");
    require(!isClosed, "Sale is closed");
    require(!isFinished, "Sale is finished");

    Whitelist memory whitelistSnapshot = whitelist[senderAddress];
    // Public sale after 24hrs
    bool isPublicSale_ = isPublicSale();

    // Auto whitelist
    if (!isPublicSale_ && whitelistSnapshot.wallet == address(0)) {
      if (_useValidator) {
        // Validate max amount by validator
        require(hasRole(VALIDATOR_ROLE, _fValidateSignature(_maxAmount, _signature)), "Wrong role");
        whitelistSnapshot.maxPayableAmount = _maxAmount;
      } else if (allocPool != address(0)) {
        // Whitelist via participate pool
        whitelistSnapshot.maxPayableAmount =
          IPoolAllocV3(allocPool).estICOAmounts(senderAddress, totalRewardTokens) /
          1e18;
      }
      whitelistUsers.push(senderAddress);
      whitelistSnapshot.wallet = senderAddress;
      whitelistSnapshot.whitelist = true;
      whitelist[senderAddress] = whitelistSnapshot;
    }

    // First hours of public sale is just for holder
    if (isPublicSale_ && block.timestamp <= publicTimeHolder) {
      require(whitelistSnapshot.whitelist, "Holder first");
    }

    if (!isPublicSale_) {
      require(!publicSaleList[senderAddress], "Not for public sale");
    } else if (whitelistSnapshot.wallet == address(0)) {
      publicSaleList[senderAddress] = true;
      whitelistUsers.push(senderAddress);
      whitelistSnapshot.wallet = senderAddress;
      whitelistSnapshot.maxPayableAmount = maxPublicPayableAmount;
      whitelistSnapshot.whitelist = true;
      whitelist[senderAddress] = whitelistSnapshot;
    }

    require(whitelistSnapshot.whitelist, "You are not in whitelist");
    require(acceptedAmount > 0, "Pay accepted tokens");

    uint256 rewardedAmount = calculateAmount(acceptedAmount);
    // In public sale mode, just check with maxPublicPayableAmount
    if (!isPublicSale_) {
      require(
        whitelistSnapshot.maxPayableAmount >= whitelistSnapshot.rewardedAmount + rewardedAmount,
        "max payable amount reached"
      );
    } else {
      require(
        maxPublicPayableAmount >= whitelistSnapshot.rewardedAmount + rewardedAmount,
        "max public payable reached"
      );
    }

    uint256 unsoldTokens = getRemainingReward();
    uint256 tokenValueInAcceptingTokens = getTokenInAcceptingToken(unsoldTokens);

    if (acceptedAmount >= tokenValueInAcceptingTokens) {
      //refund excess amount
      uint256 excessAmount = acceptedAmount - tokenValueInAcceptingTokens;
      //remaining amount
      acceptedAmount = acceptedAmount - excessAmount;
      //close the sale
      isClosed = true;
      rewardedAmount = calculateAmount(acceptedAmount);
      emit ECloseSale(isClosed);
    }

    require(rewardedAmount > 0, "Zero rewarded amount");
    _acceptingToken.transferFrom(_msgSender(), address(this), acceptedAmount);

    // Update total participant
    // Check if current whitelist amount is zero and will be deposit
    // then increase totalParticipant variable
    if (whitelistSnapshot.amount == 0 && acceptedAmount > 0) {
      totalParticipant = totalParticipant + 1;
    }
    // Update whitelist detail info
    whitelist[senderAddress].amount = whitelistSnapshot.amount + acceptedAmount;
    whitelist[senderAddress].rewardedAmount = whitelistSnapshot.rewardedAmount + rewardedAmount;
    // Update global info
    soldAmount = soldAmount + rewardedAmount;
    totalRaise = totalRaise + acceptedAmount;

    // Emit buy event
    emit EBuyTokens(
      senderAddress,
      acceptedAmount,
      totalRewardTokens,
      rewardedAmount,
      whitelist[senderAddress].amount,
      whitelist[senderAddress].rewardedAmount,
      soldAmount,
      totalRaise,
      totalParticipant,
      totalRedeemed
    );
  }

  // Write: Finish sale
  function finishSale(bool _status) external onlyOwner returns (bool) {
    isFinished = _status;
    // Emit event
    emit EFinishSale(isFinished);
    return isFinished;
  }

  ///////////////////////////////////////////////////
  // AFTER SALE
  // Write: Redeem Rewarded Tokens
  function redeemTokens() external nonReentrant {
    address senderAddress = _msgSender();

    require(whitelist[senderAddress].whitelist, "Sender is not in whitelist");

    Whitelist memory whitelistWallet = whitelist[senderAddress];

    require(isFinished, "Sale is not finalized yet");
    require(!isFailedSale, "Sale is failed");

    uint256 totalRedeemable_ = getTotalRedeemable(senderAddress);
    uint256 redeemableAmount_ = totalRedeemable_ - whitelistWallet.redeemed;
    require(redeemableAmount_ > 0, "Vesting time");
    whitelist[senderAddress].redeemed = totalRedeemable_;
    _token.transfer(whitelistWallet.wallet, redeemableAmount_);

    // Update total redeem
    // solhint-disable-next-line
    totalRedeemed += redeemableAmount_;

    // Emit event
    emit ERedeemTokens(whitelistWallet.wallet, redeemableAmount_);
  }

  // Write: Allow user withdraw their BNB if the sale is failed
  function refundAcceptingTokens() external nonReentrant {
    address payable senderAddress = payable(_msgSender());

    require(isClosed, "Sale is not closed yet");
    require(isFailedSale, "Sale is not failed");
    require(whitelist[senderAddress].whitelist, "Sender is not in whitelist");
    require(!refundedList[senderAddress], "Already refunded");
    refundedList[senderAddress] = true;

    Whitelist memory whitelistWallet = whitelist[senderAddress];
    _acceptingToken.transfer(senderAddress, whitelistWallet.amount);

    // Emit event
    emit ERefund(senderAddress, whitelistWallet.amount);
  }

  ///////////////////////////////////////////////////
  // FREE STATE
  // Write: Add Whitelist
  function addWhitelist(WhitelistInput[] memory inputs) external onlyOwner {
    uint256 addressesLength = inputs.length;

    for (uint256 i = 0; i < addressesLength; i++) {
      WhitelistInput memory input = inputs[i];
      if (whitelist[input.wallet].wallet == address(0)) {
        whitelistUsers.push(input.wallet);
      }
      Whitelist memory _whitelist = Whitelist(input.wallet, 0, input.maxPayableAmount, 0, true, 0);

      whitelist[input.wallet] = _whitelist;
    }
    // Emit event
    emit EAddWhiteList(inputs);
  }

  // Write: Remove Whitelist
  function removeWhitelist(address[] memory addresses) external onlyOwner {
    uint256 addressesLength = addresses.length;

    for (uint256 i = 0; i < addressesLength; i++) {
      address _address = addresses[i];
      Whitelist memory _whitelistSnapshot = whitelist[_address];
      whitelist[_address] = Whitelist(
        _address,
        _whitelistSnapshot.amount,
        _whitelistSnapshot.maxPayableAmount,
        _whitelistSnapshot.rewardedAmount,
        false,
        _whitelistSnapshot.redeemed
      );
    }

    // Emit event
    emit ERemoveWhiteList(addresses);
  }

  // Write: Mark failed sale to allow user withdraw their fund
  function markFailedSale(bool status) external onlyOwner {
    isFailedSale = status;
  }

  // Write: Close sale - stop buying
  function closeSale(bool status) external onlyOwner {
    isClosed = status;
    emit ECloseSale(isClosed);
  }

  // Write: owner can withdraw all BNB
  function withdrawBNBBalance() external onlyOwner {
    address payable sender = payable(_msgSender());

    uint256 balance = address(this).balance;
    sender.transfer(balance);

    // Emit event
    emit EWithdrawBNBBalance(sender, balance);
  }

  // Write: Owner withdraw tokens which are not sold
  function withdrawRemainingTokens() external onlyOwner {
    address sender = _msgSender();
    uint256 lockAmount = soldAmount - totalRedeemed;
    uint256 remainingAmount = totalRewardTokens - lockAmount;

    _token.transfer(sender, remainingAmount);

    // Emit event
    emit EWithdrawRemainingTokens(sender, remainingAmount);
  }

  // Write: Owner withdraw accepting tokens
  function withdrawAcceptingTokens() external onlyOwner {
    address sender = _msgSender();
    uint256 amount = _acceptingToken.balanceOf(address(this));
    _acceptingToken.transfer(sender, amount);

    // Emit event
    emit EWithdrawAcceptingTokens(sender, amount);
  }

  // Write: Owner can add reward tokens
  function addRewardTokens(uint256 _amount) external onlyOwner {
    require(getTokenAddress() != address(0), "Invalid token address");
    require(_amount > 0, "Amount should not be 0");

    address sender = _msgSender();
    _token.transferFrom(sender, address(this), _amount);
    totalRewardTokens = totalRewardTokens + _amount;

    emit EAddRewardTokens(sender, _amount, totalRewardTokens);
  }

  // Write: Correct total reward tokens
  function setTotalRewardTokens(uint256 _amount) external onlyOwner {
    totalRewardTokens = _amount;
  }

  /**
   * @dev Validate signature return signer address
   * @param _pMaxAmount max payable amount
   * @param _pSignature bytes signature
   */
  function _fValidateSignature(uint256 _pMaxAmount, bytes memory _pSignature) private view returns (address) {
    bytes32 digest_ = _fHash(_msgSender(), _pMaxAmount);
    return ECDSAUpgradeable.recover(digest_, _pSignature);
  }

  /**
   * @dev Hash v4
   * @param _pUser address user address
   * @param _pMaxAmount max payable amount
   */
  function _fHash(address _pUser, uint256 _pMaxAmount) private view returns (bytes32) {
    return
      _hashTypedDataV4(
        keccak256(abi.encode(keccak256("WhitelistSig(address _pUser,uint256 _pMaxAmount)"), _pUser, _pMaxAmount))
      );
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EmergencyWithdraw is OwnableUpgradeable {
  event Received(address _sender, uint256 _amount);

  /**
   * @dev Allow contract to receive ethers
   */
  receive() external payable {
    emit Received(_msgSender(), msg.value);
  }

  /**
   * @dev Get the eth balance on the contract
   * @return eth balance
   */
  function fGetEthBalance() external view returns (uint256) {
    return address(this).balance;
  }

  /**
   * @dev Withdraw eth balance
   */
  function fEmergencyWithdrawEthBalance(address _pTo, uint256 _pAmount) external onlyOwner {
    require(_pTo != address(0), "Invalid to");
    payable(_pTo).transfer(_pAmount);
  }

  /**
   * @dev Get the token balance
   * @param _pTokenAddress token address
   */
  function fGetTokenBalance(address _pTokenAddress) external view returns (uint256) {
    IERC20 erc20 = IERC20(_pTokenAddress);
    return erc20.balanceOf(address(this));
  }

  /**
   * @dev Withdraw token balance
   * @param _pTokenAddress token address
   */
  function fEmergencyWithdrawTokenBalance(
    address _pTokenAddress,
    address _pTo,
    uint256 _pAmount
  ) external onlyOwner {
    IERC20 erc20 = IERC20(_pTokenAddress);
    erc20.transfer(_pTo, _pAmount);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IPoolAllocV3 {
  function estICOAmounts(address _user, uint256 _tokenForSale) external view returns (uint256 _amount);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal initializer {
        __ERC165_init_unchained();
    }

    function __ERC165_init_unchained() internal initializer {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ECDSAUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding specified in the EIP is very generic, and such a generic implementation in Solidity is not feasible,
 * thus this contract does not implement the encoding itself. Protocols need to implement the type-specific encoding
 * they need in their contracts using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * _Available since v3.4._
 */
abstract contract EIP712Upgradeable is Initializable {
    /* solhint-disable var-name-mixedcase */
    bytes32 private _HASHED_NAME;
    bytes32 private _HASHED_VERSION;
    bytes32 private constant _TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /* solhint-enable var-name-mixedcase */

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    function __EIP712_init(string memory name, string memory version) internal initializer {
        __EIP712_init_unchained(name, version);
    }

    function __EIP712_init_unchained(string memory name, string memory version) internal initializer {
        bytes32 hashedName = keccak256(bytes(name));
        bytes32 hashedVersion = keccak256(bytes(version));
        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        return _buildDomainSeparator(_TYPE_HASH, _EIP712NameHash(), _EIP712VersionHash());
    }

    function _buildDomainSeparator(
        bytes32 typeHash,
        bytes32 nameHash,
        bytes32 versionHash
    ) private view returns (bytes32) {
        return keccak256(abi.encode(typeHash, nameHash, versionHash, block.chainid, address(this)));
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return ECDSAUpgradeable.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /**
     * @dev The hash of the name parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712NameHash() internal virtual view returns (bytes32) {
        return _HASHED_NAME;
    }

    /**
     * @dev The hash of the version parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712VersionHash() internal virtual view returns (bytes32) {
        return _HASHED_VERSION;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSAUpgradeable {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        // Check the signature length
        // - case 65: r,s,v signature (standard)
        // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return tryRecover(hash, r, vs);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s;
        uint8 v;
        assembly {
            s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            v := add(shr(255, vs), 27)
        }
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal initializer {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal initializer {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
    }

    function __AccessControl_init_unchained() internal initializer {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(uint160(account), 20),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
    uint256[49] private __gap;
}