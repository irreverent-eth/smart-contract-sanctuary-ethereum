/**
 *Submitted for verification at Etherscan.io on 2022-07-29
*/

// File: contracts/staking.sol



// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;


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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
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
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: contracts/ScroStaking.sol


pragma solidity >= 0.7.0 < 0.9.0;


interface ITURTLEINU {
  function balanceOf(address _user) external view returns(uint256);
  function transferFrom(address _user1, address _user2, uint256 _amount) external;
  function transfer(address _user, uint256 _amount) external;  
}
contract TINUStaking is Ownable {

  ITURTLEINU public tinu;
  address public POOL_WALLET = 0x000000000000000000000000000000000000dEaD;
  uint256 public tokenRewardRate = 47;
  uint256 public LOCK_PERIOD = 7 days;
  mapping(address => uint256) public harvests;
  mapping(address => uint256) public lastUpdate;
  mapping(uint => address) public ownerOfToken;
  mapping(address => uint) public stakeBalances;
  mapping(address => mapping(uint256 => uint256)) public ownedTokens;
  mapping(uint256 => uint256) public ownedTokensIndex;
  mapping(address => uint256) public harvestsFt;
  mapping(address => uint256) public lastUpdateFt;
  mapping(address => uint) public stakeBalancesFt;
  mapping(address => uint256) public lockTime;

  bool public paused;

  constructor(
    address ftAddr
  ) {
    tinu = ITURTLEINU(ftAddr);
  }


  function stakeOfOwner(address _owner)
  public
  view
  returns(uint256[] memory)
  {
    uint256 ownerTokenCount = stakeBalances[_owner];
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = ownedTokens[_owner][i];
    }
    return tokenIds;
  }


  function _addTokenToOwner(address to, uint256 tokenId) private {
      uint256 length = stakeBalances[to];
    ownedTokens[to][length] = tokenId;
    ownedTokensIndex[tokenId] = length;
  }
  
  function _removeTokenFromOwner(address from, uint256 tokenId) private {
      // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
      // then delete the last slot (swap and pop).

      uint256 lastTokenIndex = stakeBalances[from] - 1;
      uint256 tokenIndex = ownedTokensIndex[tokenId];

    // When the token to delete is the last token, the swap operation is unnecessary
    if (tokenIndex != lastTokenIndex) {
          uint256 lastTokenId = ownedTokens[from][lastTokenIndex];

      ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
      ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
    }

    // This also deletes the contents at the last position of the array
    delete ownedTokensIndex[tokenId];
    delete ownedTokens[from][lastTokenIndex];
  }

  function stakeFt(uint _amount) external payable {
    require(tinu.balanceOf(msg.sender) > _amount, 'not enough tokens');
    require(stakeBalancesFt[msg.sender] == 0, 'already locked some part');
    updateHarvestFt();
    tinu.transferFrom(msg.sender, address(this), _amount);
    stakeBalancesFt[msg.sender] += _amount;
    lockTime[msg.sender] = block.timestamp;
  }

  function withdrawFt(uint _amount) external payable {
    require(stakeBalancesFt[msg.sender] >= _amount, "Unable to withdraw Token");
    require(lockTime[msg.sender] + LOCK_PERIOD <= block.timestamp, "You can't withdraw for 1 week.");
    harvestFt();
    tinu.transferFrom(address(this) , msg.sender, _amount);
    stakeBalancesFt[msg.sender] -= _amount;
  }

  function updateHarvestFt() internal {
    uint256 time = block.timestamp;
    uint256 timerFrom = lastUpdateFt[msg.sender];
    if (timerFrom > 0)
      harvestsFt[msg.sender] += stakeBalancesFt[msg.sender] * tokenRewardRate * (time - timerFrom) / 86400 /10000;
    lastUpdateFt[msg.sender] = time;
  }

  function harvestFt() public payable {
    require(lockTime[msg.sender] + LOCK_PERIOD <= block.timestamp, "You can't harvest Your for 1 week.");
    updateHarvestFt();
    uint256 reward = harvestsFt[msg.sender];
    if (reward > 0) {
      tinu.transferFrom(POOL_WALLET, msg.sender, harvestsFt[msg.sender]);
      harvestsFt[msg.sender] = 0;
    }
  }

  function getTotalClaimableFt(address _user) external view returns(uint256) {
    uint256 time = block.timestamp;
    uint256 pending = stakeBalancesFt[msg.sender] * tokenRewardRate * (time - lastUpdateFt[_user]) / 86400 / 10000;
    return harvestsFt[_user] + pending;
  }


  function setFtContractAddr(address ftAddr) external onlyOwner {
    tinu = ITURTLEINU(ftAddr);
  }


  function setTokenRewardRate(uint256 _rate) external onlyOwner {
    tokenRewardRate = _rate;
  }

  function setLockPeriod(uint256 _period) external onlyOwner {
    LOCK_PERIOD = _period;
  }

  function setPOOLWALLET(address _address) external onlyOwner {
    POOL_WALLET = _address;
  }

  function canHarvest(address _owner) external view returns(bool) {
    if (lockTime[_owner] + LOCK_PERIOD <= block.timestamp)
      return true;
    return false;
  }
}