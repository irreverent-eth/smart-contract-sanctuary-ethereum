// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../lib/Ownable.sol";
import "../lib/SafeMath.sol";
import "../lib/ERC20.sol";

interface IEthStaking {
    function accountLpInfos(address, address)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );
}

interface IEthExternalStaking {
    function balanceOf(address) external view returns (uint256);
}

contract Info is Ownable {
    using SafeMath for uint256;

    uint256[] private devFeePercentage = [5, 2, 2];
    uint256[] private minDevFeeInWei = [0, 0, 0];
    address[] private presaleAddresses; // track all presales created

    mapping(address => uint256) private minInvestorBalance; // min amount to investors HODL BSCS balance
    mapping(address => uint256) private minInvestorGuaranteedBalance;

    uint256 private minStakeTime = 1 minutes;
    uint256 private minUnstakeTime = 3 days;
    uint256 private creatorUnsoldClaimTime = 3 days;

    address[] private swapRouters = [
        address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)
    ]; // Array of Routers
    address[] private swapFactorys = [
        address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f)
    ]; // Array of Factorys

    mapping(address => bytes32) private initCodeHash; // Mapping of INIT_CODE_HASH

    mapping(address => address) private lpAddresses; // TOKEN + START Pair Addresses

    address private weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address private factoryAddress;

    mapping(address => uint256) private investmentLimit;
    mapping(address => bool) private devs;

    address private lockingAddress =
        address(0x0000000000000000000000000000000000000000);

    mapping(address => uint256) private minYesVotesThreshold; // minimum number of yes votes needed to pass

    mapping(address => uint256) private minCreatorStakedBalance;

    mapping(address => bool) private blacklistedAddresses;

    mapping(address => bool) public auditorWhitelistedAddresses; // addresses eligible to perform audits

    IEthStaking public stakingPool;
    IEthExternalStaking public externalStaking;

    uint256 private devPresaleTokenFee = 2;
    address private devPresaleAllocationAddress =
        address(0x0000000000000000000000000000000000000000);
    uint256 private presaleCreationFee = 1 ether;

    constructor(address _stakingPool, address _externalStaking) public {
        stakingPool = IEthStaking(_stakingPool);
        externalStaking = IEthExternalStaking(_externalStaking);

        initCodeHash[
            address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f)
        ] = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f; // Uniswap V2 INIT_CODE_HASH

        lpAddresses[weth] = address(0xa0558Bec506FC36F84e93883CaA57B96d598C153); // WETH -> LP Addresses

        minYesVotesThreshold[weth] = 1000 * 1e18;

        minInvestorBalance[weth] = 3.5 * 1e18;

        minInvestorGuaranteedBalance[weth] = 35 * 1e18;

        investmentLimit[weth] = 1000 * 1e18;

        minCreatorStakedBalance[weth] = 3.5 * 1e18;
    }

    modifier onlyFactory() {
        require(
            factoryAddress == msg.sender ||
                owner == msg.sender ||
                devs[msg.sender],
            "onlyFactoryOrDev"
        );
        _;
    }

    modifier onlyDev() {
        require(owner == msg.sender || devs[msg.sender], "onlyDev");
        _;
    }

    function getCakeV2LPAddress(
        address tokenA,
        address tokenB,
        uint256 swapIndex
    ) public view returns (address pair) {
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        pair = address(
            uint256(
                keccak256(
                    abi.encodePacked(
                        hex"ff",
                        swapFactorys[swapIndex],
                        keccak256(abi.encodePacked(token0, token1)),
                        initCodeHash[swapFactorys[swapIndex]] // init code hash
                    )
                )
            )
        );
    }

    function getDev(address _dev) external view returns (bool) {
        return devs[_dev];
    }

    function setDevAddress(address _newDev) external onlyOwner {
        devs[_newDev] = true;
    }

    function removeDevAddress(address _oldDev) external onlyOwner {
        devs[_oldDev] = false;
    }

    function getFactoryAddress() external view returns (address) {
        return factoryAddress;
    }

    function setFactoryAddress(address _newFactoryAddress) external onlyDev {
        factoryAddress = _newFactoryAddress;
    }

    function getStakingPool() external view returns (address) {
        return address(stakingPool);
    }

    function setStakingPool(address _stakingPool) external onlyDev {
        stakingPool = IEthStaking(_stakingPool);
    }

    function setExternalStaking(address _externalStaking) external onlyDev {
        externalStaking = IEthExternalStaking(_externalStaking);
    }

    function addPresaleAddress(address _presale)
        external
        onlyFactory
        returns (uint256)
    {
        presaleAddresses.push(_presale);
        return presaleAddresses.length - 1;
    }

    function getPresalesCount() external view returns (uint256) {
        return presaleAddresses.length;
    }

    function getPresaleAddress(uint256 bscsId) external view returns (address) {
        return presaleAddresses[bscsId];
    }

    function setPresaleAddress(uint256 bscsId, address _newAddress)
        external
        onlyDev
    {
        presaleAddresses[bscsId] = _newAddress;
    }

    function getPresaleFee() external view returns (uint256) {
        return presaleCreationFee;
    }

    function setPresaleFee(uint256 _newFee) external onlyDev {
        presaleCreationFee = _newFee;
    }

    function getDevFeePercentage(uint256 presaleType)
        external
        view
        returns (uint256)
    {
        return devFeePercentage[presaleType];
    }

    function setDevFeePercentage(uint256 presaleType, uint256 _devFeePercentage)
        external
        onlyDev
    {
        devFeePercentage[presaleType] = _devFeePercentage;
    }

    function getMinDevFeeInWei(uint256 presaleType)
        external
        view
        returns (uint256)
    {
        return minDevFeeInWei[presaleType];
    }

    function setMinDevFeeInWei(uint256 presaleType, uint256 _fee)
        external
        onlyDev
    {
        minDevFeeInWei[presaleType] = _fee;
    }

    function getMinInvestorBalance(address tokenAddress)
        external
        view
        returns (uint256)
    {
        return minInvestorBalance[tokenAddress];
    }

    function setMinInvestorBalance(
        address tokenAddress,
        uint256 _minInvestorBalance
    ) external onlyDev {
        minInvestorBalance[tokenAddress] = _minInvestorBalance;
    }

    function getMinYesVotesThreshold(address tokenAddress)
        external
        view
        returns (uint256)
    {
        return minYesVotesThreshold[tokenAddress];
    }

    function setMinYesVotesThreshold(
        address tokenAddress,
        uint256 _minYesVotesThreshold
    ) external onlyDev {
        minYesVotesThreshold[tokenAddress] = _minYesVotesThreshold;
    }

    function getMinCreatorStakedBalance(address fundingTokenAddress)
        external
        view
        returns (uint256)
    {
        return minCreatorStakedBalance[fundingTokenAddress];
    }

    function setMinCreatorStakedBalance(
        address fundingTokenAddress,
        uint256 _minCreatorStakedBalance
    ) external onlyDev {
        minCreatorStakedBalance[fundingTokenAddress] = _minCreatorStakedBalance;
    }

    function getMinInvestorGuaranteedBalance(address tokenAddress)
        external
        view
        returns (uint256)
    {
        return minInvestorGuaranteedBalance[tokenAddress];
    }

    function setMinInvestorGuaranteedBalance(
        address tokenAddress,
        uint256 _minInvestorGuaranteedBalance
    ) external onlyDev {
        minInvestorGuaranteedBalance[
            tokenAddress
        ] = _minInvestorGuaranteedBalance;
    }

    function getMinStakeTime() external view returns (uint256) {
        return minStakeTime;
    }

    function setMinStakeTime(uint256 _minStakeTime) external onlyDev {
        minStakeTime = _minStakeTime;
    }

    function getMinUnstakeTime() external view returns (uint256) {
        return minUnstakeTime;
    }

    function setMinUnstakeTime(uint256 _minUnstakeTime) external onlyDev {
        minUnstakeTime = _minUnstakeTime;
    }

    function getCreatorUnsoldClaimTime() external view returns (uint256) {
        return creatorUnsoldClaimTime;
    }

    function setCreatorUnsoldClaimTime(uint256 _creatorUnsoldClaimTime)
        external
        onlyDev
    {
        creatorUnsoldClaimTime = _creatorUnsoldClaimTime;
    }

    function getSwapRouter(uint256 index) external view returns (address) {
        return swapRouters[index];
    }

    function setSwapRouter(uint256 index, address _swapRouter)
        external
        onlyDev
    {
        swapRouters[index] = _swapRouter;
    }

    function addSwapRouter(address _swapRouter) external onlyDev {
        swapRouters.push(_swapRouter);
    }

    function getSwapFactory(uint256 index) external view returns (address) {
        return swapFactorys[index];
    }

    function setSwapFactory(uint256 index, address _swapFactory)
        external
        onlyDev
    {
        swapFactorys[index] = _swapFactory;
    }

    function addSwapFactory(address _swapFactory) external onlyDev {
        swapFactorys.push(_swapFactory);
    }

    function getInitCodeHash(address _swapFactory)
        external
        view
        returns (bytes32)
    {
        return initCodeHash[_swapFactory];
    }

    function setInitCodeHash(address _swapFactory, bytes32 _initCodeHash)
        external
        onlyDev
    {
        initCodeHash[_swapFactory] = _initCodeHash;
    }

    function getWETH() external view returns (address) {
        return weth;
    }

    function setWETH(address _weth) external onlyDev {
        weth = _weth;
    }

    function getLockingAddress() external view returns (address) {
        return lockingAddress;
    }

    function setLockingAddress(address _newLocking) external onlyDev {
        lockingAddress = _newLocking;
    }

    function getInvestmentLimit(address tokenAddress)
        external
        view
        returns (uint256)
    {
        return investmentLimit[tokenAddress];
    }

    function setInvestmentLimit(address tokenAddress, uint256 _limit)
        external
        onlyDev
    {
        investmentLimit[tokenAddress] = _limit;
    }

    function getLpAddress(address tokenAddress) public view returns (address) {
        return lpAddresses[tokenAddress];
    }

    function setLpAddress(address tokenAddress, address lpAddress)
        external
        onlyDev
    {
        lpAddresses[tokenAddress] = lpAddress;
    }

    function getStakedByLp(address lpAddress, address payable sender)
        public
        view
        returns (uint256)
    {
        uint256 balance;
        uint256 lastStakedTimestamp;
        (balance, lastStakedTimestamp, ) = stakingPool.accountLpInfos(
            lpAddress,
            address(sender)
        );
        uint256 totalHodlerBalance = 0;
        if (lastStakedTimestamp + minStakeTime <= block.timestamp) {
            totalHodlerBalance = totalHodlerBalance.add(balance);
        }

        uint256 externalBalance = externalStaking.balanceOf(address(sender));

        return totalHodlerBalance + externalBalance;
    }

    function getTotalStakedByLp(address lpAddress)
        public
        view
        returns (uint256)
    {
        return ERC20(lpAddress).balanceOf(address(stakingPool));
    }

    function getStaked(address fundingTokenAddress, address payable sender)
        public
        view
        returns (uint256)
    {
        return getStakedByLp(getLpAddress(fundingTokenAddress), sender);
    }

    function getTotalStaked(address fundingTokenAddress)
        public
        view
        returns (uint256)
    {
        return getTotalStakedByLp(getLpAddress(fundingTokenAddress));
    }

    function getDevPresaleTokenFee() public view returns (uint256) {
        return devPresaleTokenFee;
    }

    function setDevPresaleTokenFee(uint256 _devPresaleTokenFee)
        external
        onlyDev
    {
        devPresaleTokenFee = _devPresaleTokenFee;
    }

    function getDevPresaleAllocationAddress() public view returns (address) {
        return devPresaleAllocationAddress;
    }

    function setDevPresaleAllocationAddress(
        address _devPresaleAllocationAddress
    ) external onlyDev {
        devPresaleAllocationAddress = _devPresaleAllocationAddress;
    }

    function isBlacklistedAddress(address _sender) public view returns (bool) {
        return blacklistedAddresses[_sender];
    }

    function addBlacklistedAddresses(address[] calldata _blacklistedAddresses)
        external
        onlyDev
    {
        for (uint256 i = 0; i < _blacklistedAddresses.length; i++) {
            blacklistedAddresses[_blacklistedAddresses[i]] = true;
        }
    }

    function removeBlacklistedAddresses(
        address[] calldata _blacklistedAddresses
    ) external onlyDev {
        for (uint256 i = 0; i < _blacklistedAddresses.length; i++) {
            blacklistedAddresses[_blacklistedAddresses[i]] = false;
        }
    }

    function isAuditorWhitelistedAddress(address _sender)
        public
        view
        returns (bool)
    {
        return auditorWhitelistedAddresses[_sender];
    }

    function addAuditorWhitelistedAddresses(
        address[] calldata _whitelistedAddresses
    ) external onlyDev {
        for (uint256 i = 0; i < _whitelistedAddresses.length; i++) {
            auditorWhitelistedAddresses[_whitelistedAddresses[i]] = true;
        }
    }

    function removeAuditorWhitelistedAddresses(
        address[] calldata _whitelistedAddresses
    ) external onlyDev {
        for (uint256 i = 0; i < _whitelistedAddresses.length; i++) {
            auditorWhitelistedAddresses[_whitelistedAddresses[i]] = false;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../lib/SafeMath.sol";
import "../lib/Address.sol";
import "../lib/SafeERC20.sol";
import "../lib/ERC20.sol";
import "../lib/ReentrancyGuard.sol";
import "./Info.sol";

contract Staking is ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;

    Info public infoContract;

    event Staked(address indexed from, uint256 amount);
    event Unstaked(address indexed from, uint256 amount);

    struct AccountInfo {
        uint256 balance;
        uint256 lastStakedTimestamp;
        uint256 lastUnstakedTimestamp;
    }
    mapping(address => mapping(address => AccountInfo)) public accountLpInfos;

    uint256[] public burnFees = [500, 300, 100, 50, 0];
    uint256[] public feeCycle = [2 days, 5 days, 10 days, 14 days];

    address private kitsuneAddress =
        address(0x263feE29B0b5609058d340AE707c4f8f48c355f7); // KITSUNE TOKEN

    modifier onlyDev() {
        require(
            msg.sender == infoContract.getFactoryAddress() ||
                infoContract.getDev(msg.sender),
            "Only Dev"
        );
        _;
    }

    constructor(address _infoContract) public {
        infoContract = Info(_infoContract);
    }

    function stake(address _stakedToken, uint256 _amount) public nonReentrant {
        require(_amount > 0, "Invalid amount");
        require(
            ERC20(_stakedToken).balanceOf(msg.sender) >= _amount,
            "Invalid balance"
        );

        AccountInfo storage account = accountLpInfos[_stakedToken][msg.sender];
        ERC20(_stakedToken).transferFrom(msg.sender, address(this), _amount);
        account.balance = account.balance.add(_amount);

        if (account.lastUnstakedTimestamp == 0) {
            account.lastUnstakedTimestamp = block.timestamp;
        }
        account.lastStakedTimestamp = block.timestamp;
        emit Staked(msg.sender, _amount);
    }

    function unstake(address _stakedToken, uint256 _amount)
        external
        nonReentrant
    {
        AccountInfo storage account = accountLpInfos[_stakedToken][msg.sender];
        require(
            !address(msg.sender).isContract(),
            "Please use your individual account"
        );

        require(account.balance > 0, "Nothing to unstake");
        require(_amount > 0, "Invalid amount");
        if (account.balance < _amount) {
            _amount = account.balance;
        }
        account.balance = account.balance.sub(_amount);

        uint256 burnAmount = _amount
            .mul(getLpBurnFee(_stakedToken, msg.sender))
            .div(10000);
        if (burnAmount > 0) {
            _amount = _amount.sub(burnAmount);
            ERC20(_stakedToken).transfer(
                address(0x000000000000000000000000000000000000dEaD),
                burnAmount
            );
        }

        account.lastStakedTimestamp = block.timestamp;
        account.lastUnstakedTimestamp = block.timestamp;

        if (account.balance == 0) {
            account.lastStakedTimestamp = 0;
            account.lastUnstakedTimestamp = 0;
        }
        ERC20(_stakedToken).transfer(msg.sender, _amount);
        emit Unstaked(msg.sender, _amount);
    }

    function getLpBurnFee(address _stakedToken, address _staker)
        public
        view
        returns (uint256)
    {
        AccountInfo memory account = accountLpInfos[_stakedToken][_staker];
        for (uint256 i = 0; i < feeCycle.length; i++) {
            if (block.timestamp < account.lastUnstakedTimestamp + feeCycle[i]) {
                return burnFees[i];
            }
        }
        return burnFees[feeCycle.length];
    }

    function setBurnFee(uint256 _index, uint256 fee) external onlyDev {
        burnFees[_index] = fee;
    }

    function setBurnCycle(uint256 _index, uint256 _cycle) external onlyDev {
        feeCycle[_index] = _cycle;
    }

    function setInfoContract(address _newInfo) external onlyDev {
        infoContract = Info(_newInfo);
    }

    function emergencyWithdraw(address _token, address _receiver)
        external
        onlyDev
    {
        IERC20(_token).transfer(
            _receiver,
            IERC20(_token).balanceOf(address(this))
        );
    }
}

pragma solidity ^0.6.12;

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

pragma solidity ^0.6.12;

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
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
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
    function functionCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
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

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
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
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(
        address target,
        bytes memory data,
        uint256 weiValue,
        string memory errorMessage
    ) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{value: weiValue}(
            data
        );
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

pragma solidity ^0.6.12;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

pragma solidity ^0.6.12;

import "./Address.sol";
import "./Context.sol";
import "./SafeMath.sol";
import "../interfaces/IERC20.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) _balances;

    mapping(address => mapping(address => uint256)) _allowances;

    uint256 _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
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

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
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

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
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

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(
            amount,
            "ERC20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(
            amount,
            "ERC20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

pragma solidity ^0.6.12;

/**
 * @title Owned
 * @dev Basic contract for authorization control.
 * @author dicether
 */
contract Ownable {
    address public owner;
    address public pendingOwner;

    event LogOwnerShipTransferred(address indexed previousOwner, address indexed newOwner);
    event LogOwnerShipTransferInitiated(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Modifier, which throws if called by other account than owner.
     */
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Modifier throws if called by any account other than the pendingOwner.
     */
    modifier onlyPendingOwner() {
        require(msg.sender == pendingOwner);
        _;
    }

    /**
     * @dev Set contract creator as initial owner
     */
    constructor() public {
        owner = msg.sender;
        pendingOwner = address(0);
    }

    /**
     * @dev Allows the current owner to set the pendingOwner address.
     * @param _newOwner The address to transfer ownership to.
     */
    function transferOwnership(address _newOwner) public onlyOwner {
        pendingOwner = _newOwner;
        emit LogOwnerShipTransferInitiated(owner, _newOwner);
    }

    /**
     * @dev PendingOwner can accept ownership.
     */
    function claimOwnership() public onlyPendingOwner {
        owner = pendingOwner;
        pendingOwner = address(0);
        emit LogOwnerShipTransferred(owner, pendingOwner);
    }
}

pragma solidity ^0.6.12;

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
contract ReentrancyGuard {
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

    constructor() internal {
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
}

pragma solidity ^0.6.12;

import "./Address.sol";
import "./SafeMath.sol";

import "../interfaces/IERC20.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(
            value
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(
            value,
            "SafeERC20: decreased allowance below zero"
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(
            data,
            "SafeERC20: low-level call failed"
        );
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}

pragma solidity ^0.6.12;

// File: @openzeppelin/contracts/math/SafeMath.sol

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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}