// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './RelayBase.sol';
import './ConfirmedOwner.sol';
import './interfaces/TypeAndVersionInterface.sol';
import './interfaces/AggregatorV3Interface.sol';
import './interfaces/LinkTokenInterface.sol';
import './interfaces/RelayCompatibleInterface.sol';
import './interfaces/RelayRegistryInterface.sol';
import './interfaces/ERC677ReceiverInterface.sol';
import '../utils/RelayTypes.sol';

/**
 * @notice Registry for adding work for Chainlink Relayers to perform on client
 * contracts. Clients must support the Relay interface.
 */
contract RelayRegistry is
    TypeAndVersionInterface,
    ConfirmedOwner,
    RelayBase,
    ReentrancyGuard,
    Pausable,
    RelayRegistryExecutableInterface,
    ERC677ReceiverInterface
{
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;

    address private constant ZERO_ADDRESS = address(0);
    address private constant IGNORE_ADDRESS = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
    bytes4 private constant CHECK_SELECTOR = RelayCompatibleInterface.checkRelay.selector;
    bytes4 private constant PERFORM_SELECTOR = RelayCompatibleInterface.performRelay.selector;
    uint256 private constant PERFORM_GAS_MIN = 2_300;
    uint256 private constant CANCELATION_DELAY = 50;
    uint256 private constant PERFORM_GAS_CUSHION = 5_000;
    uint256 private constant REGISTRY_GAS_OVERHEAD = 80_000;
    uint256 private constant PPB_BASE = 1_000_000_000;
    uint64 private constant UINT64_MAX = 2**64 - 1;
    uint96 private constant LINK_TOTAL_SUPPLY = 1e27;

    address[] private s_relayerList;
    EnumerableSet.UintSet private s_relayIDs;
    mapping(uint256 => Relay) private s_relay;
    mapping(address => RelayerInfo) private s_relayerInfo;
    mapping(address => address) private s_proposedPayee;
    mapping(uint256 => bytes) private s_checkData;
    Storage private s_storage;
    uint256 private s_fallbackGasPrice;
    uint256 private s_fallbackLinkPrice;
    uint96 private s_ownerLinkBalance;
    uint256 private s_expectedLinkBalance;
    address private s_registrar;

    //TODO: put in constructor so can change when using different chain
    LinkTokenInterface public constant LINK =
        LinkTokenInterface(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
    AggregatorV3Interface public constant LINK_ETH_FEED =
        AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    AggregatorV3Interface public constant FAST_GAS_FEED =
        AggregatorV3Interface(0x169E633A2D1E6c10dD91238Ba11c4A708dfEF37C);

    /**
     * @notice versions:
     * - RelayRegistry 1.0.0: initial release
     */
    string public constant override typeAndVersion = 'RelayRegistry 1.0.0';

    error CannotCancel();
    error RelayNotActive();
    error RelayNotCanceled();
    error RelayNotNeeded();
    error NotAContract();
    error PaymentGreaterThanAllLINK();
    error OnlyActiveRelayers();
    error InsufficientFunds();
    error RelayersMustTakeTurns();
    error ParameterLengthError();
    error OnlyCallableByOwnerOrAdmin();
    error OnlyCallableByLINKToken();
    error InvalidPayee();
    error DuplicateEntry();
    error ValueNotChanged();
    error IndexOutOfRange();
    error ArrayHasNoEntries();
    error GasLimitOutsideRange();
    error OnlyCallableByPayee();
    error OnlyCallableByProposedPayee();
    error GasLimitCanOnlyIncrease();
    error OnlyCallableByAdmin();
    error OnlyCallableByOwnerOrRegistrar();
    error InvalidRecipient();
    error InvalidDataLength();
    error TargetCheckReverted(bytes reason);

    /**
     * @notice storage of the registry, contains a mix of config and state data
     */
    struct Storage {
        uint32 paymentPremiumPPB;
        uint32 flatFeeMicroLink;
        uint24 blockCountPerTurn;
        uint32 checkGasLimit;
        uint24 stalenessSeconds;
        uint16 gasCeilingMultiplier;
        uint96 minRelaySpend; // 1 evm word
        uint32 maxPerformGas;
        uint32 nonce; // 2 evm words
    }

    struct Relay {
        uint96 balance;
        address lastRelayer; // 1 storage slot full
        uint32 executeGas;
        uint64 maxValidBlocknumber;
        address target; // 2 storage slots full
        uint96 amountSpent;
        address client; // 3 storage slots full
    }

    struct RelayerInfo {
        address payee;
        uint96 balance;
        bool active;
    }

    struct PerformParams {
        address from;
        uint256 id;
        RelayTypes.RelayRequest relayRequest;
        bytes performData;
        uint256 maxLinkPayment;
        uint256 gasLimit;
        uint256 adjustedGasWei;
        uint256 linkEth;
    }

    event RelayRegistered(uint256 indexed id, uint32 executeGas, address admin);
    event RelayPerformed(
        uint256 indexed id,
        bool indexed success,
        address indexed from,
        uint96 payment,
        RelayTypes.RelayRequest relayRequest,
        bytes performData
    );
    event RelayCanceled(uint256 indexed id, uint64 indexed atBlockHeight);
    event FundsAdded(uint256 indexed id, address indexed from, uint96 amount);
    event FundsWithdrawn(uint256 indexed id, uint256 amount, address to);
    event OwnerFundsWithdrawn(uint96 amount);
    event RelayReceived(uint256 indexed id, uint256 startingBalance, address importedFrom);
    event ConfigSet();
    event RelayersUpdated(address[] relayers, address[] payees);
    event PaymentWithdrawn(
        address indexed relayer,
        uint256 indexed amount,
        address indexed to,
        address payee
    );
    event PayeeshipTransferRequested(
        address indexed relayer,
        address indexed from,
        address indexed to
    );
    event PayeeshipTransferred(address indexed relayer, address indexed from, address indexed to);
    event RelayGasLimitSet(uint256 indexed id, uint96 gasLimit);

    /**
     * @param paymentPremiumPPB payment premium rate oracles receive on top of
     * being reimbursed for gas, measured in parts per billion
     * @param flatFeeMicroLink flat fee paid to oracles for performing relays,
     * priced in MicroLink; can be used in conjunction with or independently of
     * paymentPremiumPPB
     * @param blockCountPerTurn number of blocks each oracle has during their turn to
     * perform relay before it will be the next relayer's turn to submit
     * @param checkGasLimit gas limit when checking a relay
     * @param stalenessSeconds number of seconds that is allowed for feed data to
     * be stale before switching to the fallback pricing
     * @param gasCeilingMultiplier multiplier to apply to the fast gas feed price
     * when calculating the payment ceiling for relayers
     * @param minRelaySpend minimum LINK that an relay must spend before cancelling
     * @param maxPerformGas max executeGas allowed for a relay on this registry
     * @param fallbackGasPrice gas price used if the gas price feed is stale
     * @param fallbackLinkPrice LINK price used if the LINK price feed is stale
     * @param registrar address of the registrar contract
     */
    constructor(
        uint32 paymentPremiumPPB,
        uint32 flatFeeMicroLink,
        uint24 blockCountPerTurn,
        uint32 checkGasLimit,
        uint24 stalenessSeconds,
        uint16 gasCeilingMultiplier,
        uint96 minRelaySpend,
        uint32 maxPerformGas,
        uint256 fallbackGasPrice,
        uint256 fallbackLinkPrice,
        address registrar
    ) ConfirmedOwner(msg.sender) {
        setConfig(
            paymentPremiumPPB,
            flatFeeMicroLink,
            blockCountPerTurn,
            checkGasLimit,
            stalenessSeconds,
            gasCeilingMultiplier,
            minRelaySpend,
            maxPerformGas,
            fallbackGasPrice,
            fallbackLinkPrice,
            registrar
        );
    }

    // ACTIONS

    /**
     * @notice adds a new relay
     * @param target address to be submitted for relay
     * @param gasLimit amount of gas to provide the target contract when
     * performing relay
     * @param admin client address to cancel relay and withdraw remaining funds
     * @param checkData data passed to the contract when checking if relay
     * is required for a user
     * @return id the ID associated with the new relay
     */
    function registerRelay(
        address target,
        uint32 gasLimit,
        address admin,
        bytes calldata checkData
    ) external override onlyOwnerOrRegistrar returns (uint256 id) {
        id = uint256(
            keccak256(abi.encodePacked(blockhash(block.number - 1), address(this), s_storage.nonce))
        );
        _createRelay(id, target, gasLimit, admin, 0, checkData);
        s_storage.nonce++;
        emit RelayRegistered(id, gasLimit, admin);
        return id;
    }

    /**
     * @notice simulated by relayers via eth_call to see if the relay needs to be
     * performed and passes checks. If relay is needed, the call then simulates performRelay
     * to make sure it succeeds. Finally, it returns the success status along with
     * payment information and the perform data payload.
     * @param id identifier of the relay to check
     * @param from the address to simulate performing the relay from
     */
    function checkRelay(
        uint256 id,
        address from,
        RelayTypes.RelayRequest calldata relayRequest
    )
        external
        override
        cannotExecute
        returns (
            bytes memory performData,
            uint256 maxLinkPayment,
            uint256 gasLimit,
            uint256 adjustedGasWei,
            uint256 linkEth
        )
    {
        Relay memory relay = s_relay[id];

        bytes memory callData = abi.encodeWithSelector(
            CHECK_SELECTOR,
            relayRequest,
            s_checkData[id]
        );
        (bool success, bytes memory result) = relay.target.call{gas: s_storage.checkGasLimit}(
            callData
        );

        if (!success) revert TargetCheckReverted(result);

        (success, performData) = abi.decode(result, (bool, bytes));
        if (!success) revert RelayNotNeeded();

        PerformParams memory params = _generatePerformParams(
            from,
            id,
            relayRequest,
            performData,
            false
        );
        _prePerformRelay(relay, params.from, params.maxLinkPayment);

        return (
            performData,
            params.maxLinkPayment,
            params.gasLimit,
            params.adjustedGasWei,
            params.linkEth
        );
    }

    /**
     * @notice executes the relay with the perform data returned from
     * checkRelay, validates the relayer's permissions, and pays the relayer.
     * @param id identifier of the relay to execute the data with.
     * @param performData calldata parameter to be passed to the target relay.
     */
    function performRelay(
        uint256 id,
        RelayTypes.RelayRequest calldata relayRequest,
        bytes calldata performData
    ) external override whenNotPaused returns (bool success) {
        return
            _performRelayWithParams(
                _generatePerformParams(msg.sender, id, relayRequest, performData, true)
            );
    }

    /**
     * @notice prevent a relay from being performed in the future
     * @param id relay to be cancelled
     */
    function cancelRelay(uint256 id) external override {
        uint64 maxValid = s_relay[id].maxValidBlocknumber;
        bool canceled = maxValid != UINT64_MAX;
        bool isOwner = msg.sender == owner();

        if (canceled && !(isOwner && maxValid > block.number)) revert CannotCancel();
        if (!isOwner && msg.sender != s_relay[id].client) revert OnlyCallableByOwnerOrAdmin();

        uint256 height = block.number;
        if (!isOwner) {
            height = height + CANCELATION_DELAY;
        }
        s_relay[id].maxValidBlocknumber = uint64(height);
        s_relayIDs.remove(id);

        emit RelayCanceled(id, uint64(height));
    }

    /**
     * @notice adds LINK funding for a relay by transferring from the sender's
     * LINK balance
     * @param id relay to fund
     * @param amount number of LINK to transfer
     */
    function addFunds(uint256 id, uint96 amount) external override onlyActiveRelay(id) {
        s_relay[id].balance = s_relay[id].balance + amount;
        s_expectedLinkBalance = s_expectedLinkBalance + amount;
        LINK.transferFrom(msg.sender, address(this), amount);
        emit FundsAdded(id, msg.sender, amount);
    }

    /**
     * @notice uses LINK's transferAndCall to LINK and add funding to a relay
     * @dev safe to cast uint256 to uint96 as total LINK supply is under UINT96MAX
     * @param sender the account which transferred the funds
     * @param amount number of LINK transfer
     */
    function onTokenTransfer(
        address sender,
        uint256 amount,
        bytes calldata data
    ) external {
        if (msg.sender != address(LINK)) revert OnlyCallableByLINKToken();
        if (data.length != 32) revert InvalidDataLength();
        uint256 id = abi.decode(data, (uint256));
        if (s_relay[id].maxValidBlocknumber != UINT64_MAX) revert RelayNotActive();

        s_relay[id].balance = s_relay[id].balance + uint96(amount);
        s_expectedLinkBalance = s_expectedLinkBalance + amount;

        emit FundsAdded(id, sender, uint96(amount));
    }

    /**
     * @notice removes funding from a canceled relay
     * @param id relay to withdraw funds from
     * @param to destination address for sending remaining funds
     */
    function withdrawFunds(uint256 id, address to) external validRecipient(to) onlyRelayAdmin(id) {
        if (s_relay[id].maxValidBlocknumber > block.number) revert RelayNotCanceled();

        uint96 minRelaySpend = s_storage.minRelaySpend;
        uint96 amountLeft = s_relay[id].balance;
        uint96 amountSpent = s_relay[id].amountSpent;

        uint96 cancellationFee = 0;
        // cancellationFee is supposed to be min(max(minRelaySpend - amountSpent,0), amountLeft)
        if (amountSpent < minRelaySpend) {
            cancellationFee = minRelaySpend - amountSpent;
            if (cancellationFee > amountLeft) {
                cancellationFee = amountLeft;
            }
        }
        uint96 amountToWithdraw = amountLeft - cancellationFee;

        s_relay[id].balance = 0;
        s_ownerLinkBalance = s_ownerLinkBalance + cancellationFee;

        s_expectedLinkBalance = s_expectedLinkBalance - amountToWithdraw;
        emit FundsWithdrawn(id, amountToWithdraw, to);

        LINK.transfer(to, amountToWithdraw);
    }

    /**
     * @notice withdraws LINK funds collected through cancellation fees
     */
    function withdrawOwnerFunds() external onlyOwner {
        uint96 amount = s_ownerLinkBalance;

        s_expectedLinkBalance = s_expectedLinkBalance - amount;
        s_ownerLinkBalance = 0;

        emit OwnerFundsWithdrawn(amount);
        LINK.transfer(msg.sender, amount);
    }

    /**
     * @notice allows clients to modify gas limit of a relay
     * @param id relay to be change the gas limit for
     * @param gasLimit new gas limit for the relay
     */
    function setRelayGasLimit(uint256 id, uint32 gasLimit)
        external
        override
        onlyActiveRelay(id)
        onlyRelayAdmin(id)
    {
        if (gasLimit < PERFORM_GAS_MIN || gasLimit > s_storage.maxPerformGas)
            revert GasLimitOutsideRange();

        s_relay[id].executeGas = gasLimit;

        emit RelayGasLimitSet(id, gasLimit);
    }

    /**
     * @notice recovers LINK funds improperly transferred to the registry
     * @dev In principle this function’s execution cost could exceed block
     * gas limit. However, in our anticipated deployment, the number of relays and
     * relayers will be low enough to avoid this problem.
     */
    function recoverFunds() external onlyOwner {
        uint256 total = LINK.balanceOf(address(this));
        LINK.transfer(msg.sender, total - s_expectedLinkBalance);
    }

    /**
     * @notice withdraws a relayer's payment, callable only by the relayer's payee
     * @param from relayer address
     * @param to address to send the payment to
     */
    function withdrawPayment(address from, address to) external validRecipient(to) {
        RelayerInfo memory relayer = s_relayerInfo[from];
        if (relayer.payee != msg.sender) revert OnlyCallableByPayee();

        s_relayerInfo[from].balance = 0;
        s_expectedLinkBalance = s_expectedLinkBalance - relayer.balance;
        emit PaymentWithdrawn(from, relayer.balance, to, msg.sender);

        LINK.transfer(to, relayer.balance);
    }

    /**
     * @notice proposes the safe transfer of a relayer's payee to another address
     * @param relayer address of the relayer to transfer payee role
     * @param proposed address to nominate for next payeeship
     */
    function transferPayeeship(address relayer, address proposed) external {
        if (s_relayerInfo[relayer].payee != msg.sender) revert OnlyCallableByPayee();
        if (proposed == msg.sender) revert ValueNotChanged();

        if (s_proposedPayee[relayer] != proposed) {
            s_proposedPayee[relayer] = proposed;
            emit PayeeshipTransferRequested(relayer, msg.sender, proposed);
        }
    }

    /**
     * @notice accepts the safe transfer of payee role for a relayer
     * @param relayer address to accept the payee role for
     */
    function acceptPayeeship(address relayer) external {
        if (s_proposedPayee[relayer] != msg.sender) revert OnlyCallableByProposedPayee();
        address past = s_relayerInfo[relayer].payee;
        s_relayerInfo[relayer].payee = msg.sender;
        s_proposedPayee[relayer] = ZERO_ADDRESS;

        emit PayeeshipTransferred(relayer, past, msg.sender);
    }

    /**
     * @notice signals to relayers that they should not perform relays until the
     * contract has been unpaused
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice signals to relayers that they can perform relays once again after
     * having been paused
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // SETTERS

    /**
     * @notice updates the configuration of the registry
     */
    function setConfig(
        uint32 paymentPremiumPPB,
        uint32 flatFeeMicroLink,
        uint24 blockCountPerTurn,
        uint32 checkGasLimit,
        uint24 stalenessSeconds,
        uint16 gasCeilingMultiplier,
        uint96 minRelaySpend,
        uint32 maxPerformGas,
        uint256 fallbackGasPrice,
        uint256 fallbackLinkPrice,
        address registrar
    ) public onlyOwner {
        if (maxPerformGas < s_storage.maxPerformGas) revert GasLimitCanOnlyIncrease();
        s_storage = Storage({
            paymentPremiumPPB: paymentPremiumPPB,
            flatFeeMicroLink: flatFeeMicroLink,
            blockCountPerTurn: blockCountPerTurn,
            checkGasLimit: checkGasLimit,
            stalenessSeconds: stalenessSeconds,
            gasCeilingMultiplier: gasCeilingMultiplier,
            minRelaySpend: minRelaySpend,
            maxPerformGas: maxPerformGas,
            nonce: s_storage.nonce
        });
        s_fallbackGasPrice = fallbackGasPrice;
        s_fallbackLinkPrice = fallbackLinkPrice;
        s_registrar = registrar;
        emit ConfigSet();
    }

    /**
     * @notice update the list of relayers allowed to perform relay
     * @param relayers list of addresses allowed to perform relay
     * @param payees addresses corresponding to relayers who are allowed to
     * move payments which have been accrued
     */
    function setRelayers(address[] calldata relayers, address[] calldata payees)
        external
        onlyOwner
    {
        if (relayers.length != payees.length || relayers.length < 2) revert ParameterLengthError();
        for (uint256 i = 0; i < s_relayerList.length; i++) {
            address relayer = s_relayerList[i];
            s_relayerInfo[relayer].active = false;
        }
        for (uint256 i = 0; i < relayers.length; i++) {
            address relayer = relayers[i];
            RelayerInfo storage s_relayer = s_relayerInfo[relayer];
            address oldPayee = s_relayer.payee;
            address newPayee = payees[i];
            if (
                (newPayee == ZERO_ADDRESS) ||
                (oldPayee != ZERO_ADDRESS && oldPayee != newPayee && newPayee != IGNORE_ADDRESS)
            ) revert InvalidPayee();
            if (s_relayer.active) revert DuplicateEntry();
            s_relayer.active = true;
            if (newPayee != IGNORE_ADDRESS) {
                s_relayer.payee = newPayee;
            }
        }
        s_relayerList = relayers;
        emit RelayersUpdated(relayers, payees);
    }

    // GETTERS

    /**
     * @notice read all of the details about a relay
     */
    function getRelay(uint256 id)
        external
        view
        override
        returns (
            address target,
            uint32 executeGas,
            bytes memory checkData,
            uint96 balance,
            address lastRelayer,
            address admin,
            uint64 maxValidBlocknumber,
            uint96 amountSpent
        )
    {
        Relay memory reg = s_relay[id];
        return (
            reg.target,
            reg.executeGas,
            s_checkData[id],
            reg.balance,
            reg.lastRelayer,
            reg.client,
            reg.maxValidBlocknumber,
            reg.amountSpent
        );
    }

    /**
     * @notice retrieve active relay IDs
     * @param startIndex starting index in list
     * @param maxCount max count to retrieve (0 = unlimited)
     * @dev the order of IDs in the list is **not guaranteed**, therefore, if making successive calls, one
     * should consider keeping the blockheight constant to ensure a wholistic picture of the contract state
     */
    function getActiveRelayIDs(uint256 startIndex, uint256 maxCount)
        external
        view
        override
        returns (uint256[] memory)
    {
        uint256 maxIdx = s_relayIDs.length();
        if (startIndex >= maxIdx) revert IndexOutOfRange();
        if (maxCount == 0) {
            maxCount = maxIdx - startIndex;
        }
        uint256[] memory ids = new uint256[](maxCount);
        for (uint256 idx = 0; idx < maxCount; idx++) {
            ids[idx] = s_relayIDs.at(startIndex + idx);
        }
        return ids;
    }

    /**
     * @notice read the current info about any relayer address
     */
    function getRelayerInfo(address query)
        external
        view
        override
        returns (
            address payee,
            bool active,
            uint96 balance
        )
    {
        RelayerInfo memory relayer = s_relayerInfo[query];
        return (relayer.payee, relayer.active, relayer.balance);
    }

    /**
     * @notice read the current state of the registry
     */
    function getState()
        external
        view
        override
        returns (
            State memory state,
            Config memory config,
            address[] memory relayers
        )
    {
        Storage memory store = s_storage;
        state.nonce = store.nonce;
        state.ownerLinkBalance = s_ownerLinkBalance;
        state.expectedLinkBalance = s_expectedLinkBalance;
        state.numRelays = s_relayIDs.length();
        config.paymentPremiumPPB = store.paymentPremiumPPB;
        config.flatFeeMicroLink = store.flatFeeMicroLink;
        config.blockCountPerTurn = store.blockCountPerTurn;
        config.checkGasLimit = store.checkGasLimit;
        config.stalenessSeconds = store.stalenessSeconds;
        config.gasCeilingMultiplier = store.gasCeilingMultiplier;
        config.minRelaySpend = store.minRelaySpend;
        config.maxPerformGas = store.maxPerformGas;
        config.fallbackGasPrice = s_fallbackGasPrice;
        config.fallbackLinkPrice = s_fallbackLinkPrice;
        config.registrar = s_registrar;
        return (state, config, s_relayerList);
    }

    /**
     * @notice calculates the minimum balance required for a relay to remain eligible
     * @param id the relay id to calculate minimum balance for
     */
    function getMinBalanceForRelay(uint256 id) external view returns (uint96 minBalance) {
        return getMaxPaymentForGas(s_relay[id].executeGas);
    }

    /**
     * @notice calculates the maximum payment for a given gas limit
     * @param gasLimit the gas to calculate payment for
     */
    function getMaxPaymentForGas(uint256 gasLimit) public view returns (uint96 maxPayment) {
        (uint256 gasWei, uint256 linkEth) = _getFeedData();
        uint256 adjustedGasWei = _adjustGasPrice(gasWei, false);
        return _calculatePaymentAmount(gasLimit, adjustedGasWei, linkEth);
    }

    /**
     * @notice creates a new relay with the given fields
     * @param target address to be submitted for relay
     * @param gasLimit amount of gas to provide the target contract when
     * performing relay
     * @param client client address to cancel relay and withdraw remaining funds
     * @param checkData data passed to the contract when checking for relay
     */
    function _createRelay(
        uint256 id,
        address target,
        uint32 gasLimit,
        address client,
        uint96 balance,
        bytes memory checkData
    ) internal whenNotPaused {
        if (!target.isContract()) revert NotAContract();
        if (gasLimit < PERFORM_GAS_MIN || gasLimit > s_storage.maxPerformGas)
            revert GasLimitOutsideRange();
        s_relay[id] = Relay({
            target: target,
            executeGas: gasLimit,
            balance: balance,
            client: client,
            maxValidBlocknumber: UINT64_MAX,
            lastRelayer: ZERO_ADDRESS,
            amountSpent: 0
        });
        s_expectedLinkBalance = s_expectedLinkBalance + balance;
        s_checkData[id] = checkData;
        s_relayIDs.add(id);
    }

    /**
     * @dev retrieves feed data for fast gas/eth and link/eth prices. if the feed
     * data is stale it uses the configured fallback price. Once a price is picked
     * for gas it takes the min of gas price in the transaction or the fast gas
     * price in order to reduce costs for the relay clients.
     */
    function _getFeedData() private view returns (uint256 gasWei, uint256 linkEth) {
        uint32 stalenessSeconds = s_storage.stalenessSeconds;
        bool staleFallback = stalenessSeconds > 0;
        uint256 timestamp;
        int256 feedValue;
        (, feedValue, , timestamp, ) = FAST_GAS_FEED.latestRoundData();
        if ((staleFallback && stalenessSeconds < block.timestamp - timestamp) || feedValue <= 0) {
            gasWei = s_fallbackGasPrice;
        } else {
            gasWei = uint256(feedValue);
        }
        (, feedValue, , timestamp, ) = LINK_ETH_FEED.latestRoundData();
        if ((staleFallback && stalenessSeconds < block.timestamp - timestamp) || feedValue <= 0) {
            linkEth = s_fallbackLinkPrice;
        } else {
            linkEth = uint256(feedValue);
        }
        return (gasWei, linkEth);
    }

    /**
     * @dev calculates LINK paid for gas spent plus a configure premium percentage
     */
    function _calculatePaymentAmount(
        uint256 gasLimit,
        uint256 gasWei,
        uint256 linkEth
    ) private view returns (uint96 payment) {
        uint256 weiForGas = gasWei * (gasLimit + REGISTRY_GAS_OVERHEAD);
        uint256 premium = PPB_BASE + s_storage.paymentPremiumPPB;
        uint256 total = ((weiForGas * (1e9) * (premium)) / (linkEth)) +
            (uint256(s_storage.flatFeeMicroLink) * (1e12));
        if (total > LINK_TOTAL_SUPPLY) revert PaymentGreaterThanAllLINK();
        return uint96(total); // LINK_TOTAL_SUPPLY < UINT96_MAX
    }

    /**
     * @dev calls target address with exactly gasAmount gas and data as calldata
     * or reverts if at least gasAmount gas is not available
     */
    function _callWithExactGas(
        uint256 gasAmount,
        address target,
        bytes memory data
    ) private returns (bool success) {
        assembly {
            let g := gas()
            // Compute g -= PERFORM_GAS_CUSHION and check for underflow
            if lt(g, PERFORM_GAS_CUSHION) {
                revert(0, 0)
            }
            g := sub(g, PERFORM_GAS_CUSHION)
            // if g - g//64 <= gasAmount, revert
            // (we subtract g//64 because of EIP-150)
            if iszero(gt(sub(g, div(g, 64)), gasAmount)) {
                revert(0, 0)
            }
            // solidity calls check that a contract actually exists at the destination, so we do the same
            if iszero(extcodesize(target)) {
                revert(0, 0)
            }
            // call and return whether we succeeded. ignore return data
            success := call(gasAmount, target, 0, add(data, 0x20), mload(data), 0, 0)
        }
        return success;
    }

    /**
     * @dev calls the Relay target with the performData param passed in by the
     * relayer and the exact gas required by the relay
     */
    function _performRelayWithParams(PerformParams memory params)
        private
        nonReentrant
        validRelay(params.id)
        returns (bool success)
    {
        Relay memory relay = s_relay[params.id];
        _prePerformRelay(relay, params.from, params.maxLinkPayment);

        uint256 gasUsed = gasleft();
        bytes memory callData = abi.encodeWithSelector(
            PERFORM_SELECTOR,
            params.relayRequest,
            params.performData
        );
        success = _callWithExactGas(params.gasLimit, relay.target, callData);
        gasUsed = gasUsed - gasleft();

        uint96 payment = _calculatePaymentAmount(gasUsed, params.adjustedGasWei, params.linkEth);

        s_relay[params.id].balance = s_relay[params.id].balance - payment;
        s_relay[params.id].amountSpent = s_relay[params.id].amountSpent + payment;
        s_relay[params.id].lastRelayer = params.from;
        s_relayerInfo[params.from].balance = s_relayerInfo[params.from].balance + payment;

        emit RelayPerformed(
            params.id,
            success,
            params.from,
            payment,
            params.relayRequest,
            params.performData
        );
        return success;
    }

    /**
     * @dev ensures all required checks are passed before a relay is performed
     */
    function _prePerformRelay(
        Relay memory relay,
        address from,
        uint256 maxLinkPayment
    ) private view {
        if (!s_relayerInfo[from].active) revert OnlyActiveRelayers();
        if (relay.balance < maxLinkPayment) revert InsufficientFunds();
        if (relay.lastRelayer == from) revert RelayersMustTakeTurns();
    }

    /**
     * @dev adjusts the gas price to min(ceiling, tx.gasprice) or just uses the ceiling if tx.gasprice is disabled
     */
    function _adjustGasPrice(uint256 gasWei, bool useTxGasPrice)
        private
        view
        returns (uint256 adjustedPrice)
    {
        adjustedPrice = gasWei * s_storage.gasCeilingMultiplier;
        if (useTxGasPrice && tx.gasprice < adjustedPrice) {
            adjustedPrice = tx.gasprice;
        }
    }

    /**
     * @dev generates a PerformParams struct for use in _performRelayWithParams()
     */
    function _generatePerformParams(
        address from,
        uint256 id,
        RelayTypes.RelayRequest calldata relayRequest,
        bytes memory performData,
        bool useTxGasPrice
    ) private view returns (PerformParams memory) {
        uint256 gasLimit = s_relay[id].executeGas;
        (uint256 gasWei, uint256 linkEth) = _getFeedData();
        uint256 adjustedGasWei = _adjustGasPrice(gasWei, useTxGasPrice);
        uint96 maxLinkPayment = _calculatePaymentAmount(gasLimit, adjustedGasWei, linkEth);

        return
            PerformParams({
                from: from,
                id: id,
                relayRequest: relayRequest,
                performData: performData,
                maxLinkPayment: maxLinkPayment,
                gasLimit: gasLimit,
                adjustedGasWei: adjustedGasWei,
                linkEth: linkEth
            });
    }

    // MODIFIERS

    /**
     * @dev ensures a relay is valid
     */
    modifier validRelay(uint256 id) {
        if (s_relay[id].maxValidBlocknumber <= block.number) revert RelayNotActive();
        _;
    }

    /**
     * @dev Reverts if called by anyone other than the client that owns the relay #id
     */
    modifier onlyRelayAdmin(uint256 id) {
        if (msg.sender != s_relay[id].client) revert OnlyCallableByAdmin();
        _;
    }

    /**
     * @dev Reverts if called on a cancelled relay
     */
    modifier onlyActiveRelay(uint256 id) {
        if (s_relay[id].maxValidBlocknumber != UINT64_MAX) revert RelayNotActive();
        _;
    }

    /**
     * @dev ensures that burns don't accidentally happen by sending to the zero
     * address
     */
    modifier validRecipient(address to) {
        if (to == ZERO_ADDRESS) revert InvalidRecipient();
        _;
    }

    /**
     * @dev Reverts if called by anyone other than the contract owner or registrar.
     */
    modifier onlyOwnerOrRegistrar() {
        if (msg.sender != owner() && msg.sender != s_registrar)
            revert OnlyCallableByOwnerOrRegistrar();
        _;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/structs/EnumerableSet.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 *  Trying to delete such a structure from storage will likely result in data corruption, rendering the structure unusable.
 *  See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 *  In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
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
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
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
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
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
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
abstract contract ReentrancyGuard {
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

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Context.sol';

// TODO: - revert transaction if checks not correct/invalid info/ transaction already completed

contract RelayBase {
    error OnlySimulatedBackend();
    error OnlyCallableByRegistry();

    /**
     * @notice method that allows it to be simulated via eth_call by checking that
     * the sender is the zero address.
     */
    function preventExecution() internal view virtual {
        if (tx.origin != address(0)) {
            revert OnlySimulatedBackend();
        }
    }

    function checkOnlyRegistry(address registry) internal view virtual {
        if (msg.sender != registry) {
            revert OnlyCallableByRegistry();
        }
    }

    /**
     * @notice modifier that allows it to be simulated via eth_call by checking
     * that the sender is the zero address.
     */
    modifier cannotExecute() {
        preventExecution();
        _;
    }

    modifier onlyRegistry(address registry) {
        checkOnlyRegistry(registry);
        _;
    }

    function _msgSenderBase() internal view returns (address sender) {
        if (msg.data.length >= 20 && msg.sender == address(this)) {
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            sender = msg.sender;
        }
    }

    function _msgDataBase() internal view returns (bytes calldata data) {
        if (msg.data.length >= 20 && msg.sender == address(this)) {
            return msg.data[0:msg.data.length - 20];
        } else {
            return msg.data;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ConfirmedOwnerWithProposal.sol";

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwner is ConfirmedOwnerWithProposal {
  constructor(address newOwner) ConfirmedOwnerWithProposal(newOwner, address(0)) {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract TypeAndVersionInterface {
  function typeAndVersion() external pure virtual returns (string memory);
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  ) external returns (bool success);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool success);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../../utils/RelayTypes.sol';

/**
 * @title The abstract class used to build relay compatible contracts.
 *
 * @notice A base contract to be inherited by any contract that want to receive relayed transactions.
 *
 * @notice A subclass must use `_msgSender()` instead of `msg.sender`.
 *
 * @dev Note may need to split forwarder specifications from the rest
 */

interface RelayCompatibleInterface {
    /**
     * @notice method that is simulated by the relayers to see if any relays need to
     * be performed. This method does does not actually need to be
     * executable, and since it is only ever simulated it can consume lots of gas.
     * @dev To ensure that it is never called, you may want to add the
     * cannotExecute modifier from RelayBase to your implementation of this
     * method.
     * @param relayRequest data describing the specific transaction submitted for relay
     * @param checkData specified in the relay registration so it is always the
     * same for a registered relay. This can easily be broken down into specific
     * arguments using `abi.decode`, so multiple relays can be registered on the
     * same contract and easily differentiated by the contract.
     * @return relayNeeded boolean to indicate whether the Relayer should perform the relay
     * for the transaction
     * @return performData bytes that the Relayer should call performRelay with, if
     * relay is needed. If you would like to encode data to decode later, try
     * `abi.encode`.
     */
    function checkRelay(RelayTypes.RelayRequest calldata relayRequest, bytes calldata checkData)
        external
        returns (bool relayNeeded, bytes memory performData);

    /**
     * @notice method that is actually executed by the relayers nj, via the registry.
     * The data returned by the checkRelay simulation will be passed into
     * this method to actually be executed.
     * @dev The input to this method should not be trusted, and the caller of the
     * method should not even be restricted to any single registry. Anyone should
     * be able call it, and the input should be validated, there is no guarantee
     * that the data passed in is the performData returned from checkRelay. This
     * could happen due to malicious relayers, racing relayers, or simply a state
     * change while the performRelay transaction is waiting for confirmation.
     * Always validate the data passed in.
     * @param performData is the data which was passed back from the checkData
     * simulation. If it is encoded, it can easily be decoded into other types by
     * calling `abi.decode`. This data should not be trusted, and should be
     * validated against the contract's current state.
     */
    function performRelay(RelayTypes.RelayRequest calldata relayRequest, bytes calldata performData)
        external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../../utils/RelayTypes.sol';

/**
 * @notice config of the registry
 * @dev only used in params and return values
 * @member paymentPremiumPPB payment premium rate oracles receive on top of
 * being reimbursed for gas, measured in parts per billion
 * @member flatFeeMicroLink flat fee paid to oracles for performing relays,
 * priced in MicroLink; can be used in conjunction with or independently of
 * paymentPremiumPPB
 * @member blockCountPerTurn number of blocks each oracle has during their turn to
 * perform relay before it will be the next relayer's turn to submit
 * @member checkGasLimit gas limit when checking a relay
 * @member stalenessSeconds number of seconds that is allowed for feed data to
 * be stale before switching to the fallback pricing
 * @member gasCeilingMultiplier multiplier to apply to the fast gas feed price
 * when calculating the payment ceiling for relayers
 * @member minRelaySpend minimum LINK that an relay must spend before cancelling
 * @member maxPerformGas max executeGas allowed for a relay on this registry
 * @member fallbackGasPrice gas price used if the gas price feed is stale
 * @member fallbackLinkPrice LINK price used if the LINK price feed is stale
 * @member registrar address of the registrar contract
 */
struct Config {
    uint32 paymentPremiumPPB;
    uint32 flatFeeMicroLink; // min 0.000001 LINK, max 4294 LINK
    uint24 blockCountPerTurn;
    uint32 checkGasLimit;
    uint24 stalenessSeconds;
    uint16 gasCeilingMultiplier;
    uint96 minRelaySpend;
    uint32 maxPerformGas;
    uint256 fallbackGasPrice;
    uint256 fallbackLinkPrice;
    address registrar;
}

/**
 * @notice config of the registry
 * @dev only used in params and return values
 * @member nonce used for ID generation
 * @ownerLinkBalance withdrawable balance of LINK by contract owner
 * @numRelays total number of relays on the registry
 */
struct State {
    uint32 nonce;
    uint96 ownerLinkBalance;
    uint256 expectedLinkBalance;
    uint256 numRelays;
}

interface RelayRegistryInterfaceBase {
    function registerRelay(
        address target,
        uint32 gasLimit,
        address client,
        bytes calldata checkData
    ) external returns (uint256 id);

    function performRelay(
        uint256 id,
        RelayTypes.RelayRequest calldata relayRequest,
        bytes calldata performData
    ) external returns (bool success);

    function cancelRelay(uint256 id) external;

    function addFunds(uint256 id, uint96 amount) external;

    function setRelayGasLimit(uint256 id, uint32 gasLimit) external;

    function getRelay(uint256 id)
        external
        view
        returns (
            address target,
            uint32 executeGas,
            bytes memory checkData,
            uint96 balance,
            address lastRelayer,
            address client,
            uint64 maxValidBlocknumber,
            uint96 amountSpent
        );

    function getActiveRelayIDs(uint256 startIndex, uint256 maxCount)
        external
        view
        returns (uint256[] memory);

    function getRelayerInfo(address query)
        external
        view
        returns (
            address payee,
            bool active,
            uint96 balance
        );

    function getState()
        external
        view
        returns (
            State memory,
            Config memory,
            address[] memory
        );
}

/**
 * @dev The view methods are not actually marked as view in the implementation
 * but we want them to be easily queried off-chain. Solidity will not compile
 * if we actually inherit from this interface, so we document it here.
 */
interface RelayRegistryInterface is RelayRegistryInterfaceBase {
    function checkRelay(
        uint256 relayId,
        address from,
        RelayTypes.RelayRequest calldata relayRequest
    )
        external
        view
        returns (
            bytes memory performData,
            uint256 maxLinkPayment,
            uint256 gasLimit,
            int256 gasWei,
            int256 linkEth
        );
}

interface RelayRegistryExecutableInterface is RelayRegistryInterfaceBase {
    function checkRelay(
        uint256 relayId,
        address from,
        RelayTypes.RelayRequest calldata relayRequest
    )
        external
        returns (
            bytes memory performData,
            uint256 maxLinkPayment,
            uint256 gasLimit,
            uint256 adjustedGasWei,
            uint256 linkEth
        );
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface ERC677ReceiverInterface {
  function onTokenTransfer(
    address sender,
    uint256 amount,
    bytes calldata data
  ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library RelayTypes {
    struct RelayRequest {
        address from;
        address to;
        uint256 value; //mgs.value ether sent with contract call (0)
        uint256 gas; //200 gwei
        uint256 nonce; //(0)
        bytes data; //NOTE: abi encoded selector and params (specific func called)
        //need to look 1. signature (bytes) 2. message digest (bytes32??)
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

import "./interfaces/OwnableInterface.sol";

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwnerWithProposal is OwnableInterface {
  address private s_owner;
  address private s_pendingOwner;

  event OwnershipTransferRequested(address indexed from, address indexed to);
  event OwnershipTransferred(address indexed from, address indexed to);

  constructor(address newOwner, address pendingOwner) {
    require(newOwner != address(0), "Cannot set owner to zero");

    s_owner = newOwner;
    if (pendingOwner != address(0)) {
      _transferOwnership(pendingOwner);
    }
  }

  /**
   * @notice Allows an owner to begin transferring ownership to a new address,
   * pending.
   */
  function transferOwnership(address to) public override onlyOwner {
    _transferOwnership(to);
  }

  /**
   * @notice Allows an ownership transfer to be completed by the recipient.
   */
  function acceptOwnership() external override {
    require(msg.sender == s_pendingOwner, "Must be proposed owner");

    address oldOwner = s_owner;
    s_owner = msg.sender;
    s_pendingOwner = address(0);

    emit OwnershipTransferred(oldOwner, msg.sender);
  }

  /**
   * @notice Get the current owner
   */
  function owner() public view override returns (address) {
    return s_owner;
  }

  /**
   * @notice validate, transfer ownership, and emit relevant events
   */
  function _transferOwnership(address to) private {
    require(to != msg.sender, "Cannot transfer to self");

    s_pendingOwner = to;

    emit OwnershipTransferRequested(s_owner, to);
  }

  /**
   * @notice validate access
   */
  function _validateOwnership() internal view {
    require(msg.sender == s_owner, "Only callable by owner");
  }

  /**
   * @notice Reverts if called by anyone other than the contract owner.
   */
  modifier onlyOwner() {
    _validateOwnership();
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface OwnableInterface {
  function owner() external returns (address);

  function transferOwnership(address recipient) external;

  function acceptOwnership() external;
}