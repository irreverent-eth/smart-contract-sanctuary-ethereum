// TODO:
//
// - Features: 
// - - [ ] commissions
// - - [ ] another rewards except DNT
//
// - QoL:
// - - [+] tests, orders TBD
// - - [ ] deployment
//

// rinkeby addr: 0x1DCab276A5C1E0990779226e506F20F9270b2780

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./nDistributor.sol";
import "../libs/@openzeppelin/contracts/access/Ownable.sol";
import "../libs/@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Liquid staking contract
 */
contract LiquidStaking is Ownable {
    using Counters for Counters.Counter;


    // DECLARATIONS
    //
    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- STAKING SETTINGS 
    // -------------------------------------------------------------------------------------------------------

    // @notice        core staking settings
    uint256   public    totalBalance;
    uint256   public    claimPool;
    uint256   public    minStake;
    uint256[] public    tfs; // staking timeframes

    // @notice DNT distributor
    address public distrAddr;
    NDistributor   distr;

    // @notice    nDistributor required values
    string public utilName = "LS"; // Liquid Staking utility name
    string public DNTname  = "nASTR"; // DNT name

    mapping(address => mapping(uint256 => bool)) public isStakeOwner;
    mapping(address => mapping(uint256 => bool)) public isOrderOwner;


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- STAKE MANAGEMENT 
    // -------------------------------------------------------------------------------------------------------
    
    // @notice Stake struct & identifier
    Counters.Counter stakeIDs;
    struct      Stake {
        uint256 totalBalance;
        uint256 liquidBalance;
        uint256 claimable;
        uint256 rate;

        uint256 startDate;
        uint256 finDate;
        uint256 lastUpdate;
    }

    // @notice Stakes & their IDs
    mapping(uint256 => Stake) public stakes;

    // @notice staking events
    event Staked(address indexed who, uint256 stakeID, uint256 amount, uint256 timeframe);
    event Claimed(address indexed who, uint256 stakeID, uint256 amount);
    event Redeemed(address indexed who, uint256 stakeID, uint256 amount);


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- ORDER MANAGEMENT 
    // -------------------------------------------------------------------------------------------------------
    
    // @notice Order struct & identifier
    Counters.Counter orderIDs;
    struct      Order {
        bool    active;
        address owner;
        uint256 stakeID;
        uint256 price;
    }
    
    // @notice Orders & their IDs
    mapping(uint256 => Order) public orders;

    // @notice order events
    event OrderChange(uint256 id, address indexed seller, bool state, uint256 price);
    event OrderComplete(uint256 id, address indexed seller, address indexed buyer, uint256 price);


    // MODIFIERS

    // @notice checks if msg.sender owns the stake
    // @param  [uint256] id => stake ID
    modifier stakeOwner(uint256 id) {
        require(isStakeOwner[msg.sender][id], "Invalid stake owner!");
        _;
    }

    // @notice checks if msg.sender owns the order
    // @param  [uint256] id => order ID
    modifier orderOwner(uint256 id) {
        require(isOrderOwner[msg.sender][id], "Invalid order owner!");
        _;
    }

    // @notice updates claimable stake values
    // @param  [uint256] id => stake ID
    modifier updateStake(uint256 id) {

        Stake storage s = stakes[id];

        if (block.timestamp - s.lastUpdate < 1 days ) {
            _; // reward update once a day
        } else {
            claimPool -= s.claimable; // i am really sorry for this
            s.claimable = nowClaimable(id);
            claimPool += s.claimable; // i mean really
            s.lastUpdate = block.timestamp;
            _;
        }
    }


    // FUNCTIONS
    //
    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- ADMIN
    // -------------------------------------------------------------------------------------------------------

    // @notice set distributor and DNT addresses, minimum staking amount
    // @param  [address] _distrAddr => DNT distributor address
    // @param  [uint256] _min => minimum value to stake
    constructor(address _distrAddr, uint256 _min) {

        // @dev set distributor address and contract instance
        distrAddr = _distrAddr;
        distr = NDistributor(distrAddr);

        minStake = _min;
    }

    // @notice add new timeframe
    // @param  [uint256] t => new timeframe value
    function addTerm(uint256 t) external onlyOwner {
        tfs.push(t);
    }

    // @notice change timeframe value
    // @param  [uint8]   n => timeframe index
    // @param  [uint256] t => new timeframe value
    function changeTerm(uint8 n, uint256 t) external onlyOwner {
        tfs[n] = t;
    }

    // @notice set distributor
    // @param  [address] a => new distributor address
    function setDistr(address a) external onlyOwner {
        distrAddr = a;
        distr = NDistributor(distrAddr);
    }

    // @notice set minimum stake value
    // @param  [uint256] v => new minimum stake value
    function setMinStake(uint256 v) external onlyOwner {
        minStake = v;
    }


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- Stake managment (stake/redeem tokens, claim DNTs)
    // -------------------------------------------------------------------------------------------------------

    // @notice create new stake with desired timeframe
    // @param  [uint8]   timeframe => desired timeframe index, chosen from tfs[] array
    // @return [uint256] id => ID of created stake
    function stake(uint8 timeframe) external payable returns (uint256 id) {
		require(msg.value >= minStake, "Value less than minimum stake amount");

        uint256 val = msg.value;

        // @dev create new stake
        id = stakeIDs.current();
        stakeIDs.increment();
        stakes[id] = Stake ({
            totalBalance: val,
            liquidBalance: 0,
            claimable: val / 2,
            rate: val / 2 / tfs[timeframe] / 1 days,
            startDate: block.timestamp,
            finDate: block.timestamp + tfs[timeframe],
            lastUpdate: block.timestamp
        });
        isStakeOwner[msg.sender][id] = true;

        // @dev update global balances and emit event
        totalBalance += val;
        claimPool += val / 2;

        emit Staked(msg.sender, id, val, tfs[timeframe]);
    }

    // @notice claim available DNT from stake
    // @param  [uint256] id => stake ID
    // @param  [uint256] amount => amount of requested DNTs
    function claim(uint256 id, uint256 amount) external stakeOwner(id) updateStake(id) {
        require(amount > 0, "Invalid amount!");

        Stake storage s = stakes[id];
        require(s.claimable >= amount, "Invalid amount!");

        // @dev update balances
        s.claimable -= amount;
        s.liquidBalance += amount;
        claimPool -= amount;

        // @dev issue DNT and emit event
        distr.issueDnt(msg.sender, amount, utilName, DNTname);

        emit Claimed(msg.sender, id, amount);
    }

    // @notice redeem DNTs to retrieve native tokens from stake
    // @param  [uint256] id => stake ID
    // @param  [uint256] amount => amount of tokens to redeem
    function redeem(uint256 id, uint256 amount) external stakeOwner(id) {
        require(amount > 0, "Invalid amount!");

        Stake storage s = stakes[id];
        // @dev can redeem only after finDate
        require(block.timestamp > s.finDate, "Cannot do it yet!");

        uint256 uBalance = distr.getUserDntBalanceInUtil(msg.sender, utilName, DNTname);
        require(uBalance >= amount, "Insuffisient DNT balance!");
        s.totalBalance -= amount;
        totalBalance -= amount;

        // @dev burn DNT, send native token, emit event
        distr.removeDnt(msg.sender, amount, utilName, DNTname);
        payable(msg.sender).call{value: amount};

        emit Redeemed(msg.sender, id, amount);
    }

    // @notice returns the amount of DNTs available for claiming right now
    // @param  [uint256] id => stake ID
    // @return [uint256] amount => amount of claimable DNT right now
    function nowClaimable(uint256 id) public view returns (uint256 amount) {

        Stake memory s = stakes[id];

        if ( block.timestamp >= s.finDate) { // @dev if finDate already passed we can claim the rest
            amount = s.totalBalance - s.liquidBalance;
        } else if (block.timestamp - s.lastUpdate < 1 days) { // @dev don't change value if less than 1 day passed
            amount = s.claimable;
        } else { // @dev add claimable based on the amount of days passed
            uint256 d = (block.timestamp - s.lastUpdate) / 1 days;
            amount = s.claimable + s.rate * d;
        }
    }


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- Order managment (sell/buy stakes, cancel order)
    // -------------------------------------------------------------------------------------------------------

    // @notice create new sell order
    // @param  [uint256] id => ID of stake to sell
    // @param  [uint256] p => desired stake price
    // @return [uint256] orderID => ID of created order
    function createOrder(uint256 id, uint256 p) external stakeOwner(id) returns (uint256 orderID) {
        require(p > 0, "Invalid price!");
        require(isStakeOwner[msg.sender][id], "Not your stake!");
        require(stakes[id].totalBalance > 0, "Empty stake!");

        // @dev create new order and add it to user orders
        orderID = orderIDs.current();
        orderIDs.increment();
        orders[orderID] = Order ({
            active: true,
            owner: msg.sender,
            stakeID: id,
            price: p
        });
        isOrderOwner[msg.sender][orderID] = true;

        emit OrderChange(orderID, msg.sender, true, p);
    }

    // @notice cancel created order
    // @param  [uint256] id => order ID
    function cancelOrder(uint256 id) external orderOwner(id) {

        Order storage o = orders[id];

        require(o.active, "Inactive order!");

        o.active = false;

        emit OrderChange(id, msg.sender, false, o.price);
    }

    // @notice set new order price
    // @param  [uint256] id => order ID
    // @param  [uint256] p => new order price
    function setPrice(uint256 id, uint256 p) external orderOwner(id) {

        orders[id].price = p;

        emit OrderChange(id, msg.sender, true, p);
    }

    // @notice buy stake with particular order
    // @param  [uint256] id => order ID
    function buyStake(uint256 id) external payable {
        require(!isOrderOwner[msg.sender][id], "It's your order!");

        Order storage o = orders[id];

        require(o.active, "Inactive order!");
        require(msg.value == o.price, "Insuffisient value!");

        // @dev set order inactive
        o.active = false;

        // @dev change ownership
        isStakeOwner[o.owner][o.stakeID] = false;
        isStakeOwner[msg.sender][o.stakeID] = true;

        // @dev current amount of minted DNT for this stake
        uint256 liquid = stakes[o.stakeID].liquidBalance;

        // @dev update DNT balances if there were any
        if (liquid  > 0) {
            distr.removeDnt(o.owner, liquid, utilName, DNTname);
            distr.issueDnt(msg.sender, liquid, utilName, DNTname);
        }

        // @dev finally pay
        payable(o.owner).call{value: msg.value};

        emit OrderComplete(id, o.owner, msg.sender, o.price);
    }
}

//TODO:
//
// - User structure — should describe the "vault" of the user — keep track of his assets and utils [+]
//
// - Write getter functions to read info about user vaults (users mapping) [+]
// - Get user DNTs [+]
// - Get user utils [+]
// - Get user DNT in util [+]
// - Get user liquid DNT [+]
// - Get user utils in dnt [+]
//
// - Add DNT balance getter function for user from DNT contract [+]
// - DNT removal (burn) logic [+]
// - Token transfer logic (should keep track of user utils) [+]
// - Implement NULL util logic
// - Implement all checks (correct util, dnt, is util active)
// - Figure out token transfer things permissions
//
// - Make universal DNT interface
//     - setInterface
//     - mint
//     - burn
//     - balance
//     - transfer
//
// - Add the rest of the DNT token functions (pause, snapshot, etc) to interface
// - Add those functions to distributor
// - Make sure ownership over DNT tokens isn't lost
// - Add proxy contract for managing access to DNT contracts


// SET-UP:
// 1. Deploy nDistributor
// 2. Deploy nASTR, pass distributor address as constructor arg (makes nDistributor the owner)
// 3. Call "setAstrInterface" in nDistributor with nASTR contract address

// rinkeby addr: 0x5D5ed321b17EAcDD4D0EaCb957da890b6B6761c0
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../libs/@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces/IDNT.sol";


/*
 * @notice ERC20 DNT token distributor contract
 *
 * Features:
 * - Ownable
 */
contract NDistributor is Ownable {

    // DECLARATIONS
    //
    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- USER MANAGMENT
    // -------------------------------------------------------------------------------------------------------

    // @notice                         describes DntAsset structure
    // @dev                            dntInUtil => describes how many DNTs are attached to specific utility
    // @dev                            dntLiquid => describes how many DNTs are liquid and available for imidiate use
    struct                             DntAsset {
        mapping (string => uint256)    dntInUtil;
        string[]                       userUtils;
        uint256                        dntLiquid;
    }

    // @notice                         describes user structure
    // @dev                            dnt => tracks specific DNT token
    struct                             User {
        mapping (string => DntAsset)   dnt;
        string[]                       userDnts;
        string[]                       userUtilities;
    }

    // @dev                            users => describes the user and his portfolio
    mapping (address => User)          users;





    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- UTILITY MANAGMENT
    // -------------------------------------------------------------------------------------------------------

    // @notice                         defidescribesnes utility (Algem offer\opportunity) struct
    struct                             Utility {
        string                         utilityName;
        bool                           isActive;
    }

    // @notice                         keeps track of all utilities
    Utility[] public                   utilityDB;

    // @notice                         allows to list and display all utilities
    string[]                           utilities;

    // @notice                         keeps track of utility ids
    mapping (string => uint) public    utilityId;





    // -------------------------------------------------------------------------------------------------------
    // -------------------------------- DNT TOKENS MANAGMENT
    // -------------------------------------------------------------------------------------------------------

    // @notice                         defidescribesnes DNT token struct
    struct                             Dnt {
        string                         dntName;
        bool                           isActive;
    }

    // @notice                         keeps track of all DNTs
    Dnt[] public                       dntDB;

    // @notice                         allows to list and display all DNTs
    string[]                           dnts;

    // @notice                         keeps track of DNT ids
    mapping (string => uint) public    dntId;

    // @notice                          DNT token contract interface
    address public                      DNTContractAdress;
    IDNT                                DNTContract;





    // FUNCTIONS
    //
    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- Asset managment (utilities and DNTs tracking)
    // -------------------------------------------------------------------------------------------------------

    // @notice                         initializes utilityDB & dntDB
    // @dev                            first element in mapping & non-existing entry both return 0
    //                                 so we initialize it to avoid confusion
    // @dev                            "null" utility also means tokens not connected to utility
    //                                 these could be used in any utility
    //                                 for example, after token trasfer, reciever will get "null" utility
    constructor() {
        utilityDB.push(Utility("null", true));
        dntDB.push(Dnt("null", false));
        DNTContractAdress = address(0x00);
    }

    // @notice                         returns the list of all utilities
    function                           listUtilities() external view returns(string[] memory) {
        return utilities;
    }

    // @notice                         returns the list of all DNTs
    function                           listDnts() external view returns(string[] memory) {
        return dnts;
    }

    // @notice                         adds new utility to the DB, activates it by default
    // @param                          [string] _newUtility => name of the new utility
    function                           addUtility(string memory _newUtility) external onlyOwner {
        uint                           lastId = utilityDB.length;

        utilityId[_newUtility] = lastId;
        utilityDB.push(Utility(_newUtility, true));
        utilities.push(_newUtility);
    }

    // @notice                         adds new DNT to the DB, activates it by default
    // @param                          [string] _newDnt => name of the new DNT
    function                           addDnt(string memory _newDnt) external onlyOwner { // <--------- also set contract address for interface here
        uint                           lastId = dntDB.length;

        dntId[_newDnt] = lastId;
        dntDB.push(Dnt(_newDnt, true));
        dnts.push(_newDnt);
    }

    // @notice                         allows to activate\deactivate utility
    // @param                          [uint256] _id => utility id
    // @param                          [bool] _state => desired state
    function                           setUtilityStatus(uint256 _id, bool _state) public onlyOwner {
        utilityDB[_id].isActive = _state;
    }

    // @notice                         allows to activate\deactivate DNT
    // @param                          [uint256] _id => DNT id
    // @param                          [bool] _state => desired state
    function                           setDntStatus(uint256 _id, bool _state) public onlyOwner { // -----
        dntDB[_id].isActive = _state;
    }

    // @notice                         returns a list of user's DNT tokens in possession
    // @param                          [address] _user => user address
    function                           listUserDnts(address _user) public view returns(string[] memory) {
        return (users[_user].userDnts);
    }

    // @notice                         returns ammount of liquid DNT toknes in user's possesion
    // @param                          [address] _user => user address
    // @param                          [string] _dnt => DNT token name
    function                           getUserLiquidDnt(address _user, string memory _dnt) public view returns(uint256) {
        return (users[_user].dnt[_dnt].dntLiquid);
    }

    // @notice                         returns ammount of DNT toknes of user in utility
    // @param                          [address] _user => user address
    // @param                          [string] _util => utility name
    // @param                          [string] _dnt => DNT token name
    function                           getUserDntBalanceInUtil(address _user, string memory _util, string memory _dnt) public view returns(uint256) {
        return (users[_user].dnt[_dnt].dntInUtil[_util]);
    }

    // @notice                         returns which utilities are used with specific DNT token
    // @param                          [address] _user => user address
    // @param                          [string] _dnt => DNT token name
    function                           getUserUtilsInDnt(address _user, string memory _dnt) public view returns(string[] memory) {
        return (users[_user].dnt[_dnt].userUtils);
    }

    // @notice                         returns user's DNT balance
    // @param                          [address] _user => user address
    // @param                          [string] _dnt => DNT token name
    function                           getUserDntBalance(address _user, string memory _dnt) public returns(uint256) { // <--------- make universal dnt interface
        require(DNTContractAdress != address(0x00), "Interface not set!");

        return (DNTContract.balanceOf(_user));
    }





    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- Distribution logic
    // -------------------------------------------------------------------------------------------------------

    // @notice                         issues new tokens
    // @param                          [address] _to => token recepient
    // @param                          [uint256] _amount => amount of tokens to mint
    // @param                          [string] _utility => minted dnt utility
    // @param                          [string] _dnt => minted dnt
    function                           issueDnt(address _to, uint256 _amount, string memory _utility, string memory _dnt) public { // <-------- DNT contract selection needed
        uint256                        id;

        require(DNTContractAdress != address(0x00), "Interface not set!");
        require((id = utilityId[_utility]) > 0, "Non-existing utility!");
        require(utilityDB[id].isActive == true, "Inactive utility!");

        _addDntToUser(_dnt, users[_to].userDnts);
        _addUtilityToUser(_utility, users[_to].userUtilities);
        _addUtilityToUser(_utility, users[_to].dnt[_dnt].userUtils);

        users[_to].dnt[_dnt].dntInUtil[_utility] += _amount;
        users[_to].dnt[_dnt].dntLiquid += _amount;
        DNTContract.mintNote(_to, _amount);
    }

    // @notice                         adds dnt string to user array of dnts for tracking which assets are in possession
    // @param                          [string] _dnt => name of the dnt token
    // @param                          [string[] ] localUserDnts => array of user's dnts
    function                           _addDntToUser(string memory _dnt, string[] storage localUserDnts) internal {
        uint256                        id = dntId[_dnt];
        uint                           l;
        uint                           i = 0;

        require(utilityDB[id].isActive == true, "Non-existing DNT!");
        require(dntDB[id].isActive == true, "Inactive DNT token!");

        l = localUserDnts.length;
        for (i; i < l; i++) {
            if (keccak256(abi.encodePacked(localUserDnts[i])) == keccak256(abi.encodePacked(_dnt))) {
                return;
            }
        }
        localUserDnts.push(_dnt);
        return;
    }

    // @notice                         adds utility string to user array of utilities for tracking which assets are in possession
    // @param                          [string] _utility => name of the utility token
    // @param                          [string[] ] localUserUtilities => array of user's utilities
    function                           _addUtilityToUser(string memory _utility, string[] storage localUserUtilities) internal {
        uint                           l;
        uint                           i = 0;

        l = localUserUtilities.length;
        for (i; i < l; i++) {
            if (keccak256(abi.encodePacked(localUserUtilities[i])) == keccak256(abi.encodePacked(_utility))) {
                return;
            }
        }
        localUserUtilities.push(_utility);
        return;
    }

    // @notice                         removes tokens from circulation
    // @param                          [address] _account => address to burn from
    // @param                          [uint256] _amount => amount of tokens to burn
    // @param                          [string] _utility => minted dnt utility
    // @param                          [string] _dnt => minted dnt
    function                           removeDnt(address _account, uint256 _amount, string memory _utility, string memory _dnt) public { // <-------- DNT contract selection needed
        uint256                        id;

        require(DNTContractAdress != address(0x00), "Interface not set!");

        require((id = utilityId[_utility]) > 0, "Non-existing utility!");
        require(utilityDB[id].isActive == true, "Inactive utility!");

        require(users[_account].dnt[_dnt].dntInUtil[_utility] >= _amount, "Not enough DNT in utility!");
        require(users[_account].dnt[_dnt].dntLiquid >= _amount, "Not enough liquid DNT!");

        users[_account].dnt[_dnt].dntInUtil[_utility] -= _amount;
        users[_account].dnt[_dnt].dntLiquid -= _amount;

        if (users[_account].dnt[_dnt].dntInUtil[_utility] == 0) {
            _removeUtilityFromUser(_utility, users[_account].userUtilities);
            _removeUtilityFromUser(_utility, users[_account].dnt[_dnt].userUtils);
        }
        if (users[_account].dnt[_dnt].dntLiquid == 0) {
            _removeDntFromUser(_dnt, users[_account].userDnts);
        }

        DNTContract.burnNote(_account, _amount);
    }

    // @notice                         removes utility string from user array of utilities
    // @param                          [string] _utility => name of the utility token
    // @param                          [string[] ] localUserUtilities => array of user's utilities
    function                           _removeUtilityFromUser(string memory _utility, string[] storage localUserUtilities) internal {
        uint                           l;
        uint                           i = 0;

        l = localUserUtilities.length;
        for (i; i < l; i++) {
            if (keccak256(abi.encodePacked(localUserUtilities[i])) == keccak256(abi.encodePacked(_utility))) {
                delete localUserUtilities[i];
                return;
            }
        }
        return;
    }

    // @notice                         removes DNT string from user array of DNTs
    // @param                          [string] _dnt => name of the DNT token
    // @param                          [string[] ] localUserDnts => array of user's DNTs
    function                           _removeDntFromUser(string memory _dnt, string[] storage localUserDnts) internal {
        uint                           l;
        uint                           i = 0;

        l = localUserDnts.length;
        for (i; i < l; i++) {
            if (keccak256(abi.encodePacked(localUserDnts[i])) == keccak256(abi.encodePacked(_dnt))) {
                delete localUserDnts[i];
                return;
            }
        }
        return;
    }

    // @notice                         transfers tokens between users
    // @param                          [address] _from => token sender
    // @param                          [address] _to => token recepient
    // @param                          [uint256] _amount => amount of tokens to send
    // @param                          [string] _utility => transfered dnt utility
    // @param                          [string] _dnt => transfered DNT
    function                           transferDnt(address _from,
                                                   address _to,
                                                   uint256 _amount,
                                                   string memory _utility,
                                                   string memory _dnt) public onlyOwner {
        require(users[_from].dnt[_dnt].dntInUtil[_utility] >= _amount, "Not enough DNT tokens in utility!");

        removeDnt(_from, _amount, _utility, _dnt);
        issueDnt(_to, _amount, "null", _dnt);
    }

    // @notice                         allows to set a utility to free tokens (marked with null utility)
    // @param                          [address] _user => token owner
    // @param                          [uint256] _amount => amount of tokens to assign
    // @param                          [string] _newUtility => utility to set
    // @param                          [string] _dnt => DNT token
    function                           assignUtilityToNull(address _user,
                                                           uint256 _amount,
                                                           string memory _newUtility,
                                                           string memory _dnt) public onlyOwner {
      require(users[_user].dnt[_dnt].dntInUtil["null"] >= _amount, "Not enough free tokens!");
      removeDnt(_user, _amount, "null", _dnt);
      issueDnt(_user, _amount, _newUtility, _dnt);
    }





    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- Admin
    // -------------------------------------------------------------------------------------------------------

    // @notice                          allows to specify nASTR token contract address
    // @param                           [address] _contract => nASTR contract address
    function                            setAstrInterface(address _contract) external onlyOwner {
        DNTContractAdress = _contract;
        DNTContract = IDNT(DNTContractAdress);
    }

    // @notice                          allows to transfer ownership of the DNT contract
    // @param                           [address] to => new owner
    // @param                           [string] dntToken => name of the dnt token contract
    function                            transferDntContractOwnership(address to) public onlyOwner {  // <----------------------- Add contract selection
        DNTContract.transferOwnership(to);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// @notice DNT token contract interface
interface IDNT {
  function        mintNote(address to, uint256 amount) external;
  function        burnNote(address account, uint256 amount) external;
  function        snapshot() external;
  function        pause() external;
  function        unpause() external;
  function        transferOwnership(address to) external;
  function        balanceOf(address account) external returns(uint256);
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