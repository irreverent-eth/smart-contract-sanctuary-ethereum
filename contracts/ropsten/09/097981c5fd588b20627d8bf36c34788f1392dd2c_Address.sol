/**
 *Submitted for verification at Etherscan.io on 2022-07-05
*/

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.6.12;

interface IERC20 {

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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



/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
 
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

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
contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function geUnlockTime() public view returns (uint256) {
        return _lockTime;
    }

    //Locks the contract for owner for the amount of time provided
    function lock(uint256 time) public virtual onlyOwner {
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = now + time;
        emit OwnershipTransferred(_owner, address(0));
    }
    
    //Unlocks the contract for owner when _lockTime is exceeds
    function unlock() public virtual {
        require(_previousOwner == msg.sender, "You don't have permission to unlock");
        require(now > _lockTime , "Contract is locked until 7 days");
        emit OwnershipTransferred(_owner, _previousOwner);
        _owner = _previousOwner;
    }
}

// pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    //配对合约被创建的事件
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    //收税员地址
    function feeTo() external view returns (address);
    //收税员权限控制地址
    function feeToSetter() external view returns (address);
    //获取配对地址 mapping(address => mapping(address => address)) public gatPair;
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    //获取配对地址
    function allPairs(uint) external view returns (address pair);
    //获取配对地址的数量
    function allPairsLength() external view returns (uint);
    //创建配对
    //使用tokenA和tokenB的地址创建配对地址 pair address
    //确认tokenA不能等于tokenB
    //将tokenA 和tokenB进行排序 => token0 token1
    //确认token0不为0地址
    //确认token0和token1没有配对过 getpair[token0][token1] == address(0);
    //用uniswapv2pair合约创建字节码 bytes memory bytecode = type(UniswapV2Pair).creationCode;   
    //将token0和token1打包创建哈希作为盐 bytes32 salt = keccak256(abi.encodePacked(token0,token1));
    //内联汇编 assembly 
    //通过create2方法部署合约并且加盐 返回地址到pair变量 pair := create2(0,add(bytecode,32), mload(bytecode), salt);
    //调用pair地址的合约中initialize方法传入token0 token1 IUniswapV2Pair(pair).initialize(token0.token1);
    //存入映射 getpair[][] = pair; getpair[][] = pair; 放入配对数组 allpairs.push(pair); 触发事件 emit PairCreated
    function createPair(address tokenA, address tokenB) external returns (address pair);
    //设置收税员地址 验证msgsender是否是收税员
    function setFeeTo(address) external;
    //设置收税员权限控制地址
    function setFeeToSetter(address) external;
}


// pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    //构造方法确定工厂合约地址
    //
    event Approval(address indexed owner, address indexed spender, uint value);
    //
    event Transfer(address indexed from, address indexed to, uint value);

    //
    function name() external pure returns (string memory);
    //
    function symbol() external pure returns (string memory);
    //
    function decimals() external pure returns (uint8);
    //
    function totalSupply() external view returns (uint);
    //IERC20(token0/token1).balanceOf(address(this));
    function balanceOf(address owner) external view returns (uint);
    //
    function allowance(address owner, address spender) external view returns (uint);
    //
    function approve(address spender, uint value) external returns (bool);
    //
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    //事件：铸造
    event Mint(address indexed sender, uint amount0, uint amount1);
    //事件：销毁
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    //事件： 交换
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    //事件：同步
    event Sync(uint112 reserve0, uint112 reserve1);
    //最小流动性 1000
    function MINIMUM_LIQUIDITY() external pure returns (uint);
    //工厂地址
    function factory() external view returns (address);
    //token0 地址
    function token0() external view returns (address);
    //token1 地址
    function token1() external view returns (address);
    //获取储备 returns： 储备量0 储备量1 时间戳
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    //价格0最后累计
    function price0CumulativeLast() external view returns (uint);
    //价格1最后累计
    function price1CumulativeLast() external view returns (uint);
    //最近一次流动性事件后的k值
    //储备量0*储备量1 最近一次流动性时间发生后
    function kLast() external view returns (uint);
    //铸造 address to：将流动性代币铸造给谁
    //
    function mint(address to) external returns (uint liquidity);
    //销毁
    function burn(address to) external returns (uint amount0, uint amount1);
    //交换
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    //调整方法：强制平衡
    function skim(address to) external;
    //调整方法：强制准备金与余额匹配
    function sync() external;
    //初始化 使用token0 token1地址 require msg.sender == factory 工厂合约调用一次 把token0 token1 分别赋值
    function initialize(address, address) external;
}

// pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}



// pragma solidity >=0.6.2;

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


contract Token is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;
    //root own？
    mapping (address => uint256) private _rOwned;
    //账户拥有量
    mapping (address => uint256) private _tOwned;
    //授权提取额
    mapping (address => mapping (address => uint256)) private _allowances;
    //排除手续费
    mapping (address => bool) private _isExcludedFromFee;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;
    
    mapping (address => bool) private _giantWhale;
    mapping (address => bool) private _giantWhaleOperator;
    mapping (address => uint) private _limitPairTime;
    mapping (address => uint256) private _limitPairNum;

    uint256 private constant MAX = ~uint256(0);
    //totalsupply 9000* 10**12
    uint256 private _tTotal = 9000 * 10**12 * 10**18;

    uint256 private _rTotal = (MAX - (MAX % _tTotal));

    uint256 private _tFeeTotal;
    //ERC20 token name symbol 精度
    string private _name = "TEST";
    string private _symbol = "TT";
    uint8 private _decimals = 18;
    
    address mainAddress = 0x0000000000000000000000000000000000000000;
    //手续费设置
    uint256 public _taxFee = 2;
    uint256 private _previousTaxFee = _taxFee;
    //手续费设置
    uint256 public _poolFeeA = 5;
    uint256 private _previousPoolFeeA = _poolFeeA;
    address public _poolAddressA = 0x0000000000000000000000000000000000000001;
    //手续费设置
    uint256 public _poolFeeB = 0;
    uint256 private _previousPoolFeeB = _poolFeeB;
    address public _poolAddressB = 0x0000000000000000000000000000000000000002;
    //手续费设置
    uint256 public _poolFeeC = 0;
    uint256 private _previousPoolFeeC = _poolFeeC;
    address public _poolAddressC = 0x0000000000000000000000000000000000000003;
    //手续费设置
    uint256 public _liquidityFee = 0;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public _maxPairTate = 1000;
    uint256 public _limitPairNumOf = 20;
    uint public _limitPairTimeOf = 0;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    //flag
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    
    address public _capitalPool;
    
    uint256 public _maxTxAmount = 9000 * 10**12 * 10**18;
    uint256 public numTokensSellToAddToLiquidity = 500 * 10**10 * 10**18;
    
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    //防重入？
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    constructor () public {
        _rOwned[mainAddress] = _rTotal;
        //uniswap路由合约
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
         // Create a uniswap pair for this new token 工厂合约创建pair合约
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        
        //exclude owner and this contract from fee 这个合约和管理者不需要额外的手续费
        _isExcludedFromFee[mainAddress] = true; // 管理者
        _isExcludedFromFee[address(this)] = true; //这个合约
        _giantWhaleOperator[address(this)] = true;
        _isExcluded[_poolAddressA] = true;
        //from，to，value
        emit Transfer(address(0),mainAddress, _tTotal);
        
    }
    //IERC20 name
    function name() public view returns (string memory) {
        return _name;
    }
    //IERC20 symbol
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    //IERC20 decimals
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    //IERC20 totalsupply
    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }
    //IERC20 balanceOf
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }
    //IERC20 transfer
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    //IERC20 allowance
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
        function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true //// 根据takeFee 这个函数负责收取手续费
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(!takeFee) //如果不收费 
            removeAllFee(); //移除所有手续费

        if (_isExcluded[sender] && !_isExcluded[recipient]) { // sender 包含 recipient不包含
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) { // sender 不包含 recipient包含
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) { // sender 不包含 recipient 不包含
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) { // sender 包含 recipient 包含
            _transferBothExcluded(sender, recipient, amount);
        } else {    //其他
            _transferStandard(sender, recipient, amount);
        }
        
        if(takeFee){
          (uint256 tPoolFeeA, uint256 tPoolFeeB, uint256 tPoolFeeC) = _getTPValues(amount);
          _takePool(sender,tPoolFeeA,tPoolFeeB,tPoolFeeC);
        }
        
        if(!takeFee) 
            restoreAllFee(); //要恢复收费
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    
    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    
    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);           
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);        
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner() {
        // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }
    
    
    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }
    
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }
    
    function setTaxFeePercent(uint256 taxFee) external onlyOwner() {
        _taxFee = taxFee;
    }
    
    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner() {
        _liquidityFee = liquidityFee;
    }
    
    function setPoolFeeAPercent(uint256 poolFeeA) external onlyOwner() {
        _poolFeeA = poolFeeA;
    }
    
    function setPoolFeeBPercent(uint256 poolFeeB) external onlyOwner() {
        _poolFeeB = poolFeeB;
    }
    
    function setPoolFeeCPercent(uint256 poolFeeC) external onlyOwner() {
        _poolFeeC = poolFeeC;
    }
    
    function setlimitPairNumOfPercent(uint256 limitPairNumof) external onlyOwner() {
        _limitPairNumOf = limitPairNumof;
    }
    
    function setlimitPairTimeOfPercent(uint256 limitPairTimeOf) external onlyOwner() {
        _limitPairTimeOf = limitPairTimeOf;
    }
   
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(
            10**2
        );
    }
    
    function setNumTokensSellToAddToLiquidity(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = maxTxPercent;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    
    function excludeGiantWhale(address account) public view returns(bool) {
        return _giantWhale[account];
    }
    
    function setGiantWhale(address account) public onlyOwner {
        _giantWhale[account] = true;
    }
    
    function removeGiantWhale(address account) public onlyOwner {
        _giantWhale[account] = false;
    }
    
    function setGiantWhaleOperator(address account) public onlyOwner {
        _giantWhaleOperator[account] = true;
    }
    
    function removeGiantWhaleOperator(address account) public onlyOwner {
        _giantWhaleOperator[account] = false;
    }
    
    function inquireGiantWhaleOperator(address account) public view returns(bool){
        return _giantWhaleOperator[account];
    }
    
    function inquirelimitPairNum(address account) public view returns(uint256){
        return _limitPairNum[account];
    }
    
    function inquirelimitPairTime(address account) public view returns(uint256){
        return _limitPairTime[account];
    }
    
     //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }
    function _getTPValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tPoolFeeA = calculatepoolFeeA(tAmount);
        uint256 tPoolFeeB = calculatepoolFeeB(tAmount);
        uint256 tPoolFeeC = calculatepoolFeeC(tAmount);
        return (tPoolFeeA, tPoolFeeB, tPoolFeeC);
    }
    
    function _getRPValues(uint256 tAmount, uint256 currentRate) private view returns (uint256, uint256, uint256) {
        (uint256 tPoolFeeA, uint256 tPoolFeeB, uint256 tPoolFeeC) = _getTPValues(tAmount);
        uint256 rPoolFeeA = tPoolFeeA.mul(currentRate);
        uint256 rPoolFeeB = tPoolFeeB.mul(currentRate);
        uint256 rPoolFeeC = tPoolFeeC.mul(currentRate);
        return (rPoolFeeA, rPoolFeeB, rPoolFeeC);
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTValues(tAmount);
        (uint256 rAmount, uint256 _rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, _getRate());
        return (rAmount, _rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        (uint256 tPoolFeeA, uint256 tPoolFeeB, uint256 tPoolFeeC) = _getTPValues(tAmount);
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 _tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        uint256 tTransferAmount =_tTransferAmount.sub(tPoolFeeA).sub(tPoolFeeB).sub(tPoolFeeC);
        return (tTransferAmount, tFee, tLiquidity);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 currentRate) private view returns (uint256, uint256, uint256) {
        (uint256 rPoolFeeA, uint256 rPoolFeeB, uint256 rPoolFeeC) = _getRPValues(tAmount,currentRate);
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 _rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        uint256 rTransferAmount = _rTransferAmount.sub(rPoolFeeA).sub(rPoolFeeB).sub(rPoolFeeC);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }
    
    function _takePool(address sender, uint256 tPoolAmoutA, uint256 tPoolAmoutB, uint256 tPoolAmoutC) private {
        uint256 currentRate =  _getRate();

        if(tPoolAmoutA > 0){
            uint256 rPoolAmoutA = tPoolAmoutA.mul(currentRate);
            _rOwned[_poolAddressA] = _rOwned[_poolAddressA].add(rPoolAmoutA);
            if(_isExcluded[_poolAddressA]){
                _tOwned[_poolAddressA] = _tOwned[_poolAddressA].add(tPoolAmoutA);
            }
            emit Transfer(sender, _poolAddressA, tPoolAmoutA);
        }
        
        if(tPoolAmoutB > 0){
            uint256 rPoolAmoutB = tPoolAmoutB.mul(currentRate);    
            _rOwned[_poolAddressB] = _rOwned[_poolAddressB].add(rPoolAmoutB);    
            if(_isExcluded[_poolAddressB]) {
                _tOwned[_poolAddressB] = _tOwned[_poolAddressB].add(tPoolAmoutB);
            }
            emit Transfer(sender, _poolAddressB, tPoolAmoutB);
        }
        
        if(tPoolAmoutC > 0){    
            uint256 rPoolAmoutC = tPoolAmoutC.mul(currentRate);    
            _rOwned[_poolAddressC] = _rOwned[_poolAddressA].add(rPoolAmoutC);    
            if(_isExcluded[_poolAddressC]) {
                _tOwned[_poolAddressC] = _tOwned[_poolAddressC].add(tPoolAmoutC);
            }
            emit Transfer(sender, _poolAddressC, tPoolAmoutC);
        }
    }
    
    
    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(
            10**2
        );
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(
            10**2
        );
    }
    
    function calculatepoolFeeA(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_poolFeeA).div(
            10**2
        );
    }
    
    function calculatepoolFeeB(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_poolFeeB).div(
            10**2
        );
    }
    
    function calculatepoolFeeC(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_poolFeeC).div(
            10**2
        );
    }
    function getMaxCapitalPoolBalance() private view returns (uint256) {
        return balanceOf(_capitalPool).mul(_maxPairTate).div(
            10**3
        );
    }
    
    function setpoolAdressA(address poolAddressA) external onlyOwner() {
        _poolAddressA = poolAddressA;
    }
    
    function setpoolAdressB(address poolAddressB) external onlyOwner() {
        _poolAddressB = poolAddressB;
    }
    
    function setpoolAdressC(address poolAddressC) external onlyOwner() {
        _poolAddressC = poolAddressC;
    }
    
    function setmaxPairTate(uint256 maxPairTate) external onlyOwner() {
        _maxPairTate = maxPairTate;
    }
    
    function setcapitalPool(address capitalPool) external onlyOwner() {
        _capitalPool = capitalPool;
    }
    //移除手续费
    function removeAllFee() private {
        //没有费用直接return
        if(_taxFee == 0 && _liquidityFee == 0 && _poolFeeA == 0 && _poolFeeB == 0 && _poolFeeC == 0) return;
        //previousfees
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousPoolFeeA = _poolFeeA;
        _previousPoolFeeB = _poolFeeB;
        _previousPoolFeeC = _poolFeeC;
        //fees
        _taxFee = 0;
        _liquidityFee = 0;
        _poolFeeA = 0;
        _poolFeeB = 0;
        _poolFeeC = 0;
    }
    //恢复手续费设置
    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _poolFeeA = _previousPoolFeeA;
        _poolFeeB = _previousPoolFeeB;
        _poolFeeC = _previousPoolFeeC;
    }
    
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }
   
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if(from != owner() && to != owner())
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        
        if(contractTokenBalance >= _maxTxAmount)
        {
            contractTokenBalance = _maxTxAmount;
        }
		
        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }
        
        if(_giantWhale[from] || _giantWhale[to] ) {
            if(!_giantWhaleOperator[from] && !_giantWhaleOperator[to]){
                if( getMaxCapitalPoolBalance()> 0 && _capitalPool != address(0)) {
                    _antiGiantWhale(from,to,amount);
                }
            }
        }
        
        
        //indicates if fee should be deducted from transfer
        bool takeFee = true;
        
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }
        
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee);
        
    }    
    
    function _antiGiantWhale(address from, address to, uint256 amount) private {
        
        require( amount < getMaxCapitalPoolBalance(),"Transfer amount exceeds the maxPairTate.");
        address _limitAddress = _giantWhale[from] ? to : from;
        if(_limitPairTime[_limitAddress] < 1) _limitPairTime[_limitAddress] = block.timestamp;
        if(block.timestamp - _limitPairTime[_limitAddress] < _limitPairTimeOf){
            require(_limitPairNum[_limitAddress] < _limitPairNumOf,"The number of transactions exceeds the limit.");    
        }else{
            _limitPairTime[_limitAddress] = block.timestamp;
            _limitPairNum[_limitAddress]  = 0 ;
        }
        _limitPairNum[_limitAddress] = _limitPairNum[_limitAddress] + 1;   
        
       
    }
    
  
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }
    //取出token
    function withdrawStuckTokens(address _token, uint256 _amount) public onlyOwner {
		IERC20(_token).transfer(msg.sender, _amount);
	}
	//取出eth
	function withdrawStuckETH(address payable recipient) public onlyOwner {
		recipient.transfer(address(this).balance);
	}


}