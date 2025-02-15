/**
 *Submitted for verification at Etherscan.io on 2022-09-21
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20 {

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

pragma solidity ^0.8.0;

library SafeMath {

    function tryAdd(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        unchecked {

            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

pragma solidity ^0.8.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

pragma solidity ^0.8.0;

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

pragma solidity ^0.8.1;

library Address {

    function isContract(address account) internal view returns (bool) {

        return account.code.length > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    function functionCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(
                target,
                data,
                value,
                "Address: low-level call with value failed"
            );
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(
            address(this).balance >= value,
            "Address: insufficient balance for call"
        );
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data)
        internal
        view
        returns (bytes memory)
    {
        return
            functionStaticCall(
                target,
                data,
                "Address: low-level static call failed"
            );
    }

    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionDelegateCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return
            functionDelegateCall(
                target,
                data,
                "Address: low-level delegate call failed"
            );
    }

    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
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

pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint) external view returns (address pair);

    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender)
        external
        view
        returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint);

    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(
        address indexed sender,
        uint amount0,
        uint amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint);

    function price1CumulativeLast() external view returns (uint);

    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);

    function burn(address to) external returns (uint amount0, uint amount1);

    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

pragma solidity >=0.6.2;

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
    )
        external
        returns (
            uint amountA,
            uint amountB,
            uint liquidity
        );

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (
            uint amountToken,
            uint amountETH,
            uint liquidity
        );

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
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
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

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB);

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn);

    function getAmountsOut(uint amountIn, address[] calldata path)
        external
        view
        returns (uint[] memory amounts);

    function getAmountsIn(uint amountOut, address[] calldata path)
        external
        view
        returns (uint[] memory amounts);
}

// File contracts/IUniswapV2Router02.sol

pragma solidity >=0.6.2;

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
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
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


pragma solidity 0.8.13;

contract TEST1 is IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;

    mapping(address => bool) private _isExcludedFromRewards;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 public startSupply = 1e6 * 10**18;
    uint256 private _tTotal = 1e6 * 10**18;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
    address private constant deadAddress = address(0xdead);

    string private _name = "TEST1";
    string private _symbol = "TEST1";
    uint8 private _decimals = 18;

    uint256 public _reflectionFee = 1;
    uint256 private _previousReflectionFee = _reflectionFee;

    uint256 public _burnFee = 2;
    uint256 private _previousBurnFee = _burnFee;

    uint256 public _buybackFee = 2;
    uint256 private _previousBuybackFee = _buybackFee;

    uint256 public _liqFee = 1;
    uint256 private _previousLiqFee = _liqFee;

    uint256 public _sellReflectionFee = 1;
    uint256 private _previousSellReflectionFee = _sellReflectionFee;

    uint256 public _sellBurnFee = 4;
    uint256 private _previousSellBurnFee = _sellBurnFee;

    uint256 public _sellBuybackFee = 2;
    uint256 private _previousSellBuybackFee = _sellBuybackFee;

    uint256 public _sellLiqFee = 1;
    uint256 private _previousSellLiqFee = _sellLiqFee;

    uint256 public _totalBuyFee = _reflectionFee + _burnFee + _buybackFee + _liqFee;
    uint256 public _totalSellFee = _sellReflectionFee + _sellBurnFee + _sellBuybackFee + _sellLiqFee;

    uint256 private _feeDenominator = 100;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    bool inSwap;
    bool public swapEnabled = true;

    uint256 public _maxTxAmount = (_tTotal * 1) / 100; //1%
    uint256 private numTokensSellToAddToLiquidityAndDev =
        (_tTotal * 10) / 100000; //0.01%

    address private dev = 0xd07b5a6819afA155E74c28c72fe30db926be6152;

    struct TValues {
        uint256 tTransferAmount;
        uint256 tReflection;
        uint256 tBuyback;
        uint256 tBurn;
        uint256 tLiq;
    }
    struct RValues {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rReflection;
        uint256 rBuyback;
        uint256 rBurn;
        uint256 rLiq;
    }

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapEnabledUpdated(bool enabled);
    event Swap(uint256 tokensSwapped, uint256 forBuyback, uint256 forLiq);
    event Burn(uint256 amount, uint256 newSupply);
    event Liquidity(uint256 amount);

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() {
        _rOwned[_msgSender()] = _rTotal;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[address(0xdead)] = true;
        excludeFromReward(uniswapV2Pair);
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcludedFromRewards[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcludedFromRewards[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(
            !_isExcludedFromRewards[sender],
            "Excluded addresses cannot call this function"
        );
        (, RValues memory rValues) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rValues.rAmount);
        _rTotal = _rTotal.sub(rValues.rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (, RValues memory rValues) = _getValues(tAmount);
            return rValues.rAmount;
        } else {
            (, RValues memory rValues) = _getValues(tAmount);
            return rValues.rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner {
        // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
        require(
            !_isExcludedFromRewards[account],
            "Account is already excluded"
        );
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcludedFromRewards[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcludedFromRewards[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcludedFromRewards[account] = false;
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

    function setBurnFeePercent(uint256 burnFee) external onlyOwner {
        _burnFee = burnFee;
    }

    function setBuybackFeePercent(uint256 buybackFee) external onlyOwner {
        _buybackFee = buybackFee;
    }

    function setReflectionFeePercent(uint256 reflectionFee) external onlyOwner {
        _reflectionFee = reflectionFee;
    }

    function setLiquidityFeePercent(uint256 liqFee) external onlyOwner {
        _liqFee = liqFee;
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(10**2);
    }

    function setSwapPercent(uint256 maxSwapPercent) external onlyOwner {
        numTokensSellToAddToLiquidityAndDev = _tTotal.mul(maxSwapPercent).div(
            10**5
        );
    }

    function setSwapEnabled(bool _enabled) public onlyOwner {
        swapEnabled = _enabled;
        emit SwapEnabledUpdated(_enabled);
    }

    function setBuybackAddress(address _dev) external onlyOwner {
        dev = _dev;
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (TValues memory tValues, RValues memory rValues)
    {
        tValues = _getTValues(tAmount);
        rValues = _getRValues(tAmount, tValues, _getRate());
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (TValues memory tValues)
    {
        tValues.tReflection = calculateReflectionFee(tAmount);
        tValues.tBuyback = calculateBuybackFee(tAmount);
        tValues.tBurn = calculateBurnFee(tAmount);
        tValues.tLiq = calculateLiqFee(tAmount);
        tValues.tTransferAmount = tAmount
            .sub(tValues.tReflection)
            .sub(tValues.tBuyback)
            .sub(tValues.tBurn)
            .sub(tValues.tLiq);
    }

    function _getRValues(
        uint256 tAmount,
        TValues memory tValues,
        uint256 currentRate
    ) private pure returns (RValues memory rValues) {
        rValues.rAmount = tAmount.mul(currentRate);
        rValues.rReflection = tValues.tReflection.mul(currentRate);
        rValues.rBuyback = tValues.tBuyback.mul(currentRate);
        rValues.rBurn = tValues.tBurn.mul(currentRate);
        rValues.rLiq = tValues.tLiq.mul(currentRate);
        rValues.rTransferAmount = rValues
            .rAmount
            .sub(rValues.rReflection)
            .sub(rValues.rBuyback)
            .sub(rValues.rBurn)
            .sub(rValues.rLiq);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidityAndBuyback(uint256 tLiquidity, uint256 tBuyback) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rBuyback = tBuyback.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity).add(
            rBuyback
        );
        if (_isExcludedFromRewards[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity).add(
                tBuyback
            );
    }

    function calculateReflectionFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return _amount.mul(_reflectionFee).div(10**2);
    }

    function calculateBuybackFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_buybackFee).div(10**2);
    }

    function calculateBurnFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_burnFee).div(10**2);
    }

    function calculateLiqFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liqFee).div(10**2);
    }

    function removeAllFee() private {
        if (_reflectionFee == 0 && _buybackFee == 0 && _burnFee == 0) return;

        _previousReflectionFee = _reflectionFee;
        _previousBurnFee = _burnFee;
        _previousBuybackFee = _buybackFee;
        _previousLiqFee = _liqFee;
        _previousSellReflectionFee = _sellReflectionFee;
        _previousSellBurnFee = _sellBurnFee;
        _previousSellBuybackFee = _sellBuybackFee;
        _previousSellLiqFee = _sellLiqFee;

        _buybackFee = 0;
        _burnFee = 0;
        _reflectionFee = 0;
        _liqFee = 0;
        _sellBuybackFee = 0;
        _sellBurnFee = 0;
        _sellReflectionFee = 0;
        _sellLiqFee = 0;
    }

    function restoreAllFee() private {
        _buybackFee = _previousBuybackFee;
        _burnFee = _previousBurnFee;
        _reflectionFee = _previousReflectionFee;
        _liqFee = _previousLiqFee;
        _sellBurnFee = _previousSellBuybackFee;
        _sellBurnFee = _previousSellBurnFee;
        _sellReflectionFee = _previousSellReflectionFee;
        _sellLiqFee = _previousSellLiqFee;
    }

    function setBuyFees(uint256 reflectionFee, uint256 burnFee, uint256 buybackFee, uint256 liqFee, uint256 feeDenominator) external onlyOwner {
        _reflectionFee      = reflectionFee;
        _burnFee            = burnFee;
        _buybackFee         = buybackFee;
        _liqFee             = liqFee;
        _totalBuyFee         = reflectionFee.add(burnFee).add(buybackFee).add(liqFee);
        _feeDenominator      = feeDenominator;
        require(_totalBuyFee < _feeDenominator/12, "Fees cannot be more than 6%");
    }

    function setSellFees(uint256 sellReflectionFee, uint256 sellBurnFee, uint256 sellBuybackFee, uint256 sellLiqFee, uint256 feeDenominator) external onlyOwner {
        _sellReflectionFee  = sellReflectionFee;
        _sellBurnFee        = sellBurnFee;
        _sellBuybackFee     = sellBuybackFee;
        _sellLiqFee         = sellLiqFee;

        _totalSellFee        = sellReflectionFee.add(sellBurnFee).add(sellBuybackFee).add(sellLiqFee);
        _feeDenominator      = feeDenominator;
        require(_totalSellFee < _feeDenominator/16, "Fees cannot be more than 8%");
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
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
        if (from != owner() && to != owner())
            require(
                amount <= _maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );

        uint256 contractTokenBalance = balanceOf(address(this));

        if (contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }
        bool overMinTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidityAndDev;
        if (
            overMinTokenBalance &&
            !inSwap &&
            from != uniswapV2Pair &&
            swapEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidityAndDev;
            //add liquidity and dev fees
            swap(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function _burn(uint256 tBurn, uint256 rBurn) internal {
        _rOwned[deadAddress] += rBurn;
        emit Burn(tBurn, _tTotal);
    }

    function _addLiquidity(uint256 _tLiq) internal {
        uint256 currentRate = _getRate();
        uint256 _rLiq = _tLiq.mul(currentRate);
        _rOwned[uniswapV2Pair] += _rLiq;
        _tOwned[uniswapV2Pair] += _tLiq;
        emit Liquidity(_tLiq);
    }

    function swap(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance

        uint forBuyback = contractTokenBalance.mul(_buybackFee).div(_buybackFee + _liqFee);
        uint256 forLiq = contractTokenBalance.sub(forBuyback);
        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract

        // add liquidity to uniswap
        if (forLiq > 0) {
            _addLiquidity(forLiq);
        }
        // emit Swap(half, newBalance, otherHalf);
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

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();

        if (
            _isExcludedFromRewards[sender] && !_isExcludedFromRewards[recipient]
        ) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (
            !_isExcludedFromRewards[sender] && _isExcludedFromRewards[recipient]
        ) {
            _transferToExcluded(sender, recipient, amount);
        } else if (
            !_isExcludedFromRewards[sender] &&
            !_isExcludedFromRewards[recipient]
        ) {
            _transferStandard(sender, recipient, amount);
        } else if (
            _isExcludedFromRewards[sender] && _isExcludedFromRewards[recipient]
        ) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee) restoreAllFee();
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (TValues memory tValues, RValues memory rValues) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rValues.rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rValues.rTransferAmount);
        _takeLiquidityAndBuyback(tValues.tLiq, tValues.tBuyback);
        _burn(tValues.tBurn, rValues.rBurn);
        _reflectFee(rValues.rReflection, tValues.tReflection);
        emit Transfer(sender, recipient, tValues.tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (TValues memory tValues, RValues memory rValues) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rValues.rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tValues.tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rValues.rTransferAmount);
        _takeLiquidityAndBuyback(tValues.tLiq, tValues.tBuyback);
        _burn(tValues.tBurn, rValues.rBurn);
        _reflectFee(rValues.rReflection, tValues.tReflection);
        emit Transfer(sender, recipient, tValues.tTransferAmount);
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (TValues memory tValues, RValues memory rValues) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rValues.rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rValues.rTransferAmount);
        _takeLiquidityAndBuyback(tValues.tLiq, tValues.tBuyback);
        _burn(tValues.tBurn, rValues.rBurn);
        _reflectFee(rValues.rReflection, tValues.tReflection);
        emit Transfer(sender, recipient, tValues.tTransferAmount);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (TValues memory tValues, RValues memory rValues) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rValues.rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tValues.tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rValues.rTransferAmount);
        _takeLiquidityAndBuyback(tValues.tLiq, tValues.tBuyback);
        _burn(tValues.tBurn, rValues.rBurn);
        _reflectFee(rValues.rReflection, tValues.tReflection);
        emit Transfer(sender, recipient, tValues.tTransferAmount);
    }
}