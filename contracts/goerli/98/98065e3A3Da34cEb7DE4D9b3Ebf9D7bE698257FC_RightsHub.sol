// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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

// SPDX-License-Identifier: MIT
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract RightsHub is Ownable {  

  /**
   * @dev Emitted when rights are declared for tokens of contract `contractAddr`
   */
  event RightsDeclaration(address indexed contractAddr, address indexed declarer, address indexed registrar, string rightsURI);

  // Indicates if allow list is active or not
  bool private _useAllowlist;
  
  // List of contract addresses that can call this contract
  mapping(address => bool) _allowlist;

  constructor() {
    _useAllowlist = true;
  }
 
  /*
   * Returns a boolean indicating if allow list is enabled
   */
  function useAllowlist() public view returns (bool) {
    return _useAllowlist;
  }

  /*
   * Disable allow list 
   */
  function disableAllowlist() public onlyOwner {
    _useAllowlist = false;
  }

  /*
   * Enable allowlist 
   */
  function enableAllowlist() public onlyOwner {
    _useAllowlist = true;
  }

  /*
   * Add address to allowed list
   */
  function addAllowed(address addr) public onlyOwner {
    _allowlist[addr] = true;
  }
  
  /*
   * Remove address from allowed list
   */
  function removeAllowed(address addr) public onlyOwner {
    _allowlist[addr] = false;
  }

  /*
   * Throws error if caller is not in the allowed list
   */
  modifier onlyAllowed() {
    if (_useAllowlist) {
      require(_allowlist[msg.sender] == true || _allowlist[tx.origin] == true, "RightsHub: caller is not in allow list");
    }
    _;
  }

  /*
   * Declare Rights for NFTs in the Smart Contract
   */
  function declareRights(address contractAddr, address declarer, string calldata rightsURI) public onlyAllowed {
    require(tx.origin != msg.sender, "RightsHub: declareRights() can only be called by Smart Contracts");
    require(bytes(rightsURI).length > 0, "RightsHub: Rights URI can not be empty");
    
    // Emit event
    emit RightsDeclaration(contractAddr, declarer, msg.sender, rightsURI);
  }
}