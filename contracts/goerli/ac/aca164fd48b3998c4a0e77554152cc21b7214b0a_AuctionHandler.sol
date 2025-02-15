pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import './interfaces/IMoonFactory.sol';
import './Vault.sol';

contract AuctionHandler is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint;

    struct AuctionInfo {
        uint startTime;
        uint endTime;
        address moonToken;
        uint256 nftIndexForMoonToken;
        bool claimable;
        bool claimed;
    }

    struct Bid {
    	address bidder;
    	uint256 amount;
    }

    // Info of each pool.
    AuctionInfo[] public auctionInfo;

    // Auction index to bid
    mapping(uint256 => Bid) public bids;
    // Auction index to user address to amount
    mapping(uint256 => mapping(address => uint256)) public bidRefunds;
    // moonToken address to NFT index to auction index
    mapping(address => mapping(uint256 => uint256)) public auctionIndex;
    // moonToken address to NFT index to bool
    mapping(address => mapping(uint256 => bool)) public auctionStarted;
    // moonToken address to vault balances
    mapping(address => uint256) public vaultBalances;

    IMoonFactory public factory;
    // 129600 or 36 hours
    uint public duration;
    // 105 = next bid must be 5% above top bid to be new top bid
    uint8 public minBidMultiplier;
    // 5 minutes
    uint public auctionExtension;
    // 50 (2%)
    uint8 public feeDivisor;

    address public feeToSetter;
    address public feeTo;

    event AuctionCreated(uint256 indexed auctionId, address indexed moonToken, uint256 nftIndexForMoonToken, uint startTime, uint indexed endTime);
    event BidCreated(uint256 indexed auctionId, address indexed bidder, uint256 amount, uint indexed endTime);
    event BidRemoved(uint256 indexed auctionId, address indexed bidder);
    event ClaimedNFT(uint256 indexed auctionId, address indexed winner);

    function initialize(
        address _factory,
        uint _duration,
        uint8 _minBidMultiplier,
        uint _auctionExtension,
        uint8 _feeDivisor,
        address _feeToSetter,
        address _feeTo
    ) public initializer {
        require(_factory != address(0) && _feeToSetter != address(0) && _feeTo != address(0), "Invalid address");
        require(_minBidMultiplier > 100 && _minBidMultiplier < 200, "Invalid multiplier");
        require(_feeDivisor > 1, "Invalid fee divisor");
        require(_feeDivisor > uint256(100).div(uint256(100).mul(_minBidMultiplier).div(100).sub(100)), "Invalid fee vs multiplier");
        __Ownable_init();
        factory = IMoonFactory(_factory);
        duration = _duration;
        minBidMultiplier = _minBidMultiplier;
        auctionExtension = _auctionExtension;
        feeDivisor = _feeDivisor;
        feeToSetter = _feeToSetter;
        feeTo = _feeTo;
    }

    function auctionLength() external view returns (uint256) {
        return auctionInfo.length;
    }

    function newAuction(address _moonToken, uint256 _nftIndexForMoonToken) public payable {
        require(IMoonFactory(factory).getMoonToken(_moonToken) != 0 || IMoonFactory(factory).moonTokens(0) == _moonToken, 
            "AuctionHandler: moonToken contract must be valid");
        require(Vault(_moonToken).active(), "AuctionHandler: Can not bid on inactive moonToken");
        //get the contract address and trigger price of the given NFT
        (address contractAddr, , , uint256 triggerPrice) = Vault(_moonToken).nfts(_nftIndexForMoonToken);
        //verify that the vault is not in crowdfund
        require(Vault(_moonToken).crowdfundingMode() == false, "AuctionHandler: newAuction: Can not bid on NFTs in crowdfunding mode");
        // Check that nft index exists on vault contract
        require(contractAddr != address(0), "AuctionHandler: NFT index must exist");
        // Check that bid meets reserve price
        require(triggerPrice <= msg.value, "AuctionHandler: Starting bid must be higher than trigger price");
        require(!auctionStarted[_moonToken][_nftIndexForMoonToken], "AuctionHandler: NFT already on auction");
        auctionStarted[_moonToken][_nftIndexForMoonToken] = true;

        uint256 currentIndex = auctionInfo.length;
        uint auctionEndTime = getBlockTimestamp().add(duration);

        auctionInfo.push(
            AuctionInfo({
                startTime: getBlockTimestamp(),
                endTime: auctionEndTime,
                moonToken: _moonToken,
                nftIndexForMoonToken: _nftIndexForMoonToken,
                claimable: false,
                claimed: false
            })
        );

        auctionIndex[_moonToken][_nftIndexForMoonToken] = currentIndex;
        uint256 fee = msg.value.div(feeDivisor);
        vaultBalances[_moonToken] = vaultBalances[_moonToken].add(msg.value.sub(fee));
        bids[currentIndex] = Bid(msg.sender, msg.value);
        sendFee(fee);

        emit AuctionCreated(currentIndex, _moonToken, _nftIndexForMoonToken, getBlockTimestamp(), auctionEndTime);
        emit BidCreated(currentIndex, msg.sender, msg.value, auctionEndTime);
    }

    function bid(uint256 _auctionId) public payable {
        AuctionInfo storage thisAuction = auctionInfo[_auctionId];
        require(getBlockTimestamp() < thisAuction.endTime, "AuctionHandler: Auction for NFT ended");
        require(Vault(thisAuction.moonToken).active(), "AuctionHandler: Can not bid on inactive moonToken");

        Bid storage topBid = bids[_auctionId];
        require(topBid.bidder != msg.sender, "AuctionHandler: You have an active bid");
        require(topBid.amount.mul(minBidMultiplier) <= msg.value.mul(100), "AuctionHandler: Bid too low");
        require(bidRefunds[_auctionId][msg.sender] == 0, "AuctionHandler: Collect bid refund first");

        // Case where new top bid occurs near end time
        // In this case we add an extension to the auction
        if(getBlockTimestamp() > thisAuction.endTime.sub(auctionExtension)) {
            thisAuction.endTime = getBlockTimestamp().add(auctionExtension);
        }

        bidRefunds[_auctionId][topBid.bidder] = topBid.amount;
        uint256 fee = (msg.value.sub(topBid.amount)).div(feeDivisor);
        vaultBalances[thisAuction.moonToken] = vaultBalances[thisAuction.moonToken].add(msg.value).sub(topBid.amount).sub(fee);

        topBid.bidder = msg.sender;
        topBid.amount = msg.value;

        sendFee(fee);

        emit BidCreated(_auctionId, msg.sender, msg.value, thisAuction.endTime);
    }

    function unbid(uint256 _auctionId) public {
        Bid memory topBid = bids[_auctionId];
        require(topBid.bidder != msg.sender, "AuctionHandler: Top bidder can not unbid");

        uint256 refundAmount = bidRefunds[_auctionId][msg.sender];
        require(refundAmount > 0, "AuctionHandler: No bid found");
        bidRefunds[_auctionId][msg.sender] = 0;
        (bool sent, bytes memory data) = msg.sender.call{value: refundAmount}("");
        require(sent, "AuctionHandler: Failed to send Ether");

        emit BidRemoved(_auctionId, msg.sender);
    }

    // after the auction ends, a proposer or the issuer must make a proposal to toggleClaimable() if they and the community want to sell the NFT
    //if vote goes through, this function will be called and the NFT will be claimable
    function toggleClaimable(uint256 _auctionId) public {
        AuctionInfo storage thisAuction = auctionInfo[_auctionId];
        //require that the sender is the vault's timelock or moonlight
        //post-beta remove allowing the curator to call this function
        require(msg.sender == Vault(thisAuction.moonToken).vaultTimeLock() || msg.sender == factory.owner() || msg.sender == Vault(thisAuction.moonToken).issuer(), "AuctionHandler::toggleClaimable : Only vault's timelock or moonlight can toggle claimable");
        require(getBlockTimestamp() > thisAuction.endTime, "AuctionHandler::toggleClaimable : Auction duration must have ended");

        thisAuction.claimable = !thisAuction.claimable;
    }


    // Claim NFT if address is winning bidder
    function claim(uint256 _auctionId) public {
        AuctionInfo storage thisAuction = auctionInfo[_auctionId];
        require(getBlockTimestamp() > thisAuction.endTime, "AuctionHandler: Auction or buffer period is not over");
        require(thisAuction.claimable, "AuctionHandler: claim: Auction is not claimable");
        require(!thisAuction.claimed, "AuctionHandler: Already claimed");
        Bid memory topBid = bids[_auctionId];
        require(msg.sender == topBid.bidder, "AuctionHandler: Only winner can claim");

        thisAuction.claimed = true;

        require(Vault(thisAuction.moonToken).claimNFT(thisAuction.nftIndexForMoonToken, topBid.bidder), "AuctionHandler: Claim failed");

        emit ClaimedNFT(_auctionId, topBid.bidder);
    }

    //how a user can withdraw pro-rata shares of auction proceeds
    function burnAndRedeem(address _moonToken, uint256 _amount) public {
        require(vaultBalances[_moonToken] > 0, "AuctionHandler: No vault balance to redeem from");

        uint256 redeemAmount = _amount.mul(vaultBalances[_moonToken]).div(IERC20Upgradeable(_moonToken).totalSupply());
        Vault(_moonToken).burnFrom(msg.sender, _amount);
        vaultBalances[_moonToken] = vaultBalances[_moonToken].sub(redeemAmount);

        // Redeem ETH corresponding to moonToken amount
        (bool sent, bytes memory data) = msg.sender.call{value: redeemAmount}("");
        require(sent, "AuctionHandler: Failed to send Ether");
    }

    // This function is for fee-taking
    function sendFee(uint256 _fees) internal {
        // Send fee to feeTo address
        (bool sent, bytes memory data) = feeTo.call{value: _fees}("");
        require(sent, "AuctionHandler: Failed to send Ether");
    }

    function setFactory(address _factory) public onlyOwner {
        factory = IMoonFactory(_factory);
    }

    function setAuctionParameters(uint _duration, uint8 _minBidMultiplier, uint _auctionExtension, uint8 _feeDivisor) public onlyOwner {
        require(_duration > 0 && _auctionExtension > 0, "AuctionHandler: Invalid parameters");
        require(_minBidMultiplier > 100 && _minBidMultiplier < 200, "Invalid multiplier");
        require(_feeDivisor > 1, "Invalid fee divisor");
        require(_feeDivisor > uint256(100).div(uint256(100).mul(_minBidMultiplier).div(100).sub(100)), "Invalid fee vs multiplier");
        duration = _duration;
        minBidMultiplier = _minBidMultiplier;
        auctionExtension = _auctionExtension;
        feeDivisor = _feeDivisor;
    }

    function setFeeTo(address _feeTo) public {
        require(msg.sender == feeToSetter, "AuctionHandler: Not feeToSetter");
        require(_feeTo != address(0), "AuctionHandler: Fee address cannot be zero address");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) public {
        require(msg.sender == feeToSetter, "AuctionHandler: Not feeToSetter");
        feeToSetter = _feeToSetter;
    }
    
    function setFeeDivisor(uint8 _feeDivisor) external {
        require(msg.sender == factory.owner() || msg.sender == feeToSetter, "AuctionHandler::setFeeDivisor: Not allowed to set fee divisor");
        feeDivisor = _feeDivisor;

    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }

    function onAuction(address moonToken, uint256 nftIndexForMoonToken) external view returns (bool) {
        return auctionStarted[moonToken][nftIndexForMoonToken];
    }
}

pragma solidity 0.6.12;

interface IVault {
    function setVaultTimeLock(address _vaultTimeLock) external;
}

pragma solidity >=0.5.0;

interface IProxyTransaction {
    function forwardCall(address target, uint256 value, bytes calldata callData) external payable returns (bool success, bytes memory returnData);
}

pragma solidity >=0.5.0;

interface IMoonFactory {
    event TokenCreated(address indexed caller, address indexed moonToken);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function vaultImplementation() external view returns (address);

    function getMoonToken(address moonToken) external view returns (uint);
    function moonTokens(uint) external view returns (address);
    function moonTokensLength() external view returns (uint);
    function getGovernorAlpha(address moonToken) external view returns (address);
    function feeDivisor() external view returns (uint);
    function auctionHandler() external view returns (address);
    function moonTokenSupply() external view returns (uint);
    function owner() external view returns (address);
    function proxyTransactionFactory() external view returns (address);
    function crowdfundDuration() external view returns (uint);
    function crowdfundFeeDivisor() external view returns (uint);
    function usdCrowdfundingPrice() external view returns (uint);

    function createMoonToken(
        string calldata name,
        string calldata symbol,
        bool enableProxyTransactions, 
        bool crowdfundingMode ,
        uint256 supply
    ) external returns (address, address);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setVaultImplementation(address) external;
    function setFeeDivisor(uint) external;
    function setAuctionHandler(address) external;
    function setSupply(uint) external;
    function setProxyTransactionFactory(address _proxyTransactionFactory) external;
}

pragma solidity 0.6.12;

interface IGetAuctionInfo {
    function onAuction(address uToken, uint nftIndexForUToken) external view returns (bool);
}

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

/**
 * Expand the ERC20Burnable contract to include a governance voting feature.
 */
abstract contract ERC20VotesUpgradeable is ERC20BurnableUpgradeable  {
    using SafeMathUpgradeable for uint256;

    //see some docs/explanation online of how erc20votes works
    //GIO IMPLEMENT A CHECK IN DELEGATE THAT MAKES SURE CURRENT/PRIOR VOTES ARE BELOW 35% OF TOTAL SUPPLY

    // Copied and modified from YAM code:
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
    // Which is copied and modified from COMPOUND:
    // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol

    /// @dev A record of each accounts delegate
    mapping (address => address) internal _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegator The address to get delegatee for
     */
    function delegates(address delegator)
    external
    view
    returns (address)
    {
        return _delegates[delegator];
    }

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
    external
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATION_TYPEHASH,
                delegatee,
                nonce,
                expiry
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "UNIC::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "UNIC::delegateBySig: invalid nonce");
        require(now <= expiry, "UNIC::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account)
    external
    view
    returns (uint256)
    {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber)
    external
    view
    returns (uint256)
    {
        require(blockNumber < block.number, "MOON::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee)
    internal
    {
        address currentDelegate = _delegates[delegator];
        //here check balance of less than 35%. in write checkpoint, only give 35% of token supply
        uint256 delegatorBalance = balanceOf(delegator); // balance of underlying tokens (not scaled);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld.sub(amount);
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld.add(amount);
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    )
    internal
    {
        uint32 blockNumber = safe32(block.number, "UNIC::_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal pure returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./interfaces/IMoonFactory.sol";
import "./interfaces/IProxyTransaction.sol";
import "./interfaces/IGetAuctionInfo.sol"; 
import "./interfaces/IVault.sol";
import "./abstract/ERC20VotesUpgradeable.sol";

//for chainlink price feed
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

contract Vault is IVault, IProxyTransaction, Initializable, ERC1155ReceiverUpgradeable, ERC20VotesUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint;

    //list of target NFTs for crowdfunding
    struct TargetNft {
        address nftContract;
        uint tokenId;
        uint amount;
        uint buyNowPrice;
    }

    mapping(uint256 => TargetNft) public targetNfts;
    uint256 public targetNFTIndex;

    // List of NFTs that have been deposited
    struct NFT {
    	address contractAddr;
    	uint256 tokenId;
        uint256 amount;
        uint256 triggerPrice;
    }

    mapping(uint256 => NFT) public nfts;
    // Current index and length of nfts
    uint256 public currentNFTIndex;
    // If active, NFTs can’t be withdrawn
    bool public active; //default in solidity is false
    address public issuer;
    uint256 public cap; //whatever the current supply of tokens is
    address public vaultTimeLock;
    IMoonFactory public factory;

    ////////////////CROWDFUND////////////////////
    //whether or not this is currently in crowdfund stage
    bool public crowdfundingMode;
    //current crowdfund goal based on buy now prices
    uint256 public crowdfundGoal;
    //how much funded so far
    uint256 public fundedSoFar;
    //tracking how much stake users have in this crowdfund
    mapping (address => uint) public ethContributed;
    mapping (address => uint) public amountOwned;
    //tracking how much contribution fees have been collected to the vault
    uint256 contributionFees;
    //chainlink aggregator interface for price feed
    AggregatorV3Interface internal priceFeed;
    //how much ETH the crowdfund token is worth, (artificially) set upon creation by the crowdfund creator at $10 per token (must use chainlink price oracle)
    uint public moonTokenCrowdfundingPrice;
    //crowdfund time tracking
    uint public duration;
    uint public startTime;
    uint public endTime;

    event Deposited(uint256[] tokenIDs, uint256[] amounts, uint256[] triggerPrices, address indexed contractAddr);
    event Refunded();
    event Issued();
    event TriggerPriceUpdate(uint256[] indexed nftIndex, uint[] price);
    event TargetAdded(uint256[] tokenIDs, uint256[] amounts, uint256[] buyNowPrices, address[] indexed contractAddr);
    event TargetUpdated(uint256 indexed targetNftIndex, uint256 tokenID, uint256 amount, address indexed contractAddr);
    event UpdatedGoal(uint256 newGoal);
    event BuyPriceUpdate(uint256[] indexed targetNftIndex, uint[] buyNowPrices);
    event PurchasedCrowdfund(address indexed buyer, uint256 amount);
    event WithdrawnCrowdfund(address indexed user);
    event CrowdfundSuccess();
    event BoughtNfts();
    event TerminatedCrowdfund();

    bytes private constant VALIDATOR = bytes('JCMY');

    function initialize (
        string memory name,
        string memory symbol,
        address _issuer,
        address _factory, 
        bool _crowdfundingMode, 
        uint256 _supply
    )
        public
        initializer
        returns (bool)
    {
        require(_issuer != address(0) && _factory != address(0), "Invalid address");
        __Ownable_init();
        __ERC20_init(name, symbol);
        crowdfundingMode = _crowdfundingMode;
        issuer = _issuer; //issuer is curator
        factory = IMoonFactory(_factory);

        if (_crowdfundingMode) {
            startTime = getBlockTimestamp();
            endTime = startTime.add(factory.crowdfundDuration());
            /**
            * Network: Kovan
            * Aggregator: ETH/USD
            * Address: 0x9326BFA02ADD2366b30bacB125260Af641031331
            * set the price feed. **change to eth mainnet after testing is done**
            */
            priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);

            //set the moonToken CrowdfundingPrice (a temporary price during crowdfund)= 10 dollars of ETH
            //limit moonTokenCrowdfundingPrice bound. 100,000,000,000,000
            moonTokenCrowdfundingPrice = (uint256)(10**18).mul( factory.usdCrowdfundingPrice().div( uint(getLatestPrice()).div(10**8) ) ); //convert ether to wei by * 10^18
        }
        else {
            cap = _supply;
        }

        return true;
    }

    function getLatestPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price;
    }

    function burn(address _account, uint256 _amount) public {
        require(msg.sender == factory.auctionHandler(), "Vault: Only auction handler can burn");
        super._burn(_account, _amount);
    }

    function setCurator(address _issuer) external {
        require(active, "Vault: Tokens have not been issued yet");
        require(msg.sender == factory.owner() || msg.sender == issuer, "Vault: Not vault manager or issuer");

        issuer = _issuer;
    }

    function setTriggers(uint256[] calldata _nftIndex, uint256[] calldata _triggerPrices) external {
        require(msg.sender == issuer, "Vault: Only issuer can set trigger prices");
        require(_nftIndex.length <= 50, "Vault: A maximum of 50 trigger prices can be set at once");
        require(_nftIndex.length == _triggerPrices.length, "Array length mismatch");
        require(crowdfundingMode == false, "Vault: Crowdfund is on");

        for (uint8 i = 0; i < 50; i++) {
            if (_nftIndex.length == i) {
                break;
            }
            // require(!IGetAuctionInfo(factory.auctionHandler()).onAuction(address(this), _nftIndex[i]), "Vault: Already on auction");
            nfts[_nftIndex[i]].triggerPrice = _triggerPrices[i];
        }

        emit TriggerPriceUpdate(_nftIndex, _triggerPrices);
    }

    function setVaultTimeLock(address _vaultTimeLock) public override {
        require(msg.sender == address(factory), "Vault: Only factory can set vaultTimeLock");
        require(_vaultTimeLock != address(0), "Invalid address");
        vaultTimeLock = _vaultTimeLock;
    }

    //can add multiple NFTs with this but only if they come from the same collection (contractAddr)
    //otherwise will have to call this func multiple times for different NFT contracts
    //notify user that buy now price is for the whole bundle
    function addTargetNft(uint256[] calldata tokenIDs, uint256[] calldata amounts, uint256[] calldata buyNowPrices, address[] calldata contractAddr) external {
        require(msg.sender == issuer, "Vault: Only issuer can add target NFTs");
        require(tokenIDs.length <= 50, "Vault: A maximum of 50 tokens can be added in one go");
        require(tokenIDs.length > 0, "Vault: You must specify at least one token ID");
        require(tokenIDs.length == buyNowPrices.length, "Array length mismatch");
        require(crowdfundingMode == true, "Vault: Crowdfund is not on");

        for (uint8 i = 0; i < 50; i++){
            if (i == tokenIDs.length) {
                break;
            }

            //if it is an ERC1155 we will take the amounts[] they give us
            if(ERC165CheckerUpgradeable.supportsInterface(contractAddr[i], 0xd9b67a26)) {
                targetNfts[targetNFTIndex++] = TargetNft(contractAddr[i], tokenIDs[i], amounts[i], buyNowPrices[i]);
            }
            //else it is ERC721 and amounts will always be 1
            else {
                targetNfts[targetNFTIndex++] = TargetNft(contractAddr[i], tokenIDs[i], 1, buyNowPrices[i]);
            }

        }
        
        /*
        //if it is an ERC1155 we will take the amounts[] they give us
        if (ERC165CheckerUpgradeable.supportsInterface(contractAddr, 0xd9b67a26)){
            for (uint8 i = 0; i < 50; i++){
                if (i == tokenIDs.length) {
                    break;
                }
                targetNfts[targetNFTIndex++] = TargetNft(contractAddr, tokenIDs[i], amounts[i], buyNowPrices[i]);
            }
        }
        //else it is ERC721 and amounts will always be 1
        else {
            for (uint8 i = 0; i < 50; i++){
                if (i == tokenIDs.length) {
                    break;
                }
                targetNfts[targetNFTIndex++] = TargetNft(contractAddr, tokenIDs[i], 1, buyNowPrices[i]);
            }
        } */
        
        //update the crowdfund goal
        updateCrowdfundGoal();
        emit TargetAdded(tokenIDs, amounts, buyNowPrices, contractAddr);
    }

    function setBuyNowPrices(uint256[] calldata _targetNftIndex, uint256[] calldata _buyNowPrices) external {
        //important note that for erc1155, buy-now price is of the whole batch (of amount)
        //post-MVP: chainlink => opensea API. update periodically
        require(msg.sender == issuer, "Vault: Only issuer can set buy prices");
        require(_targetNftIndex.length <= 50, "Vault: A maximum of 50 buy prices can be set at once");
        require(_targetNftIndex.length == _buyNowPrices.length, "Array length mismatch");
        require(crowdfundingMode == true, "Vault: Crowdfund is not on");
        for (uint8 i = 0; i < 50; i++) {
            if (_targetNftIndex.length == i) {
                break;
            }
            targetNfts[_targetNftIndex[i]].buyNowPrice = _buyNowPrices[i];
        }

        emit BuyPriceUpdate(_targetNftIndex, _buyNowPrices);
        updateCrowdfundGoal();
    }

    //call this internally whenever buy prices change
    function updateCrowdfundGoal() public {
        require(crowdfundingMode == true, "Vault: Crowdfund is not on");
        crowdfundGoal = 0;

        //post-MVP: automatically update buy prices here, then make setBuyNowPrices() as onlyOwner

        for (uint8 i = 0; i < targetNFTIndex; i++) {
            crowdfundGoal += targetNfts[i].buyNowPrice;
        }
        emit UpdatedGoal(crowdfundGoal);

    }

    // deposits an nft using the transferFrom action of the NFT contractAddr
    //can only do from one contract address at a time because transfer function is either ERC721 or ERC1155
    function deposit(uint256[] calldata tokenIDs, uint256[] calldata amounts, uint256[] calldata triggerPrices, address contractAddr) external {
        require(msg.sender == issuer, "Vault: Only issuer can deposit");
        require(tokenIDs.length <= 50, "Vault: A maximum of 50 tokens can be deposited in one go");
        require(tokenIDs.length > 0, "Vault: You must specify at least one token ID");
        require(tokenIDs.length == triggerPrices.length, "Array length mismatch");

        //this if statement checks if the contractAddr is an ERC1155 contract
        if (ERC165CheckerUpgradeable.supportsInterface(contractAddr, 0xd9b67a26)){
            IERC1155Upgradeable(contractAddr).safeBatchTransferFrom(msg.sender, address(this), tokenIDs, amounts, VALIDATOR);

            for (uint8 i = 0; i < 50; i++){
                if (tokenIDs.length == i){
                    break;
                }
                nfts[currentNFTIndex++] = NFT(contractAddr, tokenIDs[i], amounts[i], triggerPrices[i]);
            }
        }
        else {
            for (uint8 i = 0; i < 50; i++){
                if (tokenIDs.length == i){
                    break;
                }
                IERC721Upgradeable(contractAddr).transferFrom(msg.sender, address(this), tokenIDs[i]);
                nfts[currentNFTIndex++] = NFT(contractAddr, tokenIDs[i], 1, triggerPrices[i]);
            }
        }

        emit Deposited(tokenIDs, amounts, triggerPrices, contractAddr);
    }

    // Function that locks deposited NFTs as collateral and issues the moonTokens to the issuer
    //puts the entire token supply (the "cap") in th issuers wallet (**for non-crowdfund mode)
    function issue() external {
        require(msg.sender == issuer, "Vault: Only issuer can issue the tokens");
        require(active == false, "Vault: Token is already active");
        require(crowdfundingMode == false, "Vault: Crowdfund is on");

        active = true;
        address feeTo = factory.feeTo();
        uint256 feeAmount = 0;  
        if (feeTo != address(0)) {
            feeAmount = cap.div(factory.feeDivisor());
            _mint(feeTo, feeAmount);
        }

        uint256 amount = cap - feeAmount;
        _mint(issuer, amount);

        emit Issued();
    }

    //handles minting new tokens for crowdfunding mode, whether crowdfund creator or anyone else
    function purchaseCrowdfunding(uint amount) external payable {
        uint beforeFees = amount.mul(moonTokenCrowdfundingPrice);
        uint fee = beforeFees.div(factory.crowdfundFeeDivisor());
        uint requiredAmount = beforeFees.add(fee);

        require (msg.value >= requiredAmount, "Vault: Not enough ETH sent");
        require (crowdfundingMode == true, "Vault: Crowdfund is not on");
        require(active == false, "Vault: Token is already active");
        require(getBlockTimestamp() < endTime, "Vault: Crowdfund has terminated");

        //first case: conbribution balance (including this contribution) is less than or equal to the crowdfundgoal
        if ( address(this).balance.sub(contributionFees) <= crowdfundGoal) {
            _mint(msg.sender, amount);

            amountOwned[msg.sender] = amountOwned[msg.sender].add(amount);
            ethContributed[msg.sender] = ethContributed[msg.sender].add(msg.value);
            //increment total fees accrued in contract
            contributionFees = contributionFees.add(fee);
            fundedSoFar = fundedSoFar.add( msg.value.sub(fee) );

            emit PurchasedCrowdfund(msg.sender, amount);
        }
        //second case: this message's value made money in contract exceed the crowdfund goal
        else {
            // If the contribution balance before this contribution was already greater than the funding cap, then we should revert immediately.
            require(
                fundedSoFar < crowdfundGoal,
                "Crowdfund: Funding cap already reached"
            );
            // Otherwise, the contribution helped us reach the crowdfund goal. We should
            // take what we can until the funding cap is reached, and refund the rest.
            uint256 eligibleEth = crowdfundGoal - fundedSoFar;
            // Otherwise, we process the contribution as if it were the minimal amount.
            uint256 properAmount = eligibleEth.div(moonTokenCrowdfundingPrice);
            _mint(msg.sender, properAmount);

            amountOwned[msg.sender] = amountOwned[msg.sender].add(properAmount);
            ethContributed[msg.sender] = ethContributed[msg.sender].add(eligibleEth.add(fee));
            //increment total fees accrued in contract
            contributionFees = contributionFees.add(fee);
            fundedSoFar = fundedSoFar.add( eligibleEth );

            // Refund the sender with their contribution (e.g. 2.5 minus the diff - e.g. 1.5 = 1 ETH)
            msg.sender.transfer(msg.value.sub(eligibleEth.sub(fee)));

            emit PurchasedCrowdfund(msg.sender, properAmount);
        }
    }

    //users withdraw their contributions if the crowdfund ended or was terminated
    //need backend time tracker to check progress status when duration ends and then notify users to withdraw if goal is not reached by then
    function withdrawCrowdfunding() external {
        require(ethContributed[msg.sender] > 0, "Vault: You have no ETH to withdraw");
        require(crowdfundingMode == true, "Vault: Crowdfund is not on");
        require(getBlockTimestamp() > endTime, "Vault: Crowdfund has not ended yet");
        require(fundedSoFar < crowdfundGoal, "Vault: Crowdfund has not failed");

        super._burn(msg.sender, amountOwned[msg.sender]); //burn their tokens
        msg.sender.transfer(ethContributed[msg.sender]); //send them back their ETH

        //update ethContributed and amountOwned for msg.sender
        amountOwned[msg.sender] = 0;
        ethContributed[msg.sender] = 0;

        //emit event
        emit WithdrawnCrowdfund(msg.sender);
    } 

    //function to call when target NFT is delisted or bought before crowdfunding succeeds
    //or if the issuer wants to terminate for any other reason
    function terminateCrowdfund() external {
        require(msg.sender == issuer || msg.sender == factory.owner(), "Vault: terminateCrowdfund(): only issuer or owner can terminate");
        require(crowdfundingMode == true, "Vault: terminateCrowdfund(): Crowdfund is not on");

        //this is the best way to stop people from calling purchaseCrowdfunding() because if we set 
        //crowdfundingMode = false then the contract will reject any calls to withdrawCrowdfunding()
        endTime = 0;
        //now need to prompt users via notification to withdrawCrowdfunding()
        emit TerminatedCrowdfund();
    }

    //another alternative if the target NFT is delisted or bought before crowdfunding succeeds
    function updateTarget(uint _targetNftIndex, uint256 _tokenID, uint256 _amount, uint256 buyNowPrice, address _contractAddr) external {
        require(msg.sender == issuer || msg.sender == factory.owner(), "Vault: updateTargets(): only issuer or owner can update");
        require(crowdfundingMode == true, "Vault: updateTargets(): Crowdfund is not on");
        require(getBlockTimestamp() < endTime, "Vault: updateTargets(): Crowdfund has ended");

        //update targetNFTs
        targetNfts[_targetNftIndex].tokenId = _tokenID;
        targetNfts[_targetNftIndex].amount = _amount;
        targetNfts[_targetNftIndex].buyNowPrice = buyNowPrice;
        targetNfts[_targetNftIndex].nftContract = _contractAddr;

        updateCrowdfundGoal();
        emit TargetUpdated(_targetNftIndex, _tokenID, _amount, _contractAddr);
    }

    //need some frontend/backend progress tracker (funded so far/goal) to be able to call this function on time
    //only call this function when funded so far > goal
    function crowdfundSuccess() external {
        require (crowdfundingMode == true, "Vault: Crowdfund is not on");
        require (fundedSoFar >= crowdfundGoal, "Vault: Crowdfund has not succeeded");

        //set all the variables to stop the crowdfund phase and prepare for NFT purchase
        crowdfundingMode = false;
        active = true;
        cap = totalSupply();

        address feeTo = factory.feeTo();
        //send all ETH crowdfunding fees to moonlight
        if (feeTo != address(0)) {
            payable(feeTo).transfer(contributionFees);
        }

        //emit event
        emit CrowdfundSuccess();

        //call buy function
        betaBuyNfts();
    }

    //this releases funds to the crowdfund creator so they can manually make the purchase(s)
    //post-MVP remove this for buyNftsCrowdfunding()
    //obviously this is a bad function since curator can run off with funds, but for beta, moonlight will be the only curator -- take out the funds, buy NFT, and deposit it into vault
    function betaBuyNfts() internal {
        require (fundedSoFar >= crowdfundGoal && crowdfundGoal != 0, "Vault: Crowdfund was never on or has not succeeded yet");
        require(active == true, "Vault: Token is not active");

        payable(issuer).transfer(address(this).balance);

        //emit bought event
        emit BoughtNfts();
    }

    /**
     * Buy the target NFT(s) by calling target NFT's contract with calldata supplying value
     * Emits a Bought event upon success; reverts otherwise
     */
     /*
     //make this capable of buying ALL the target NFTs ?
    function buyNftsCrowdfunding(
        uint256 _targetNFTIndex,
        uint256 _value,
        bytes calldata _calldata
    ) public {
        require (fundedSoFar >= crowdfundGoal && crowdfundGoal != 0, "Vault: Crowdfund was never on or has not succeeded yet");
        require(active == true, "Vault: Token is not active");
        // ensure the caller is issuer OR this contract
        // ensure the the target NFT index is valid
        // check that the _value being spent is not more than available in vault
        // check that the value being spent is not zero
        //check that the value being spent is less than or equal to the buy price of the NFT
        
        // require that the NFT is NOT owned by the Vault
        require(
            _getOwner(_targetNFTIndex) != address(this),
            "PartyBuy::buy: own token before call"
        );
        // execute the calldata on the target contract
        //figure out a way to verify that calldata is executing purchase of the correct token ID
        (bool _success, bytes memory _returnData) = address(targetNfts[_targetNFTIndex].nftContract).call{value: _value}(_calldata);
        // require that the external call succeeded
        require(_success, string(_returnData));
        // require that the NFT is owned by the Vault
        require(
            _getOwner(_targetNFTIndex) == address(this),
            "PartyBuy::buy: failed to buy token"
        );

        //**ADD THE PURCHASED NFT TO nfts[] MAPPING

        // emit Bought event
        // **after purchase is done, make sure to track the new vault asset in nfts[] mapping
    } */

    //helper function to see who owns an NFT
    /*
    function _getOwner(uint _targetNFTIndex) internal view returns (address _owner) {
        (bool _success, bytes memory _returnData) = address(targetNfts[_targetNFTIndex].nftContract)
            .staticcall(abi.encodeWithSignature("ownerOf(uint256)", targetNfts[_targetNFTIndex].tokenId));
        if (_success && _returnData.length > 0) {
            _owner = abi.decode(_returnData, (address));
            return _owner;
        }
    }
    */

    // Function that allows NFTs to be refunded (prior to issue being called)
    function refund(address _to) external {
        require(!active, "Vault: Contract is already active - cannot refund");
        require(msg.sender == issuer, "Vault: Only issuer can refund");
        require(crowdfundingMode == false, "Vault: refund: crowdfunding is on");

        // Only transfer maximum of 50 at a time to limit gas per call
        uint8 _i = 0;
        uint256 _index = currentNFTIndex;
        bytes memory data;

        while (_index > 0 && _i < 50){
            NFT memory nft = nfts[_index - 1];

            if (ERC165CheckerUpgradeable.supportsInterface(nft.contractAddr, 0xd9b67a26)){
                IERC1155Upgradeable(nft.contractAddr).safeTransferFrom(address(this), _to, nft.tokenId, nft.amount, data);
            }
            else {
                IERC721Upgradeable(nft.contractAddr).safeTransferFrom(address(this), _to, nft.tokenId);
            }

            delete nfts[_index - 1];

            _index--;
            _i++;
        }

        currentNFTIndex = _index;

        emit Refunded();
    }

    function claimNFT(uint256 _nftIndex, address _to) external returns (bool) {
        require(msg.sender == factory.auctionHandler(), "Vault: Not auction handler");

        if (ERC165CheckerUpgradeable.supportsInterface(nfts[_nftIndex].contractAddr, 0xd9b67a26)){
            bytes memory data;
            IERC1155Upgradeable(nfts[_nftIndex].contractAddr).safeTransferFrom(address(this), _to, nfts[_nftIndex].tokenId, nfts[_nftIndex].amount, data);
        }
        else {
            IERC721Upgradeable(nfts[_nftIndex].contractAddr).safeTransferFrom(address(this), _to, nfts[_nftIndex].tokenId);
        }

        return true;
    }

    /**
     * ERC1155 Token ERC1155Receiver
     */
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) override external returns(bytes4) {
        if(keccak256(_data) == keccak256(VALIDATOR)){
            return 0xf23a6e61;
        }
    }

    function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) override external returns(bytes4) {
        if(keccak256(_data) == keccak256(VALIDATOR)){
            return 0xbc197c81;
        }
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        // Move voting rights
        _moveDelegates(_delegates[from], _delegates[to], amount);
    }

    /**
     * @dev implements the proxy transaction used by {VaultTimeLock-executeTransaction}
     */
    function forwardCall(address target, uint256 value, bytes calldata callData) external override payable returns (bool success, bytes memory returnData) {
        require(target != address(factory), "Vault: No proxy transactions calling factory allowed");
        require(msg.sender == vaultTimeLock, "Vault: Caller is not the vaultTimeLock contract");
        return target.call{value: value}(callData);
    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import "../../introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
      * @dev Safely transfers `tokenId` token from `from` to `to`.
      *
      * Requirements:
      *
      * - `from` cannot be the zero address.
      * - `to` cannot be the zero address.
      * - `tokenId` token must exist and be owned by `from`.
      * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
      * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
      *
      * Emits a {Transfer} event.
      */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/ContextUpgradeable.sol";
import "./IERC20Upgradeable.sol";
import "../../math/SafeMathUpgradeable.sol";
import "../../proxy/Initializable.sol";

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
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable {
    using SafeMathUpgradeable for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

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
    function __ERC20_init(string memory name_, string memory symbol_) internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal initializer {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
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
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
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
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
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
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
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
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
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
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
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
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
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
    function _approve(address owner, address spender, uint256 amount) internal virtual {
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
    function _setupDecimals(uint8 decimals_) internal virtual {
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
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
    uint256[44] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/ContextUpgradeable.sol";
import "./ERC20Upgradeable.sol";
import "../../proxy/Initializable.sol";

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20BurnableUpgradeable is Initializable, ContextUpgradeable, ERC20Upgradeable {
    function __ERC20Burnable_init() internal initializer {
        __Context_init_unchained();
        __ERC20Burnable_init_unchained();
    }

    function __ERC20Burnable_init_unchained() internal initializer {
    }
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import "../../introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155Upgradeable is IERC165Upgradeable {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../introspection/IERC165Upgradeable.sol";

/**
 * _Available since v3.1._
 */
interface IERC1155ReceiverUpgradeable is IERC165Upgradeable {

    /**
        @dev Handles the receipt of a single ERC1155 token type. This function is
        called at the end of a `safeTransferFrom` after the balance has been updated.
        To accept the transfer, this must return
        `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
        (i.e. 0xf23a6e61, or its own function selector).
        @param operator The address which initiated the transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param id The ID of the token being transferred
        @param value The amount of tokens being transferred
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
    */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    )
        external
        returns(bytes4);

    /**
        @dev Handles the receipt of a multiple ERC1155 token types. This function
        is called at the end of a `safeBatchTransferFrom` after the balances have
        been updated. To accept the transfer(s), this must return
        `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
        (i.e. 0xbc197c81, or its own function selector).
        @param operator The address which initiated the batch transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param ids An array containing ids of each token being transferred (order and length must match values array)
        @param values An array containing amounts of each token being transferred (order and length must match ids array)
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
    */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    )
        external
        returns(bytes4);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC1155ReceiverUpgradeable.sol";
import "../../introspection/ERC165Upgradeable.sol";
import "../../proxy/Initializable.sol";

/**
 * @dev _Available since v3.1._
 */
abstract contract ERC1155ReceiverUpgradeable is Initializable, ERC165Upgradeable, IERC1155ReceiverUpgradeable {
    function __ERC1155Receiver_init() internal initializer {
        __ERC165_init_unchained();
        __ERC1155Receiver_init_unchained();
    }

    function __ERC1155Receiver_init_unchained() internal initializer {
        _registerInterface(
            ERC1155ReceiverUpgradeable(address(0)).onERC1155Received.selector ^
            ERC1155ReceiverUpgradeable(address(0)).onERC1155BatchReceived.selector
        );
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;

import "../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
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
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

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

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
library SafeMathUpgradeable {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

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
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
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
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
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
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
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
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

pragma solidity >=0.6.0 <0.8.0;

import "./IERC165Upgradeable.sol";
import "../proxy/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts may inherit from this and call {_registerInterface} to declare
 * their support of an interface.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    /*
     * bytes4(keccak256('supportsInterface(bytes4)')) == 0x01ffc9a7
     */
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    /**
     * @dev Mapping of interface ids to whether or not it's supported.
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    function __ERC165_init() internal initializer {
        __ERC165_init_unchained();
    }

    function __ERC165_init_unchained() internal initializer {
        // Derived contracts need only register support for their own interfaces,
        // we register support for ERC165 itself here
        _registerInterface(_INTERFACE_ID_ERC165);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     *
     * Time complexity O(1), guaranteed to always use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return _supportedInterfaces[interfaceId];
    }

    /**
     * @dev Registers the contract as an implementer of the interface defined by
     * `interfaceId`. Support of the actual ERC165 interface is automatic and
     * registering its interface id is not required.
     *
     * See {IERC165-supportsInterface}.
     *
     * Requirements:
     *
     * - `interfaceId` cannot be the ERC165 invalid interface (`0xffffffff`).
     */
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Library used to query support of an interface declared via {IERC165}.
 *
 * Note that these functions return the actual result of the query: they do not
 * `revert` if an interface is not supported. It is up to the caller to decide
 * what to do in these cases.
 */
library ERC165CheckerUpgradeable {
    // As per the EIP-165 spec, no interface should ever match 0xffffffff
    bytes4 private constant _INTERFACE_ID_INVALID = 0xffffffff;

    /*
     * bytes4(keccak256('supportsInterface(bytes4)')) == 0x01ffc9a7
     */
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    /**
     * @dev Returns true if `account` supports the {IERC165} interface,
     */
    function supportsERC165(address account) internal view returns (bool) {
        // Any contract that implements ERC165 must explicitly indicate support of
        // InterfaceId_ERC165 and explicitly indicate non-support of InterfaceId_Invalid
        return _supportsERC165Interface(account, _INTERFACE_ID_ERC165) &&
            !_supportsERC165Interface(account, _INTERFACE_ID_INVALID);
    }

    /**
     * @dev Returns true if `account` supports the interface defined by
     * `interfaceId`. Support for {IERC165} itself is queried automatically.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsInterface(address account, bytes4 interfaceId) internal view returns (bool) {
        // query support of both ERC165 as per the spec and support of _interfaceId
        return supportsERC165(account) &&
            _supportsERC165Interface(account, interfaceId);
    }

    /**
     * @dev Returns a boolean array where each value corresponds to the
     * interfaces passed in and whether they're supported or not. This allows
     * you to batch check interfaces for a contract where your expectation
     * is that some interfaces may not be supported.
     *
     * See {IERC165-supportsInterface}.
     *
     * _Available since v3.4._
     */
    function getSupportedInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool[] memory) {
        // an array of booleans corresponding to interfaceIds and whether they're supported or not
        bool[] memory interfaceIdsSupported = new bool[](interfaceIds.length);

        // query support of ERC165 itself
        if (supportsERC165(account)) {
            // query support of each interface in interfaceIds
            for (uint256 i = 0; i < interfaceIds.length; i++) {
                interfaceIdsSupported[i] = _supportsERC165Interface(account, interfaceIds[i]);
            }
        }

        return interfaceIdsSupported;
    }

    /**
     * @dev Returns true if `account` supports all the interfaces defined in
     * `interfaceIds`. Support for {IERC165} itself is queried automatically.
     *
     * Batch-querying can lead to gas savings by skipping repeated checks for
     * {IERC165} support.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsAllInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool) {
        // query support of ERC165 itself
        if (!supportsERC165(account)) {
            return false;
        }

        // query support of each interface in _interfaceIds
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            if (!_supportsERC165Interface(account, interfaceIds[i])) {
                return false;
            }
        }

        // all interfaces supported
        return true;
    }

    /**
     * @notice Query if a contract implements an interface, does not check ERC165 support
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the contract at account indicates support of the interface with
     * identifier interfaceId, false otherwise
     * @dev Assumes that account contains a contract that supports ERC165, otherwise
     * the behavior of this method is undefined. This precondition can be checked
     * with {supportsERC165}.
     * Interface identification is specified in ERC-165.
     */
    function _supportsERC165Interface(address account, bytes4 interfaceId) private view returns (bool) {
        // success determines whether the staticcall succeeded and result determines
        // whether the contract at account indicates support of _interfaceId
        (bool success, bool result) = _callERC165SupportsInterface(account, interfaceId);

        return (success && result);
    }

    /**
     * @notice Calls the function with selector 0x01ffc9a7 (ERC165) and suppresses throw
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return success true if the STATICCALL succeeded, false otherwise
     * @return result true if the STATICCALL succeeded and the contract at account
     * indicates support of the interface with identifier interfaceId, false otherwise
     */
    function _callERC165SupportsInterface(address account, bytes4 interfaceId)
        private
        view
        returns (bool, bool)
    {
        bytes memory encodedParams = abi.encodeWithSelector(_INTERFACE_ID_ERC165, interfaceId);
        (bool success, bytes memory result) = account.staticcall{ gas: 30000 }(encodedParams);
        if (result.length < 32) return (false, false);
        return (success, abi.decode(result, (bool)));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/Initializable.sol";
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
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface AggregatorV3Interface {

  function decimals()
    external
    view
    returns (
      uint8
    );

  function description()
    external
    view
    returns (
      string memory
    );

  function version()
    external
    view
    returns (
      uint256
    );

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(
    uint80 _roundId
  )
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