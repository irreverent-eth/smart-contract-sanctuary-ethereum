// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IUniswap.sol";
import "./interfaces/IS1Proxy.sol";
import "./proxies/S1VesperFinanceDAIProxy.sol"; 


interface IVars {
    function getDepositsStopped(uint8 _structIndex) external view returns(bool);
    function getUniswapSlippage(uint8 _structIndex) external view returns(uint8);
    function getFeeCollector(uint8 _structIndex) external view returns(address);
    function vspTokenUniswapFee() external view returns (uint16);
    function swapRouterAddress() external view returns (address);
    function daiAddress() external view returns (address);
    function wethAddress() external view returns (address);
    function vPoolDAI() external view returns (address);
    function vPoolRewardsDAI() external view returns (address);
    function vspToken() external view returns (address);
    function validateWhitelistedDepositCurrencyFee(uint8 _structIndex, address _token) external view returns(bool);
    function getWhitelistedDepositCurrencyFee(uint8 _structIndex, address _token) external view returns(uint16);
    function calcWithdrawFeeBasedOnTokenOrNFT(uint256 _amount, address _address, address _feeToken, address _feeNFT, uint256 _nftID) external view returns (uint256);
}


contract S1VesperFinanceDAI {
    address public varsA;
    address private swapRouterAddress;
    address private wethAddress;
    address private daiAddress;
    mapping(address => address) public depositors; 

    constructor(
        address _varsA
    ) payable {
        varsA = _varsA;
        swapRouterAddress = IVars(varsA).swapRouterAddress();
        wethAddress = IVars(varsA).wethAddress();
        daiAddress = IVars(varsA).daiAddress();

        IERC20(wethAddress).approve(swapRouterAddress, 2**256 - 1);
        IERC20(IVars(varsA).vspToken()).approve(swapRouterAddress, 2**256 - 1);
    }

    event Deposit(address indexed _depositor, address indexed _token, uint256 _amountIn, uint256 _amountOut);

    event Withdraw(address indexed _depositor, address indexed _token, uint256 _amount, uint256 _fee);

    event ClaimAdditionalTokens(address indexed _depositor, uint256 _amount0, uint256 _amount1, address indexed _swappedTo);

    function depositETH(uint256 tokenAmountOut) public payable {
        require(!IVars(varsA).getDepositsStopped(4), "ERR: DEPOSITS_STOPPED");
        uint16 daiUniswapFee = IVars(varsA).getWhitelistedDepositCurrencyFee(4, daiAddress);

        // Swap msg.value for DAI at Uniswap
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn : wethAddress,
            tokenOut : daiAddress,
            fee : daiUniswapFee,
            recipient : address(this),
            amountIn : msg.value,
            amountOutMinimum : (tokenAmountOut * (100 - IVars(varsA).getUniswapSlippage(4))) / 100,
            sqrtPriceLimitX96 : 0
        });
        uint256 daiAmount = ISwapRouter(swapRouterAddress).exactInputSingle{value : msg.value}(params);
        _yieldDeposit(daiAmount);

        emit Deposit(msg.sender, wethAddress, msg.value, daiAmount);
    }

    function depositTokens(address _token, uint256 _amount, uint256 wethAmountOut, uint256 tokenAmountOut) external {
        require(!IVars(varsA).getDepositsStopped(4), "ERR: DEPOSITS_STOPPED");
        require(IVars(varsA).validateWhitelistedDepositCurrencyFee(4, _token), "ERR: INVALID_DEPOSIT_TOKEN");
        require(IERC20(_token).transferFrom(msg.sender, address(this), _amount), "ERR: INVALID_TRANSFER_FROM");

        uint256 daiAmount;
        if (_token != daiAddress) {
            // approve Uniswap router ONLY if needed
            if (IERC20(_token).allowance(address(this), swapRouterAddress) == 0) {
                IERC20(_token).approve(swapRouterAddress, 2**256 - 1);
            }

            uint16 tokenUniswapFee = IVars(varsA).getWhitelistedDepositCurrencyFee(4, _token);
            uint16 daiUniswapFee = IVars(varsA).getWhitelistedDepositCurrencyFee(4, daiAddress);
            uint16 uniswapSlippage = IVars(varsA).getUniswapSlippage(4);

            bytes[] memory uniswapCalls = new bytes[](2);
            uniswapCalls[0] = _getEncodedSingleSwap(
                _token,
                wethAddress,
                tokenUniswapFee,
                _amount,
                (wethAmountOut * (100 - uniswapSlippage)) / 100
            );

            uniswapCalls[1] = _getEncodedSingleSwap(
                wethAddress,
                daiAddress,
                daiUniswapFee,
                wethAmountOut,
                (tokenAmountOut * (100 - uniswapSlippage)) / 100
            );
            (bytes[] memory results) = ISwapRouter(swapRouterAddress).multicall(uniswapCalls);
            daiAmount = abi.decode(results[1], (uint256));  
        } else {
            daiAmount = _amount;
        }
        _yieldDeposit(daiAmount);
 
        emit Deposit(msg.sender, _token, _amount, daiAmount);
    }

    function _yieldDeposit(uint256 _amount) internal {
        if (depositors[msg.sender] == address(0)) {
            // deploy new proxy contract
            S1VesperFinanceDAIProxy s1proxy = new S1VesperFinanceDAIProxy(
                address(this),
                varsA,
                daiAddress
            );
            depositors[msg.sender] = address(s1proxy);
            IERC20(daiAddress).approve(depositors[msg.sender], 2**256 - 1);
            s1proxy.deposit(_amount); 
        } else {
            // send the deposit to the existing proxy contract
            if (IERC20(daiAddress).allowance(address(this), depositors[msg.sender]) == 0) {
                IERC20(daiAddress).approve(depositors[msg.sender], 2**256 - 1); 
            }

            IS1Proxy(depositors[msg.sender]).deposit(_amount);  
        }
    }

    function _getEncodedSingleSwap(address _tokenIn, address _tokenOut, uint16 _fee, uint256 _amountIn, uint256 _amountOutMinimum) internal view returns(bytes memory) {
        return abi.encodeWithSelector(
            ISwapRouter.exactInputSingle.selector,
            ISwapRouter.ExactInputSingleParams({
            tokenIn : _tokenIn,
            tokenOut : _tokenOut,
            fee : _fee,
            recipient : address(this),
            amountIn : _amountIn,
            amountOutMinimum : _amountOutMinimum,
            sqrtPriceLimitX96 : 0
            })
        );
    }

    // Get current unclaimed additional tokens amount
    function getPendingAdditionalTokenClaims(address _address) external view returns(address[] memory _rewardTokens, uint256[] memory _claimableAmounts) {
        return IVPoolRewards(IVars(varsA).vPoolRewardsDAI()).claimable(_address);
    } 
    
    // Get current stake
    function getCurrentDeposit(address _address) external view returns(uint256) {
        uint256 vaDAIShare = IERC20(IVars(varsA).vPoolDAI()).balanceOf(_address);
        uint256 pricePerShare = IVPoolDAI(IVars(varsA).vPoolDAI()).pricePerShare();
        uint256 daiEquivalent = (pricePerShare * vaDAIShare) / 1 ** 18;
        return daiEquivalent;
    }

    // claim VSP tokens and withdraw them
    function claimRaw() external {
        require(depositors[msg.sender] != address(0), "ERR: INVALID_DEPOSITOR");
        uint256 vspTokens = IS1Proxy(depositors[msg.sender]).claimToDepositor(msg.sender); 

        emit ClaimAdditionalTokens(msg.sender, vspTokens, 0, address(0));
    }

    // claim VSP tokens, swap them for ETH and withdraw
    function claimInETH(uint256 wethAmountOut) external {
        require(depositors[msg.sender] != address(0), "ERR: INVALID_DEPOSITOR");
        uint256 vspTokens = IS1Proxy(depositors[msg.sender]).claimToDeployer(); 
        address vspTokenAddress = IVars(varsA).vspToken();
        uint16 vspTokenUniswapFee = IVars(varsA).vspTokenUniswapFee();

        // swap DAI for WETH
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn : vspTokenAddress,
            tokenOut : wethAddress,
            fee : vspTokenUniswapFee,
            recipient : address(this),
            amountIn : vspTokens,
            amountOutMinimum : (wethAmountOut * (100 - IVars(varsA).getUniswapSlippage(4))) / 100,
            sqrtPriceLimitX96 : 0
        });
        uint256 wethAmount = ISwapRouter(swapRouterAddress).exactInputSingle(params);

        // swap WETH for ETH
        IWETH(wethAddress).withdraw(wethAmount);
        // withdraw ETH
        payable(msg.sender).transfer(wethAmount);

        emit ClaimAdditionalTokens(msg.sender, vspTokens, wethAmount, wethAddress);
    }

    // claim VSP tokens, swap them for _token and withdraw
    function claimInToken(address _token, uint256 wethAmountOut, uint256 tokenAmountOut) external {
        require(depositors[msg.sender] != address(0), "ERR: INVALID_DEPOSITOR");

        uint256 vspTokens = IS1Proxy(depositors[msg.sender]).claimToDeployer(); 
        bytes[] memory uniswapCalls;
        uint8 uniswapSlippage = IVars(varsA).getUniswapSlippage(4); 
        address vspTokenAddress = IVars(varsA).vspToken();
        uint16 vspTokenUniswapFee = IVars(varsA).vspTokenUniswapFee();

        // swap the VSP tokens for WETH
        uniswapCalls[0] = _getEncodedSingleSwap(
            vspTokenAddress,
            wethAddress,
            vspTokenUniswapFee,
            vspTokens,
            (wethAmountOut * (100 - uniswapSlippage)) / 100
        );

        // swap the WETH from VSP swaps into the token last used for deposit
        uniswapCalls[1] = _getEncodedSingleSwap(
            wethAddress,
            _token,
            IVars(varsA).getWhitelistedDepositCurrencyFee(4, _token),
            wethAmountOut,
            (tokenAmountOut * (100 - uniswapSlippage)) / 100
        );

        (bytes[] memory results) = ISwapRouter(swapRouterAddress).multicall(uniswapCalls);

        IERC20(_token).transfer(
            msg.sender,
            abi.decode(results[1], (uint256))
        );

        emit ClaimAdditionalTokens(msg.sender, vspTokens, abi.decode(results[1], (uint256)), _token);
    }

    function withdrawETH(uint256 _vaDAIAmount, uint256 wethAmountOut, address _feeToken, address _feeNFT, uint256 _nftID) external {
        require(depositors[msg.sender] != address(0), "ERR: INVALID_DEPOSITOR");
        (uint256 yieldDeposit, uint256 fee) = _withdrawYieldDeposit(_vaDAIAmount, _feeToken, _feeNFT, _nftID);

        if (IERC20(daiAddress).allowance(address(this), swapRouterAddress) == 0) {
            IERC20(daiAddress).approve(swapRouterAddress, 2**256 - 1);
        }

        // swap DAI for WETH
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn : daiAddress,
            tokenOut : wethAddress,
            fee : IVars(varsA).getWhitelistedDepositCurrencyFee(4, daiAddress),
            recipient : address(this),
            amountIn : yieldDeposit - fee,
            amountOutMinimum : (wethAmountOut * (100 - IVars(varsA).getUniswapSlippage(4))) / 100,
            sqrtPriceLimitX96 : 0
        });
        uint256 wethAmount = ISwapRouter(swapRouterAddress).exactInputSingle(params);

        // swap WETH for ETH
        IWETH(wethAddress).withdraw(wethAmount); 
        // withdraw ETH
        payable(msg.sender).transfer(wethAmount);

        emit Withdraw(msg.sender, wethAddress, wethAmount, fee);
    }

    function withdrawToken(address _token, uint256 _vaDAIAmount, uint256 wethAmountOut, uint256 tokenAmountOut, address _feeToken, address _feeNFT, uint256 _nftID) external {
        require(depositors[msg.sender] != address(0), "ERR: INVALID_DEPOSITOR");
        (uint256 yieldDeposit, uint256 fee) = _withdrawYieldDeposit(_vaDAIAmount, _feeToken, _feeNFT, _nftID);
        if (_token == daiAddress) { 
            // withdraw DAI
            IERC20(daiAddress).transfer(
                msg.sender,
                yieldDeposit - fee
            );

            emit Withdraw(msg.sender, daiAddress, yieldDeposit - fee, fee);
        } else {
            if (IERC20(daiAddress).allowance(address(this), swapRouterAddress) == 0) {
                IERC20(daiAddress).approve(swapRouterAddress, 2**256 - 1);
            }

            bytes[] memory uniswapCalls = new bytes[](2);
            // swap DAI for WETH
            uniswapCalls[0] = _getEncodedSingleSwap(
                daiAddress,  
                wethAddress,
                IVars(varsA).getWhitelistedDepositCurrencyFee(4, daiAddress),
                yieldDeposit - fee,
                (wethAmountOut * (100 - IVars(varsA).getUniswapSlippage(4))) / 100
            );

            // swap WETH for _token
            uniswapCalls[1] = _getEncodedSingleSwap(
                wethAddress,
                _token,
                IVars(varsA).getWhitelistedDepositCurrencyFee(4, _token),
                wethAmountOut,
                (tokenAmountOut * (100 - IVars(varsA).getUniswapSlippage(4))) / 100
            );
            (bytes[] memory results) = ISwapRouter(swapRouterAddress).multicall(uniswapCalls);

            IERC20(_token).transfer(
                msg.sender,
                abi.decode(results[1], (uint256))
            );

            emit Withdraw(msg.sender, _token, abi.decode(results[1], (uint256)), fee); 
        }
    }

    function _withdrawYieldDeposit(uint256 _vaDAIAmount, address _feeToken, address _feeNFT, uint256 _nftID) private returns(uint256, uint256) {
        uint256 daiAmountToBeWithdrawn = IS1Proxy(depositors[msg.sender]).withdraw(_vaDAIAmount); 
        require(IERC20(daiAddress).transferFrom(depositors[msg.sender], address(this), daiAmountToBeWithdrawn), "ERR: INVALID_TRANSFER_FROM");
        
        // if fee then send it to the feeCollector 
        uint256 fee = (daiAmountToBeWithdrawn * IVars(varsA).calcWithdrawFeeBasedOnTokenOrNFT(daiAmountToBeWithdrawn, msg.sender, _feeToken, _feeNFT, _nftID)) / 1000;
        if (fee > 0) {
            IERC20(daiAddress).transfer(
                IVars(varsA).getFeeCollector(4), 
                fee
            );
        }
        return (daiAmountToBeWithdrawn, fee);
    }

    receive() external payable {}
}

// MN bby ¯\_(ツ)_/¯

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ISwapRouter {
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);

    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}


interface IQuoter {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IWETH {
    function withdraw(uint wad) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IERC20 {
    function balanceOf(address _owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IS1Proxy {
    function deposit(uint256 _deposit) external;
    function depositETH() external payable;
    function withdraw(uint256 _amount) external returns(uint256);
    function claimToDepositor(address _depositor) external returns(uint256);
    function claimToDeployer() external returns(uint256);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../interfaces/IERC20.sol";
import "../interfaces/IVesperFinance.sol";


interface IVarsP {
    function vPoolDAI() external view returns (address);
    function vPoolRewardsDAI() external view returns (address);
    function vspToken() external view returns (address);
}


contract S1VesperFinanceDAIProxy {
    address public deployer;
    address private varsA;
    address private daiAddress;

    constructor(
        address _deployer,
        address _varsA,
        address _daiAddress
    ) payable {
        varsA = _varsA;
        deployer = _deployer;
        daiAddress = _daiAddress;

        IERC20(daiAddress).approve(_deployer, 2**256 - 1);
        IERC20(daiAddress).approve(IVarsP(varsA).vPoolDAI(), 2**256 - 1);
    }

    modifier onlyDeployer() {
        require(msg.sender == deployer, "ERR: WRONG_DEPLOYER");
        _;
    } 

    function deposit(uint256 _amount) external onlyDeployer {
        require(IERC20(daiAddress).transferFrom(deployer, address(this), _amount), "ERR: INVALID_TRANSFER_FROM");

        // Vesper Finance deposit
        IVPoolDAI(IVarsP(varsA).vPoolDAI()).deposit(_amount);
    }

    function withdraw(uint256 _amount) external onlyDeployer returns(uint256) {
        IVPoolDAI(IVarsP(varsA).vPoolDAI()).withdraw(_amount);

        return IERC20(daiAddress).balanceOf(address(this));
    }

    function claimToDepositor(address _depositor) external onlyDeployer returns(uint256) {
        return _claim(_depositor);
    }

    function claimToDeployer() external onlyDeployer returns(uint256) {
        return _claim(deployer);
    }

    function _claim(address _address) private returns(uint256) {
        // VSP tokens
        IVPoolRewards(IVarsP(varsA).vPoolRewardsDAI()).claimReward(address(this));

        uint256 vspBalance = IERC20(IVarsP(varsA).vspToken()).balanceOf(address(this));
        IERC20(IVarsP(varsA).vspToken()).transfer(
            _address,
            vspBalance
        );

        return vspBalance;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IVPoolDAI {
    function deposit(uint256 _amount) external;

    function withdraw(uint256 _shares) external;

    function pricePerShare() external view returns (uint256);
}


interface IVPoolETH {
    function deposit() external payable;

    function withdrawETH(uint256 _shares) external;

    function pricePerShare() external view returns (uint256);
}


interface IVPoolRewards {
    function claimable(address _account) external view returns (
        address[] memory _rewardTokens,
        uint256[] memory _claimableAmounts
    );

    function claimReward(address _account) external;
}