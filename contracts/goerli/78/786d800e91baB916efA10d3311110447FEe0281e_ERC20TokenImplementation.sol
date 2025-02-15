/**
 *Submitted for verification at Etherscan.io on 2022-11-14
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library SafeMath {
	function mul(uint256 a, uint256 b) internal pure returns (uint256) {
		if (a == 0) {
			return 0;
		}
		uint256 c = a * b;
		assert(c / a == b);
		return c;
	}

	function div(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a / b;
		return c;
	}

	function sub(uint256 a, uint256 b) internal pure returns (uint256) {
		assert(b <= a);
		return a - b;
	}

	function add(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a + b;
		assert(c >= a);
		return c;
	}

	function mod(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a % b;       
		return c;
	}
}

contract Manageable {
	address internal _owner;
	address internal _manager;

	modifier onlyOwner() {
		require(msg.sender == _owner);
		_;
	}
	
	modifier onlyManager() {
		require(msg.sender == _manager);
		_;
	}

	function transferOwnership(address owner) external onlyOwner {
		if (owner != address(0)) {
			_owner = owner;
		}
	}
	
	function setManager(address manager) external onlyOwner {
		_manager = manager;
	}

	function getOwner() external view returns (address) {
		return _owner;
	}
	
	function getManager() external view returns (address) {
		return _manager;
	}

}

contract Pausable is Manageable {
  event Pause();
  event Unpause();

  bool public paused = false;

  modifier whenNotPaused() {
	require(!paused);
	_;
  }

  modifier whenPaused() {
	require(paused);
	_;
  }

  function pause() onlyManager whenNotPaused external {
	paused = true;
	emit Pause();
  }

  function unpause() onlyManager whenPaused external {
	paused = false;
	emit Unpause();
  }
}

contract BlackListable is Manageable {
	mapping (address => bool) internal isBlackListed;

	function getBlackListStatus(address _maker) external view returns (bool) {
		return isBlackListed[_maker];
	}

	function addBlackList (address _evilUser) external onlyManager {
		isBlackListed[_evilUser] = true;
		emit AddedBlackList(_evilUser);
	}

	function removeBlackList (address _clearedUser) external onlyManager {
		isBlackListed[_clearedUser] = false;
		emit RemovedBlackList(_clearedUser);
	}

	event DestroyedBlackFunds(address _blackListedUser, uint256 _balance);
	event AddedBlackList(address _user);
	event RemovedBlackList(address _user);

}

contract ERC20TokenImplementation is Manageable, Pausable, BlackListable {
	using SafeMath for uint256;

	mapping(address => uint256) internal balances;
	mapping (address => mapping (address => uint256)) internal allowed;

	uint256 internal constant MAX_UINT = 2**256 - 1;

	/**
	* @dev Fix for the ERC20 short address attack.
	*/
	modifier onlyPayloadSize(uint256 size) {
		require(!(msg.data.length < size + 4));
		_;
	}

	string internal _name;
	string internal _symbol;
	uint256 internal _totalSupply;
	uint8 internal _decimals;
	bool internal _initialized;
	
	function initialize(
		string calldata tokenName,
		string calldata tokenSymbol,
		uint8 tokenDecimals,
		address owner,
		address manager
	) external {
		require(!_initialized);
		require(owner != address(0));
		_name = tokenName;
		_symbol = tokenSymbol;
		_decimals = tokenDecimals;
		_owner = owner;
		_manager = manager;
		_initialized = true;
	}

	function totalSupply() external view returns (uint256) {
		return _totalSupply;
	}

	function name() external view returns (string memory) {
		return _name;
	}

	function symbol() external view returns (string memory) {
		return _symbol;
	}

	function decimals() external view returns (uint8) {
		return _decimals;
	}

	function transfer(address _to, uint256 _value) external whenNotPaused onlyPayloadSize(2 * 32) returns (bool) {
		require(!isBlackListed[msg.sender]);

		balances[msg.sender] = balances[msg.sender].sub(_value);
		balances[_to] = balances[_to].add(_value);
	 
		emit Transfer(msg.sender, _to, _value);
		return true;
	}

	function balanceOf(address _address) external view returns (uint256 balance) {
		return balances[_address];
	}

	function transferFrom(address _from, address _to, uint256 _value) external whenNotPaused onlyPayloadSize(3 * 32) returns (bool)  {
		require(!isBlackListed[_from]);
		uint256 _allowance = allowed[_from][msg.sender];

		allowed[_from][msg.sender] = _allowance.sub(_value);

		balances[_from] = balances[_from].sub(_value);
		balances[_to] = balances[_to].add(_value);
		
		emit Transfer(_from, _to, _value);
		return true;
	}

	function approve(address _spender, uint256 _value) external whenNotPaused onlyPayloadSize(2 * 32) returns (bool) {

		require(!((_value != 0) && (allowed[msg.sender][_spender] != 0)));

		allowed[msg.sender][_spender] = _value;
		emit Approval(msg.sender, _spender, _value);
		return true;
	}

	function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
		return allowed[_owner][_spender];
	}

	event Approval(address indexed acc_owner, address indexed spender, uint256 value);
	event Transfer(address indexed from, address indexed to, uint256 value);

	function destroyBlackFunds (address _blackListedUser) external onlyManager {
		require(isBlackListed[_blackListedUser]);
		uint256 dirtyFunds = this.balanceOf(_blackListedUser);
		balances[_blackListedUser] = 0;
		_totalSupply = _totalSupply.sub(dirtyFunds);
		emit DestroyedBlackFunds(_blackListedUser, dirtyFunds);
	}

	function issue(address _to, uint256 _amount) external onlyManager {
		require(_to != address(0));
		require(_amount > 0);
		
		_totalSupply = _totalSupply.add(_amount);
		balances[_to] = balances[_to].add(_amount);
		
		emit Transfer(address(0), _to, _amount);
		emit Issue(msg.sender, _to, _amount);
	}

	function redeem(uint256 _amount) external onlyManager {
		uint256 balance = balances[msg.sender];
		require(_amount > 0);
		require(balance >= _amount);
		
		_totalSupply = _totalSupply.sub(_amount);
		balances[msg.sender] = balance.sub(_amount);
		
		emit Transfer(msg.sender, address(0), _amount);
		emit Redeem(msg.sender, _amount);
	}
	
	event Issue(address indexed minter, address indexed to, uint256 amount);
	event Redeem(address indexed burner, uint256 amount);
}