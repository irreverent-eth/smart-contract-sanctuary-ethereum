pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import {Foundance} from "../libraries/Foundance.sol";
import "./DaoFactory.sol";
import "./DaoRegistry.sol";
import "../extensions/IExtension.sol";
import "../extensions/bank/BankFactory.sol";
import "../extensions/executor/ExecutorFactory.sol";
import "../extensions/token/erc20/ERC20TokenExtensionFactory.sol";
import "../extensions/foundance/DynamicEquityExtensionFactory.sol";
import "../extensions/foundance/CommunityIncentiveExtensionFactory.sol";
  //import "../extensions/nft/NFTCollectionFactory.sol";
  //import "../extensions/erc1155/ERC1155TokenExtensionFactory.sol";
  //import "../extensions/erc1271/ERC1271Factory.sol";
import "../adapters/Manager.sol";
import "../adapters/voting/Voting.sol"; 
import "../adapters/Tribute.sol";
import "../adapters/foundance/DynamicEquityAdapter.sol";
import "../adapters/foundance/CommunityIncentiveAdapter.sol";
  //import "../adapters/Onboarding.sol";
import "../helpers/DaoHelper.sol";

//TODO: (PROXY-FoundanceFactory)(GAS Optimization)(test)

contract FoundanceFactory{
    //EVENT
    /**
     * @notice Event emitted when a new Foundance-Agreement has been registered/approved
     * @param  _address address of interacting member
     * @param _projectId The Foundance project Id
     * @param  _name name of Foundance-Agreement
     */
		event FoundanceRegistered(address _address, uint32 _projectId, string _name);
    event FoundanceApproved(address _address, uint32 _projectId,  string _name);
    /**
     * @notice Event emitted when a member has been added/deleted/changed in already registered Foundance-Agreement
     * @param  _address address of Foundance creator
     * @param  _name name of Foundance
     */
    event FoundanceMemberAdded(address _address, string _name);
    event FoundanceMemberDeleted(address _address, string _name);
    event FoundanceMemberChanged(address _address, string _name);
     /**
     * @notice Event emitted when a new Dao has been created based upon a registered Foundance
     * @dev The event is too big, people will have to call `function getExtensionAddress(bytes32 extensionId)` to get the addresses
     * @param  _creatorAddress add of the member summoning the DAO
     * @param _projectId The Foundance project Id
     * @param  _daoAdress address of DaoRegistry
     * @param  _bankAdress address of BankExtension
     * @param  _dynamicEquityExtensionAddress address of dynamicEquity Extension
     */
    event FoundanceLive(
      address _creatorAddress,
      uint32 _projectId,
      address _daoAdress,
      address _bankAdress,
      address _dynamicEquityExtensionAddress
    ); 

    //CORE
    address daoFactoryAddress = 0x06b315B7f086470E61E64066DA94480De3077Db7;
    //EXTENSION
    address bankFactoryAddress = 0xb1e179f2B123972DcA00D48E9E921D0a166760f4;
    address erc20TokenExtensionFactoryAddress = 0xe86710A297DC477090a7091FFeBa3E4f27c916AC;
    address dynamicEquityExtensionFactoryAddress = 0x5761726a28235aD438971536F2Ca81D4a41d2a3F;
    address communityIncentiveExtensionFactoryAddress = 0xdDf3A27335f7237454D79Ce65eAE4b85A2620d6C;
      //address erc1155TokenCollectionFactoryAddress = 0xa9A41180488FB4E9C95A8E239283643fF4E7A033;
      //address erc1271ExtensionFactoryAddress = 0x4e6B44EaA0B0B5157b2D94F3aeaba2da21333e6e;
      //address nftCollectionFactoryAddress = 0x11519997d9452f510DE67c3A97e76F787df53f52;
      //address executorExtensionFactoryAddress = 0x73917D1bfB83671AE2EE8832D0a938BD5Ac0DC6a;
    //ADAPTER
    address daoRegistryAdapterContractAddress = 0xb8ce10b2605428c40437456388281DAbE8f541cC;
    address bankAdapterContractAddress = 0x3B572D946cA0932aFEb552d99Df34e552f25cFDD;
    address configurationContractAddress = 0x2aB5e0126394A976a016b7e99710B96baA42F630;
    address managingContractAddress = 0x7B1A478980688d92448D365fAE807054E1A5aBDb;
    address managerAddress = 0x294ce605667EE7101A0a8e2a00f579aa7824D924;
    address votingContractAddress = 0xB6D1Ac5CEb2Ef423040eD9E72090d9B4b5a2c5ee;
    address tributeContractAddress = 0x07976dD69E4a8cf334D1B6270d8D2F56F3855381;
    address ERC20TransferStrategyAddress = 0xc070271B1D530da63A50103BFDE2221C9819C7DE;
    address multicallAddress = 0xf56ccB937dB963674a7935bda315132A299b747D;
    address dynamicEquityAdapterAddress = 0x0886BBAf02414Ff61c34d5D5B764a15a95bf0530;
    address communityIncentiveAdapterAddress = 0xa8A5d7A4EAC2cc82C1F62A93902031EEFEbA3e00;
      //address signaturesContractAddress = 0xA4eA0F9c93d5Aca3117999bc5EBb1743fDe55692;
      //address onboardingContractAddress = 0x9C4443e13F3ff47Aa1Be8a108d2E529755e91d1F;
      //address ERC1155AdapterContractAddress = 0xEe7DD41D6Ed50aCD0B2fB84b5bd3A653944F2b9f;

    //CORE
    DaoFactory daoFactory; 
    //EXTENSION
    BankFactory bankFactory;
    ERC20TokenExtensionFactory erc20TokenExtensionFactory;
    DynamicEquityExtensionFactory dynamicEquityExtensionFactory;
    CommunityIncentiveExtensionFactory communityIncentiveExtensionFactory;
      //ERC1155TokenCollectionFactory erc1155TokenCollectionFactory;
      //ERC1271ExtensionFactory erc1271ExtensionFactory;
      //NFTCollectionFactory nftCollectionFactory;
      //ExecutorExtensionFactory executorExtensionFactory;
    //ADAPTER
    Manager manager;
    VotingContract votingContract;
    TributeContract tributeContract;
    DynamicEquityAdapter dynamicEquityAdapter;
    CommunityIncentiveAdapter communityIncentiveAdapter;
      //OnboardingContract onboardingContract;

    constructor() {
        daoFactory = DaoFactory(daoFactoryAddress);
        bankFactory = BankFactory(bankFactoryAddress);
        erc20TokenExtensionFactory = ERC20TokenExtensionFactory(erc20TokenExtensionFactoryAddress);
        dynamicEquityExtensionFactory = DynamicEquityExtensionFactory(dynamicEquityExtensionFactoryAddress);
        communityIncentiveExtensionFactory = CommunityIncentiveExtensionFactory(communityIncentiveExtensionFactoryAddress);
          //erc1155TokenCollectionFactory = ERC1155TokenCollectionFactory(erc1155TokenCollectionFactoryAddress);
          //erc1271ExtensionFactory = ERC1271ExtensionFactory(erc1271ExtensionFactoryAddress);
          //nftCollectionFactory = NFTCollectionFactory(nftCollectionFactoryAddress);
          //executorExtensionFactory = ExecutorExtensionFactory(executorExtensionFactoryAddress);
        manager = Manager(managerAddress);
        votingContract = VotingContract(votingContractAddress);
        tributeContract = TributeContract(tributeContractAddress);
        dynamicEquityAdapter = DynamicEquityAdapter(dynamicEquityAdapterAddress);
        communityIncentiveAdapter = CommunityIncentiveAdapter(communityIncentiveAdapterAddress);
          //onboardingContract = OnboardingContract(onboardingContractAddress);
    }

    mapping(string => Foundance.FoundanceConfig) private registeredFoundance;

    modifier onlyCreator(string calldata foundanceName) {
        require(registeredFoundance[foundanceName].creatorAddress == msg.sender, "Only creatorAddress can access");
        _;
    }

    /**
     * @notice Register a Foundance Dao   
     * @dev The foundanceName must be unique and not previously registered.
     * @param foundanceName Name of the Dao
     * @param projectId THe internal project identifier for correlating projects and DAOs
     * @param memberArray Member Array including all relevant data
     * @param tokenConfig *
     * @param votingConfig *
     * @param epochConfig *
     * @param dynamicEquityConfig *
     * @param communityIncentiveConfig *
     **/ 
    function registerFoundance( 
      string calldata foundanceName,
      uint32 projectId,
      Foundance.Member[] memory memberArray,
      Foundance.TokenConfig calldata tokenConfig,
      Foundance.VotingConfig calldata  votingConfig,
      Foundance.EpochConfig calldata epochConfig,
      Foundance.DynamicEquityConfig calldata dynamicEquityConfig, 
      Foundance.CommunityIncentiveConfig calldata communityIncentiveConfig 
    ) external{
        require(daoFactory.getDaoAddress(foundanceName)==address(0x0),"Foundance-DAO with this name already created.");
        require(registeredFoundance[foundanceName].creatorAddress==address(0x0),"Foundance-Agreement with this name already registered.");
        Foundance.FoundanceConfig storage foundance = registeredFoundance[foundanceName];
        foundance.creatorAddress = msg.sender;
        //FOUNDANCE
        foundance.projectId = projectId;
        foundance.tokenConfig = tokenConfig; 	
        foundance.votingConfig = votingConfig; 	
        foundance.epochConfig = epochConfig; 	
        foundance.dynamicEquityConfig = dynamicEquityConfig; 	
        foundance.communityIncentiveConfig = communityIncentiveConfig; 	
          //foundance.memberArray = new Foundance.Member[](memberArray.length);
        //MEMBER
        for(uint256 i=0;i<memberArray.length;i++){
          foundance.memberIndex[memberArray[i].memberAddress]=i+1;
          memberArray[i].foundanceApproved = false;
          foundance.memberArray.push(memberArray[i]);
        }
        foundance.foundanceStatus = Foundance.FoundanceStatus.REGISTERED;
        emit FoundanceRegistered(msg.sender,projectId,foundanceName);
     }

    /**
    * @notice Member approves a registered Foundance-Agreement  
    * @param foundanceName Name of Foundance-DAO
    **/ 
    function approveFoundance(
      string calldata foundanceName
    ) external{
        Foundance.FoundanceConfig storage foundance = registeredFoundance[foundanceName];
        require(foundanceMemberExists(foundance, msg.sender), "Member doesnt exists in this Foundance-Agreement.");
        foundance.memberArray[foundance.memberIndex[msg.sender]-1].foundanceApproved = true;
        emit FoundanceApproved(msg.sender,foundance.projectId,foundanceName);
    }

    /**
    * @notice Checks if the Foundance-Agreement is approved by all registered members.  
    * @param foundanceName Name of the Foundance DAO
    **/ 
    function isFoundanceApproved(string calldata foundanceName) external view returns(bool){
        Foundance.FoundanceConfig storage foundance = registeredFoundance[foundanceName];    
        return _isFoundanceApproved(foundance);
    }

    /**
    * @notice Checks if the Foundance-Agreement is approved by all registered members.  
    * @param foundance Foundance
    **/ 
    function _isFoundanceApproved(
      Foundance.FoundanceConfig storage foundance
    ) internal view returns(bool){
        for(uint256 i=0;i<foundance.memberArray.length;i++){
          if(!foundance.memberArray[i].foundanceApproved) return false;
        }
        return true;
    }

    /**
    * @notice Revokes approval for all members within a Foundance-Agreement
    * @param foundance Foundance
    **/ 
    function revokeApproval(Foundance.FoundanceConfig storage foundance) internal returns(Foundance.FoundanceConfig storage){
      for(uint256 i=0;i<foundance.memberArray.length;i++){
      	foundance.memberArray[i].foundanceApproved=false;
      }
      return foundance;
    }

    /**
    * @notice Create a Foundance-DAO based upon an already approved Foundance-Agreement 
    * @dev The Foundance-Agreement must be approved by all members
    * @dev This function must be accessed by the Foundance-Agreement creator
    * @param foundanceName Name of the Foundance-DAO
    * @param creatorAddress Address of the Foundance-DAO creator
    **/ 
    function createFoundance(
      string calldata foundanceName, 
      address creatorAddress
    ) external onlyCreator(foundanceName){
				Foundance.FoundanceConfig storage foundance = registeredFoundance[foundanceName];    
    		require(_isFoundanceApproved(foundance), "Foundance-Agreement is not approved by all members");
				foundance.foundanceStatus=Foundance.FoundanceStatus.APPROVED;
        //CREATE_CORE
        daoFactory.createDao(foundanceName, creatorAddress);    
        address daoAddress = daoFactory.getDaoAddress(foundanceName);
        DaoRegistry daoRegistry = DaoRegistry(daoAddress);
        //CREATE_EXTENSION
        bankFactory.create(daoRegistry,foundance.tokenConfig.maxExternalTokens);
        erc20TokenExtensionFactory.create(daoRegistry,foundance.tokenConfig.tokenName,DaoHelper.UNITS,foundance.tokenConfig.tokenSymbol,foundance.tokenConfig.decimals);
        dynamicEquityExtensionFactory.create(daoRegistry);
        communityIncentiveExtensionFactory.create(daoRegistry);
          //erc1155TokenCollectionFactory.create(daoRegistry);//(DaoRegistry dao)
          //erc1271ExtensionFactory.create(daoRegistry);//(DaoRegistry dao)
          //executorExtensionFactory.create(daoRegistry);//(DaoRegistry dao)
          //nftCollectionFactory.create(daoRegistry);//(DaoRegistry dao)
        //GET_ADDRESSES
        address bankExtensionAddress = bankFactory.getExtensionAddress(daoAddress);
        address erc20TokenExtensionAddress = erc20TokenExtensionFactory.getExtensionAddress(daoAddress);
        address dynamicEquityExtensionAddress = dynamicEquityExtensionFactory.getExtensionAddress(daoAddress);
        address communityIncentiveExtensionAddress = communityIncentiveExtensionFactory.getExtensionAddress(daoAddress);
          //address erc1155TokenExtensionAddress = erc1155TokenCollectionFactory.getExtensionAddress(daoAddress);
          //address erc1271ExtensionAddress = erc1271ExtensionFactory.getExtensionAddress(daoAddress);
          //address executorExtensionAddress = executorExtensionFactory.getExtensionAddress(daoAddress);
          //address nftExtensionAddress = nftCollectionFactory.getExtensionAddress(daoAddress);
        //ENABLE_EXTENSION
        daoRegistry.addExtension(DaoHelper.BANK, IExtension(bankExtensionAddress));
        daoRegistry.addExtension(DaoHelper.ERC20_EXT,IExtension(erc20TokenExtensionAddress));
        daoRegistry.addExtension(DaoHelper.DYNAMIC_EQUITY_EXT,IExtension(dynamicEquityExtensionAddress));
        daoRegistry.addExtension(DaoHelper.COMMUNITY_INCENTIVE_EXT,IExtension(communityIncentiveExtensionAddress));
          //daoRegistry.addExtension(DaoHelper.ERC1155_EXT,IExtension(erc1155TokenExtensionAddress));
          //daoRegistry.addExtension(DaoHelper.ERC1271,IExtension(erc1271ExtensionAddress));
          //daoRegistry.addExtension(DaoHelper.EXECUTOR_EXT,IExtension(executorExtensionAddress));
          //daoRegistry.addExtension(DaoHelper.NFT,IExtension(nftExtensionAddress));
        //CONFIGURATION  
        daoRegistry.setAddressConfiguration(keccak256(abi.encodePacked("governance.role.",configurationContractAddress)), DaoHelper.UNITS); // Here we should put maintainerTokenAddress
        daoRegistry.setAddressConfiguration(keccak256(abi.encodePacked("governance.role.",managingContractAddress)), DaoHelper.UNITS); // Here we should put maintainerTokenAddress
        //CORE_ADAPTER_ACL
        {
        DaoFactory.Adapter[] memory adapterList = new DaoFactory.Adapter[](12);
          adapterList[0] = DaoFactory.Adapter(DaoHelper.DAO_REGISTRY_ADAPT,daoRegistryAdapterContractAddress,uint128(4));
          adapterList[1] = DaoFactory.Adapter(DaoHelper.BANK_ADAPT,bankAdapterContractAddress,uint128(0));
          adapterList[2] = DaoFactory.Adapter(DaoHelper.CONFIGURATION,configurationContractAddress,uint128(10));        
          adapterList[3] = DaoFactory.Adapter(DaoHelper.MANAGING,managingContractAddress,uint128(59));
          adapterList[4] = DaoFactory.Adapter(keccak256("manager"),managerAddress,uint128(59));        
          adapterList[5] = DaoFactory.Adapter(DaoHelper.VOTING,votingContractAddress,uint128(0));
          adapterList[6] = DaoFactory.Adapter(DaoHelper.TRIBUTE,tributeContractAddress,uint128(66));
          adapterList[7] = DaoFactory.Adapter(DaoHelper.ERC20_TRANSFER_STRATEGY_ADPT,ERC20TransferStrategyAddress,uint128(0));
          adapterList[8] = DaoFactory.Adapter(keccak256("foundanceFactory"),address(this),uint128(127));
          adapterList[9] = DaoFactory.Adapter(DaoHelper.ERC20_EXT,erc20TokenExtensionAddress,uint128(64));
          adapterList[10] = DaoFactory.Adapter(DaoHelper.DYNAMIC_EQUITY_ADAPT,dynamicEquityAdapterAddress,uint128(127));
          adapterList[11] = DaoFactory.Adapter(DaoHelper.COMMUNITY_INCENTIVE_ADAPT,communityIncentiveAdapterAddress,uint128(127));
            //adapterList[] = DaoFactory.Adapter(DaoHelper.ERC1155_ADAPT,ERC1155AdapterContractAddress,uint128(0));
            //adapterList[] = DaoFactory.Adapter(DaoHelper.ERC1271_ADAPT,signaturesContractAddress,uint128(2));
            //adapterList[] = DaoFactory.Adapter(DaoHelper.ONBOARDING,onboardingContractAddress,uint128(70));
        daoFactory.addAdapters(daoRegistry, adapterList);
        }
        //CONFIGURATION  
        manager.configureDao(daoRegistry, creatorAddress);
        votingContract.configureDao(daoRegistry, 600, 600);
        tributeContract.configureDao(daoRegistry, DaoHelper.UNITS);
        tributeContract.configureDao(daoRegistry, DaoHelper.LOOT);
          //onboardingContract.configureDao(daoRegistry, DaoHelper.UNITS, 100000000000000000, 100000, 11,address(0x0));//This transaction is made twice with different unitsToMint parameter???
          //onboardingContract.configureDao(daoRegistry, DaoHelper.LOOT, 100000000000000000, 100000, 11,address(0x0));//This transaction is made twice with different unitsToMint parameter??
        //EXTENSION_ADAPTER_ACL
        {
        DaoFactory.Adapter[] memory adapterList = new DaoFactory.Adapter[](7);
          adapterList[0] = DaoFactory.Adapter(DaoHelper.BANK_ADAPT,bankAdapterContractAddress,uint128(75));        
          adapterList[1] = DaoFactory.Adapter(DaoHelper.TRIBUTE,tributeContractAddress,uint128(17));
          adapterList[2] = DaoFactory.Adapter(DaoHelper.ERC20_TRANSFER_STRATEGY_ADPT,ERC20TransferStrategyAddress,uint128(4));
          adapterList[3] = DaoFactory.Adapter(keccak256("foundanceFactory"),address(this),uint128(127));
          adapterList[4] = DaoFactory.Adapter(DaoHelper.DYNAMIC_EQUITY_ADAPT,dynamicEquityAdapterAddress,uint128(7));
          adapterList[5] = DaoFactory.Adapter(DaoHelper.COMMUNITY_INCENTIVE_ADAPT,communityIncentiveAdapterAddress,uint128(15));
          adapterList[6] = DaoFactory.Adapter(DaoHelper.VOTING,votingContractAddress,uint128(4));
          //adapterList[] = DaoFactory.Adapter(DaoHelper.ONBOARDING,onboardingContractAddress,uint128(5));
        daoFactory.configureExtension(daoRegistry, bankExtensionAddress, adapterList);

        adapterList = new DaoFactory.Adapter[](2);
          adapterList[0] = DaoFactory.Adapter(DaoHelper.DYNAMIC_EQUITY_ADAPT,dynamicEquityAdapterAddress,uint128(15));
          adapterList[1] = DaoFactory.Adapter(keccak256("foundanceFactory"),address(this),uint128(15));
        daoFactory.configureExtension(daoRegistry, dynamicEquityExtensionAddress, adapterList);
          adapterList[0] = DaoFactory.Adapter(DaoHelper.COMMUNITY_INCENTIVE_ADAPT,communityIncentiveAdapterAddress,uint128(15));
          adapterList[1] = DaoFactory.Adapter(keccak256("foundanceFactory"),address(this),uint128(15));
        daoFactory.configureExtension(daoRegistry, communityIncentiveExtensionAddress, adapterList);

        adapterList = new DaoFactory.Adapter[](1);
          adapterList[0] = DaoFactory.Adapter(DaoHelper.ERC20_EXT,erc20TokenExtensionAddress,uint128(4));
        daoFactory.configureExtension(daoRegistry, bankExtensionAddress, adapterList);
        /*
          DaoFactory.Adapter[] memory adapterList = new DaoFactory.Adapter[](1);
          adapterList[0] = DaoFactory.Adapter(DaoHelper.ERC1155_ADAPT,ERC1155AdapterContractAddress,uint128(7));
          daoFactory.configureExtension(daoRegistry, nftExtensionAddress, adapterList);
          adapterList[0] = DaoFactory.Adapter(DaoHelper.ERC1271_ADAPT,signaturesContractAddress,uint128(1));
          daoFactory.configureExtension(daoRegistry, erc1271ExtensionAddress, adapterList);
          adapterList[0] = DaoFactory.Adapter(DaoHelper.ERC1155_ADAPT,ERC1155AdapterContractAddress,uint128(7));
          daoFactory.configureExtension(daoRegistry, erc1155TokenExtensionAddress, adapterList);
        */
        }
        //CONFIGURE_EXTENSION
        DynamicEquityExtension(dynamicEquityExtensionAddress).setDynamicEquity(daoRegistry,foundance.dynamicEquityConfig,foundance.epochConfig);
        CommunityIncentiveExtension(communityIncentiveExtensionAddress).setCommunityIncentive(daoRegistry,foundance.communityIncentiveConfig,foundance.epochConfig);
        //CONFIGURE_EXTENSION_PER_MEMBER
        for(uint256 i=0;i<foundance.memberArray.length;i++){
          daoRegistry.potentialNewMember(foundance.memberArray[i].memberAddress);
          BankExtension(bankExtensionAddress).addToBalance(daoRegistry,foundance.memberArray[i].memberAddress,DaoHelper.UNITS,foundance.memberArray[i].initialTokenAmount);
          if(foundance.memberArray[i].dynamicEquity){
            DynamicEquityExtension(dynamicEquityExtensionAddress).setDynamicEquityMember(daoRegistry,foundance.memberArray[i].dynamicEquityMemberConfig);
          }
          if(foundance.memberArray[i].vesting){
            DynamicEquityExtension(dynamicEquityExtensionAddress).setVestingMember(daoRegistry,foundance.memberArray[i].vestingMemberConfig);
          }
          if(foundance.memberArray[i].governer){
            CommunityIncentiveExtension(communityIncentiveExtensionAddress).setCommunityIncentiveMember(daoRegistry,foundance.memberArray[i].communityIncentiveMemberConfig);
          }
        }
        //FINALIZE_DAO
          //daoRegistry.finalizeDao();
				  //foundance.status=FoundanceStatus.LIVE;
        emit FoundanceLive(creatorAddress,foundance.projectId,daoAddress,bankExtensionAddress,dynamicEquityExtensionAddress);
    }

    /**
    * @notice Checks if the member exists within the Foundance
    * @dev The Foundance must exist
    * @param foundance Foundance
    * @param _member Address of member
    **/ 
    function foundanceMemberExists(
      Foundance.FoundanceConfig storage foundance, 
      address _member
    ) internal view returns(bool){
        require(foundance.creatorAddress!=address(0x0),"There is no foundance with this name");
        uint memberIndex = foundance.memberIndex[_member];
        if(memberIndex==0){
      	  return false;
        }
        return true;
    }
 
    //Member management for registered Foundance-Agreement

		function addMember(string calldata foundanceName, Foundance.Member calldata _member) external onlyCreator(foundanceName){ 
    	Foundance.FoundanceConfig storage foundance = registeredFoundance[foundanceName];      
      require(!foundanceMemberExists(foundance, _member.memberAddress), "Member already exists in this foundance"); 
      
      foundance.memberArray.push(_member);
      foundance.memberIndex[_member.memberAddress]=foundance.memberArray.length;
      revokeApproval(foundance);
    }
 
    function deleteMember(string calldata foundanceName, address _member) external onlyCreator(foundanceName){
    	Foundance.FoundanceConfig storage foundance = registeredFoundance[foundanceName];   
      require(foundanceMemberExists(foundance, _member), "Member doesnt exists in this foundance");
      
      foundance.memberArray[foundance.memberIndex[_member]-1] = foundance.memberArray[foundance.memberArray.length-1];
      foundance.memberIndex[foundance.memberArray[foundance.memberArray.length-1].memberAddress] = foundance.memberIndex[_member];      
      foundance.memberIndex[_member]=0;
      foundance.memberArray.pop();
			revokeApproval(foundance);
    }
    
    function changeMember(string calldata foundanceName, Foundance.Member calldata _member) external onlyCreator(foundanceName){
    	Foundance.FoundanceConfig storage foundance = registeredFoundance[foundanceName];   
      require(foundanceMemberExists(foundance, _member.memberAddress), "Member doesnt exists in this foundance");
      
      foundance.memberArray[foundance.memberIndex[_member.memberAddress]-1] = _member;
      revokeApproval(foundance);
    }

    //view Functions

    function getFoundanceMembers(string calldata foundanceName) public view returns(Foundance.Member[] memory _memberArray){
       return registeredFoundance[foundanceName].memberArray;       
    }
    function getFoundanceTokenConfig(string calldata foundanceName) public view returns(Foundance.TokenConfig memory _memberArray){
       return registeredFoundance[foundanceName].tokenConfig;       
    }
    function getFoundanceDynamicEquityConfig(string calldata foundanceName) public view returns(Foundance.DynamicEquityConfig memory _memberArray){
       return registeredFoundance[foundanceName].dynamicEquityConfig;       
    }
    
}

pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
library Foundance {

    enum FoundanceStatus {
      REGISTERED,
      APPROVED,
      LIVE
    }

    enum VotingType {
      LINEAR,
      WEIGHTED,
      QUADRATIC,
      OPTIMISTIC,
      COOPERATIVE
    }

    enum AllocationType {
      POOL,
      EPOCH,
      EPOCH_POOL,
      EPOCH_PERCENTAGE  
    }

    //FOUNDANCE
    struct FoundanceConfig {
        address creatorAddress;
        uint32 projectId;
        FoundanceStatus foundanceStatus;
        Member[] memberArray;
        mapping(address => uint) memberIndex;
        TokenConfig tokenConfig;
        VotingConfig votingConfig;
        EpochConfig epochConfig;
        DynamicEquityConfig dynamicEquityConfig;
        CommunityIncentiveConfig communityIncentiveConfig;
    }
    struct TokenConfig {
        address tokenAddress;
        string tokenName;
        string tokenSymbol;
        uint8 maxExternalTokens;
        uint8 decimals;
    }
    struct VotingConfig {
        VotingType votingType;
        uint256 votingPeriod;
        uint256 gracePeriod;
        uint256 disputePeriod;
        uint passRateMember;
        uint passRateToken;
        uint supportRequired;
    }
    struct EpochConfig {
        uint256 epochDuration;
        uint256 epochReview;
        uint256 epochStart;
        uint256 epochLast;
    }
    struct DynamicEquityConfig {
        uint riskMultiplier;
        uint timeMultiplier;
    }
    struct CommunityIncentiveConfig {
        AllocationType allocationType;
        uint poolTokenAmount;
        uint epochTokenAmount;
        uint percentageTokenAmount;
        uint totalTokenAmount;
    }

    //MEMBER
    struct Member {
        address memberAddress;
        bool foundanceApproved;
        uint initialTokenAmount;
        bool dynamicEquity;
        bool vesting;
        bool governer;
        DynamicEquityMemberConfig dynamicEquityMemberConfig;
        VestingMemberConfig vestingMemberConfig;
        CommunityIncentiveMemberConfig communityIncentiveMemberConfig;
    }
    struct DynamicEquityMemberConfig {
        address memberAddress;
        uint256 suspendedUntil;
        uint availability;
        uint availabilityThreshold;
        uint salary;
        uint salaryMarket;
        uint salaryThreshold;
        uint expense;
        uint expenseThreshold;
    }
    struct VestingMemberConfig {
        address memberAddress;
        uint amount;
        uint256 duration;
        uint256 start;
        uint256 cliff;
    }
    struct CommunityIncentiveMemberConfig {
        address memberAddress;
        uint singlePaymentAmountThreshold;
        uint totalPaymentAmountThreshold;
        uint totalPaymentAmount;
    }

    //CONSTANTS//REQUIMENT
    uint8 internal constant FOUNDANCE_TOKENS_GUILD_BANK = 100;
    uint8 internal constant FOUNDANCE_TOKEN_DECIMALS = 8;
    uint internal constant FOUNDANCE_WORKDAYS_WEEK= 5;
    uint internal constant FOUNDANCE_MONTHS_YEAR = 12;
    uint internal constant FOUNDANCE_WEEKS_MONTH = 434524;
    uint internal constant FOUNDANCE_WEEKS_MONTH_PRECISION = 5;
    uint internal constant FOUNDANCE_PRECISION = 5;

}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
import "./DaoRegistry.sol";
import "./CloneFactory.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

contract DaoFactory is CloneFactory {
    struct Adapter {
        bytes32 id;
        address addr;
        uint128 flags;
    }

    // daoAddr => hashedName
    mapping(address => bytes32) public daos;
    // hashedName => daoAddr
    mapping(bytes32 => address) public addresses;

    address public identityAddress;

    /**
     * @notice Event emitted when a new DAO has been created.
     * @param _address The DAO address.
     * @param _name The DAO name.
     */
    event DAOCreated(address _address, string _name);

    constructor(address _identityAddress) {
        require(_identityAddress != address(0x0), "invalid addr");
        identityAddress = _identityAddress;
    }

    /**
     * @notice Creates and initializes a new DaoRegistry with the DAO creator and the transaction sender.
     * @notice Enters the new DaoRegistry in the DaoFactory state.
     * @dev The daoName must not already have been taken.
     * @param daoName The name of the DAO which, after being hashed, is used to access the address.
     * @param creator The DAO's creator, who will be an initial member.
     */
    function createDao(string calldata daoName, address creator) external {
        bytes32 hashedName = keccak256(abi.encode(daoName));
        require(
            addresses[hashedName] == address(0x0),
            string(abi.encodePacked("name ", daoName, " already taken"))
        );
        DaoRegistry dao = DaoRegistry(_createClone(identityAddress));

        address daoAddr = address(dao);
        addresses[hashedName] = daoAddr;
        daos[daoAddr] = hashedName;

        dao.initialize(creator, msg.sender);
        //slither-disable-next-line reentrancy-events
        emit DAOCreated(daoAddr, daoName);
    }

    /**
     * @notice Returns the DAO address based on its name.
     * @return The address of a DAO, given its name.
     * @param daoName Name of the DAO to be searched.
     */
    function getDaoAddress(string calldata daoName)
        external
        view
        returns (address)
    {
        return addresses[keccak256(abi.encode(daoName))];
    }

    /**
     * @notice Adds adapters and sets their ACL for DaoRegistry functions.
     * @dev A new DAO is instantiated with only the Core Modules enabled, to reduce the call cost. This call must be made to add adapters.
     * @dev The message sender must be an active member of the DAO.
     * @dev The DAO must be in `CREATION` state.
     * @param dao DaoRegistry to have adapters added to.
     * @param adapters Adapter structs to be added to the DAO.
     */
    function addAdapters(DaoRegistry dao, Adapter[] calldata adapters)
        external
    {
        require(dao.isMember(msg.sender), "not member");
        //Registring Adapters
        require(
            dao.state() == DaoRegistry.DaoState.CREATION,
            "this DAO has already been setup"
        );

        for (uint256 i = 0; i < adapters.length; i++) {
            //slither-disable-next-line calls-loop
            dao.replaceAdapter(
                adapters[i].id,
                adapters[i].addr,
                adapters[i].flags,
                new bytes32[](0),
                new uint256[](0)
            );
        }
    }

    /**
     * @notice Configures extension to set the ACL for each adapter that needs to access the extension.
     * @dev The message sender must be an active member of the DAO.
     * @dev The DAO must be in `CREATION` state.
     * @param dao DaoRegistry for which the extension is being configured.
     * @param extension The address of the extension to be configured.
     * @param adapters Adapter structs for which the ACL is being set for the extension.
     */
    function configureExtension(
        DaoRegistry dao,
        address extension,
        Adapter[] calldata adapters
    ) external {
        require(dao.isMember(msg.sender), "not member");
        //Registring Adapters
        require(
            dao.state() == DaoRegistry.DaoState.CREATION,
            "this DAO has already been setup"
        );

        for (uint256 i = 0; i < adapters.length; i++) {
            //slither-disable-next-line calls-loop
            dao.setAclToExtensionForAdapter(
                extension,
                adapters[i].addr,
                adapters[i].flags
            );
        }
    }

    /**
     * @notice Removes an adapter with a given ID from a DAO, and adds a new one of the same ID.
     * @dev The message sender must be an active member of the DAO.
     * @dev The DAO must be in `CREATION` state.
     * @param dao DAO to be updated.
     * @param adapter Adapter that will be replacing the currently-existing adapter of the same ID.
     */
    function updateAdapter(DaoRegistry dao, Adapter calldata adapter) external {
        require(dao.isMember(msg.sender), "not member");
        require(
            dao.state() == DaoRegistry.DaoState.CREATION,
            "this DAO has already been setup"
        );

        dao.replaceAdapter(
            adapter.id,
            adapter.addr,
            adapter.flags,
            new bytes32[](0),
            new uint256[](0)
        );
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import '../guards/AdapterGuard.sol';
import '../guards/MemberGuard.sol';
import '../extensions/IExtension.sol';
import '../helpers/DaoHelper.sol';

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

contract DaoRegistry is MemberGuard, AdapterGuard {
    /**
     * EVENTS
     */
    event SubmittedProposal(bytes32 proposalId, uint256 flags);
    event SponsoredProposal(
        bytes32 proposalId,
        uint256 flags,
        address votingAdapter
    );
    event ProcessedProposal(bytes32 proposalId, uint256 flags);
    event AdapterAdded(
        bytes32 adapterId,
        address adapterAddress,
        uint256 flags
    );
    event AdapterRemoved(bytes32 adapterId);
    event ExtensionAdded(bytes32 extensionId, address extensionAddress);
    event ExtensionRemoved(bytes32 extensionId);
    event UpdateDelegateKey(address memberAddress, address newDelegateKey);
    event ConfigurationUpdated(bytes32 key, uint256 value);
    event AddressConfigurationUpdated(bytes32 key, address value);

    enum DaoState {
        CREATION,
        READY
    }

    enum MemberFlag {
        EXISTS,
        JAILED
    }

    enum ProposalFlag {
        EXISTS,
        SPONSORED,
        PROCESSED
    }

    enum AclFlag {
        REPLACE_ADAPTER,
        SUBMIT_PROPOSAL,
        UPDATE_DELEGATE_KEY,
        SET_CONFIGURATION,
        ADD_EXTENSION,
        REMOVE_EXTENSION,
        NEW_MEMBER,
        JAIL_MEMBER
    }

    /**
     * STRUCTURES
     */
    struct Proposal {
        /// the structure to track all the proposals in the DAO
        address adapterAddress; /// the adapter address that called the functions to change the DAO state
        uint256 flags; /// flags to track the state of the proposal: exist, sponsored, processed, canceled, etc.
    }

    struct Member {
        /// the structure to track all the members in the DAO
        uint256 flags; /// flags to track the state of the member: exists, etc
    }

    struct Checkpoint {
        /// A checkpoint for marking number of votes from a given block
        uint96 fromBlock;
        uint160 amount;
    }

    struct DelegateCheckpoint {
        /// A checkpoint for marking the delegate key for a member from a given block
        uint96 fromBlock;
        address delegateKey;
    }

    struct AdapterEntry {
        bytes32 id;
        uint256 acl;
    }

    struct ExtensionEntry {
        bytes32 id;
        mapping(address => uint256) acl;
        bool deleted;
    }

    /**
     * PUBLIC VARIABLES
     */

    /// @notice internally tracks deployment under eip-1167 proxy pattern
    bool public initialized = false;

    /// @notice The dao state starts as CREATION and is changed to READY after the finalizeDao call
    DaoState public state;

    /// @notice The map to track all members of the DAO with their existing flags
    mapping(address => Member) public members;
    /// @notice The list of members
    address[] private _members;

    /// @notice delegate key => member address mapping
    mapping(address => address) public memberAddressesByDelegatedKey;

    /// @notice The map that keeps track of all proposasls submitted to the DAO
    mapping(bytes32 => Proposal) public proposals;
    /// @notice The map that tracks the voting adapter address per proposalId: proposalId => adapterAddress
    mapping(bytes32 => address) public votingAdapter;
    /// @notice The map that keeps track of all adapters registered in the DAO: sha3(adapterId) => adapterAddress
    mapping(bytes32 => address) public adapters;
    /// @notice The inverse map to get the adapter id based on its address
    mapping(address => AdapterEntry) public inverseAdapters;
    /// @notice The map that keeps track of all extensions registered in the DAO: sha3(extId) => extAddress
    mapping(bytes32 => address) public extensions;
    /// @notice The inverse map to get the extension id based on its address
    mapping(address => ExtensionEntry) public inverseExtensions;
    /// @notice The map that keeps track of configuration parameters for the DAO and adapters: sha3(configId) => numericValue
    mapping(bytes32 => uint256) public mainConfiguration;
    /// @notice The map to track all the configuration of type Address: sha3(configId) => addressValue
    mapping(bytes32 => address) public addressConfiguration;

    /// @notice controls the lock mechanism using the block.number
    uint256 public lockedAt;

    /**
     * INTERNAL VARIABLES
     */

    /// @notice memberAddress => checkpointNum => DelegateCheckpoint
    mapping(address => mapping(uint32 => DelegateCheckpoint)) _checkpoints;
    /// @notice memberAddress => numDelegateCheckpoints
    mapping(address => uint32) _numCheckpoints;

    /// @notice Clonable contract must have an empty constructor
    constructor() {}

    /**
     * @notice Initialises the DAO
     * @dev Involves initialising available tokens, checkpoints, and membership of creator
     * @dev Can only be called once
     * @param creator The DAO's creator, who will be an initial member
     * @param payer The account which paid for the transaction to create the DAO, who will be an initial member
     */
    //slither-disable-next-line reentrancy-no-eth
    function initialize(address creator, address payer) external {
        require(!initialized, 'dao already initialized');
        initialized = true;
        potentialNewMember(msg.sender);
        potentialNewMember(creator);
        potentialNewMember(payer);
    }

    /**
     * ACCESS CONTROL
     */

    /**
     * @dev Sets the state of the dao to READY
     */
    function finalizeDao() external {
        require(
            isActiveMember(this, msg.sender) || isAdapter(msg.sender),
            'not allowed to finalize'
        );
        state = DaoState.READY;
    }

    /**
     * @notice Contract lock strategy to lock only the caller is an adapter or extension.
     */
    function lockSession() external {
        if (isAdapter(msg.sender) || isExtension(msg.sender)) {
            lockedAt = block.number;
        }
    }

    /**
     * @notice Contract lock strategy to release the lock only the caller is an adapter or extension.
     */
    function unlockSession() external {
        if (isAdapter(msg.sender) || isExtension(msg.sender)) {
            lockedAt = 0;
        }
    }

    /**
     * CONFIGURATIONS
     */

    /**
     * @notice Sets a configuration value
     * @dev Changes the value of a key in the configuration mapping
     * @param key The configuration key for which the value will be set
     * @param value The value to set the key
     */
    function setConfiguration(bytes32 key, uint256 value)
        external
        hasAccess(this, AclFlag.SET_CONFIGURATION)
    {
        mainConfiguration[key] = value;

        emit ConfigurationUpdated(key, value);
    }

    /**
     * @notice Sets an configuration value
     * @dev Changes the value of a key in the configuration mapping
     * @param key The configuration key for which the value will be set
     * @param value The value to set the key
     */
    function setAddressConfiguration(bytes32 key, address value)
        external
        hasAccess(this, AclFlag.SET_CONFIGURATION)
    {
        addressConfiguration[key] = value;

        emit AddressConfigurationUpdated(key, value);
    }

    /**
     * @return The configuration value of a particular key
     * @param key The key to look up in the configuration mapping
     */
    function getConfiguration(bytes32 key) external view returns (uint256) {
        return mainConfiguration[key];
    }

    /**
     * @return The configuration value of a particular key
     * @param key The key to look up in the configuration mapping
     */
    function getAddressConfiguration(bytes32 key)
        external
        view
        returns (address)
    {
        return addressConfiguration[key];
    }

    /**
     * ADAPTERS
     */

    /**
     * @notice Replaces an adapter in the registry in a single step.
     * @notice It handles addition and removal of adapters as special cases.
     * @dev It removes the current adapter if the adapterId maps to an existing adapter address.
     * @dev It adds an adapter if the adapterAddress parameter is not zeroed.
     * @param adapterId The unique identifier of the adapter
     * @param adapterAddress The address of the new adapter or zero if it is a removal operation
     * @param acl The flags indicating the access control layer or permissions of the new adapter
     * @param keys The keys indicating the adapter configuration names.
     * @param values The values indicating the adapter configuration values.
     */
    function replaceAdapter(
        bytes32 adapterId,
        address adapterAddress,
        uint128 acl,
        bytes32[] calldata keys,
        uint256[] calldata values
    ) external hasAccess(this, AclFlag.REPLACE_ADAPTER) {
        require(adapterId != bytes32(0), 'adapterId must not be empty');

        address currentAdapterAddr = adapters[adapterId];
        if (currentAdapterAddr != address(0x0)) {
            delete inverseAdapters[currentAdapterAddr];
            delete adapters[adapterId];
            emit AdapterRemoved(adapterId);
        }

        for (uint256 i = 0; i < keys.length; i++) {
            bytes32 key = keys[i];
            uint256 value = values[i];
            mainConfiguration[key] = value;
            emit ConfigurationUpdated(key, value);
        }

        if (adapterAddress != address(0x0)) {
            require(
                inverseAdapters[adapterAddress].id == bytes32(0),
                'adapterAddress already in use'
            );
            adapters[adapterId] = adapterAddress;
            inverseAdapters[adapterAddress].id = adapterId;
            inverseAdapters[adapterAddress].acl = acl;
            emit AdapterAdded(adapterId, adapterAddress, acl);
        }
    }

    /**
     * @notice Looks up if there is an adapter of a given address
     * @return Whether or not the address is an adapter
     * @param adapterAddress The address to look up
     */
    function isAdapter(address adapterAddress) public view returns (bool) {
        return inverseAdapters[adapterAddress].id != bytes32(0);
    }

    /**
     * @notice Checks if an adapter has a given ACL flag
     * @return Whether or not the given adapter has the given flag set
     * @param adapterAddress The address to look up
     * @param flag The ACL flag to check against the given address
     */
    function hasAdapterAccess(address adapterAddress, AclFlag flag)
        external
        view
        returns (bool)
    {
        return
            DaoHelper.getFlag(inverseAdapters[adapterAddress].acl, uint8(flag));
    }

    /**
     * @return The address of a given adapter ID
     * @param adapterId The ID to look up
     */
    function getAdapterAddress(bytes32 adapterId)
        external
        view
        returns (address)
    {
        require(adapters[adapterId] != address(0), 'adapter not found');
        return adapters[adapterId];
    }

    /**
     * EXTENSIONS
     */

    /**
     * @notice Adds a new extension to the registry
     * @param extensionId The unique identifier of the new extension
     * @param extension The address of the extension
     */
    // slither-disable-next-line reentrancy-events
    function addExtension(bytes32 extensionId, IExtension extension)
        external
        hasAccess(this, AclFlag.ADD_EXTENSION)
    {
        require(extensionId != bytes32(0), 'extension id must not be empty');
        require(
            extensions[extensionId] == address(0x0),
            'extensionId already in use'
        );
        require(
            !inverseExtensions[address(extension)].deleted,
            'extension can not be re-added'
        );
        extensions[extensionId] = address(extension);
        inverseExtensions[address(extension)].id = extensionId;
        emit ExtensionAdded(extensionId, address(extension));
    }

    // v1.0.6 signature
    function addExtension(
        bytes32,
        IExtension,
        address
    ) external {
        revert('not implemented');
    }

    /**
     * @notice Removes an adapter from the registry
     * @param extensionId The unique identifier of the extension
     */
    function removeExtension(bytes32 extensionId)
        external
        hasAccess(this, AclFlag.REMOVE_EXTENSION)
    {
        require(extensionId != bytes32(0), 'extensionId must not be empty');
        address extensionAddress = extensions[extensionId];
        require(extensionAddress != address(0x0), 'extensionId not registered');
        ExtensionEntry storage extEntry = inverseExtensions[extensionAddress];
        extEntry.deleted = true;
        //slither-disable-next-line mapping-deletion
        delete extensions[extensionId];
        emit ExtensionRemoved(extensionId);
    }

    /**
     * @notice Looks up if there is an extension of a given address
     * @return Whether or not the address is an extension
     * @param extensionAddr The address to look up
     */
    function isExtension(address extensionAddr) public view returns (bool) {
        return inverseExtensions[extensionAddr].id != bytes32(0);
    }

    /**
     * @notice It sets the ACL flags to an Adapter to make it possible to access specific functions of an Extension.
     */
    function setAclToExtensionForAdapter(
        address extensionAddress,
        address adapterAddress,
        uint256 acl
    ) external hasAccess(this, AclFlag.ADD_EXTENSION) {
        require(isAdapter(adapterAddress), 'not an adapter');
        require(isExtension(extensionAddress), 'not an extension');
        inverseExtensions[extensionAddress].acl[adapterAddress] = acl;
    }

    /**
     * @notice Checks if an adapter has a given ACL flag
     * @return Whether or not the given adapter has the given flag set
     * @param adapterAddress The address to look up
     * @param flag The ACL flag to check against the given address
     */
    function hasAdapterAccessToExtension(
        address adapterAddress,
        address extensionAddress,
        uint8 flag
    ) external view returns (bool) {
        return
            isAdapter(adapterAddress) &&
            DaoHelper.getFlag(
                inverseExtensions[extensionAddress].acl[adapterAddress],
                uint8(flag)
            );
    }

    /**
     * @return The address of a given extension Id
     * @param extensionId The ID to look up
     */
    function getExtensionAddress(bytes32 extensionId)
        external
        view
        returns (address)
    {
        require(extensions[extensionId] != address(0), 'extension not found');
        return extensions[extensionId];
    }

    /**
     * PROPOSALS
     */

    /**
     * @notice Submit proposals to the DAO registry
     */
    function submitProposal(bytes32 proposalId)
        external
        hasAccess(this, AclFlag.SUBMIT_PROPOSAL)
    {
        require(proposalId != bytes32(0), 'invalid proposalId');
        require(
            !getProposalFlag(proposalId, ProposalFlag.EXISTS),
            'proposalId must be unique'
        );
        proposals[proposalId] = Proposal(msg.sender, 1); // 1 means that only the first flag is being set i.e. EXISTS
        emit SubmittedProposal(proposalId, 1);
    }

    /**
     * @notice Sponsor proposals that were submitted to the DAO registry
     * @dev adds SPONSORED to the proposal flag
     * @param proposalId The ID of the proposal to sponsor
     * @param sponsoringMember The member who is sponsoring the proposal
     */
    function sponsorProposal(
        bytes32 proposalId,
        address sponsoringMember,
        address votingAdapterAddr
    ) external onlyMember2(this, sponsoringMember) {
        // also checks if the flag was already set
        Proposal storage proposal = _setProposalFlag(
            proposalId,
            ProposalFlag.SPONSORED
        );

        uint256 flags = proposal.flags;

        require(
            proposal.adapterAddress == msg.sender,
            'only the adapter that submitted the proposal can sponsor it'
        );

        require(
            !DaoHelper.getFlag(flags, uint8(ProposalFlag.PROCESSED)),
            'proposal already processed'
        );
        votingAdapter[proposalId] = votingAdapterAddr;
        emit SponsoredProposal(proposalId, flags, votingAdapterAddr);
    }

    /**
     * @notice Mark a proposal as processed in the DAO registry
     * @param proposalId The ID of the proposal that is being processed
     */
    function processProposal(bytes32 proposalId) external {
        Proposal storage proposal = _setProposalFlag(
            proposalId,
            ProposalFlag.PROCESSED
        );

        require(proposal.adapterAddress == msg.sender, 'err::adapter mismatch');
        uint256 flags = proposal.flags;

        emit ProcessedProposal(proposalId, flags);
    }

    /**
     * @notice Sets a flag of a proposal
     * @dev Reverts if the proposal is already processed
     * @param proposalId The ID of the proposal to be changed
     * @param flag The flag that will be set on the proposal
     */
    function _setProposalFlag(bytes32 proposalId, ProposalFlag flag)
        internal
        returns (Proposal storage)
    {
        Proposal storage proposal = proposals[proposalId];

        uint256 flags = proposal.flags;
        require(
            DaoHelper.getFlag(flags, uint8(ProposalFlag.EXISTS)),
            'proposal does not exist for this dao'
        );

        require(
            proposal.adapterAddress == msg.sender,
            'invalid adapter try to set flag'
        );

        require(!DaoHelper.getFlag(flags, uint8(flag)), 'flag already set');

        flags = DaoHelper.setFlag(flags, uint8(flag), true);
        proposals[proposalId].flags = flags;

        return proposals[proposalId];
    }

    /**
     * @return Whether or not a flag is set for a given proposal
     * @param proposalId The proposal to check against flag
     * @param flag The flag to check in the proposal
     */
    function getProposalFlag(bytes32 proposalId, ProposalFlag flag)
        public
        view
        returns (bool)
    {
        return DaoHelper.getFlag(proposals[proposalId].flags, uint8(flag));
    }

    /**
     * MEMBERS
     */

    /**
     * @notice Sets true for the JAILED flag.
     * @param memberAddress The address of the member to update the flag.
     */
    function jailMember(address memberAddress)
        external
        hasAccess(this, AclFlag.JAIL_MEMBER)
    {
        require(memberAddress != address(0x0), 'invalid member address');

        Member storage member = members[memberAddress];
        require(
            DaoHelper.getFlag(member.flags, uint8(MemberFlag.EXISTS)),
            'member does not exist'
        );

        member.flags = DaoHelper.setFlag(
            member.flags,
            uint8(MemberFlag.JAILED),
            true
        );
    }

    /**
     * @notice Sets false for the JAILED flag.
     * @param memberAddress The address of the member to update the flag.
     */
    function unjailMember(address memberAddress)
        external
        hasAccess(this, AclFlag.JAIL_MEMBER)
    {
        require(memberAddress != address(0x0), 'invalid member address');

        Member storage member = members[memberAddress];
        require(
            DaoHelper.getFlag(member.flags, uint8(MemberFlag.EXISTS)),
            'member does not exist'
        );

        member.flags = DaoHelper.setFlag(
            member.flags,
            uint8(MemberFlag.JAILED),
            false
        );
    }

    /**
     * @notice Checks if a given member address is not jailed.
     * @param memberAddress The address of the member to check the flag.
     */
    function notJailed(address memberAddress) external view returns (bool) {
        return
            !DaoHelper.getFlag(
                members[memberAddress].flags,
                uint8(MemberFlag.JAILED)
            );
    }

    /**
     * @notice Registers a member address in the DAO if it is not registered or invalid.
     * @notice A potential new member is a member that holds no shares, and its registration still needs to be voted on.
     */
    function potentialNewMember(address memberAddress)
        public
        hasAccess(this, AclFlag.NEW_MEMBER)
    {
        require(memberAddress != address(0x0), 'invalid member address');

        Member storage member = members[memberAddress];
        if (!DaoHelper.getFlag(member.flags, uint8(MemberFlag.EXISTS))) {
            require(
                memberAddressesByDelegatedKey[memberAddress] == address(0x0),
                'member address already taken as delegated key'
            );
            member.flags = DaoHelper.setFlag(
                member.flags,
                uint8(MemberFlag.EXISTS),
                true
            );
            memberAddressesByDelegatedKey[memberAddress] = memberAddress;
            _members.push(memberAddress);
        }

        address bankAddress = extensions[DaoHelper.BANK];
        if (bankAddress != address(0x0)) {
            BankExtension bank = BankExtension(bankAddress);
            if (bank.balanceOf(memberAddress, DaoHelper.MEMBER_COUNT) == 0) {
                bank.addToBalance(
                    this,
                    memberAddress,
                    DaoHelper.MEMBER_COUNT,
                    1
                );
            }
        }
    }

    /**
     * @return Whether or not a given address is a member of the DAO.
     * @dev it will resolve by delegate key, not member address.
     * @param addr The address to look up
     */
    function isMember(address addr) external view returns (bool) {
        address memberAddress = memberAddressesByDelegatedKey[addr];
        return getMemberFlag(memberAddress, MemberFlag.EXISTS);
    }

    /**
     * @return Whether or not a flag is set for a given member
     * @param memberAddress The member to check against flag
     * @param flag The flag to check in the member
     */
    function getMemberFlag(address memberAddress, MemberFlag flag)
        public
        view
        returns (bool)
    {
        return DaoHelper.getFlag(members[memberAddress].flags, uint8(flag));
    }

    /**
     * @notice Returns the number of members in the registry.
     */
    function getNbMembers() external view returns (uint256) {
        return _members.length;
    }

    /**
     * @notice Returns the member address for the given index.
     */
    function getMemberAddress(uint256 index) external view returns (address) {
        return _members[index];
    }

    /**
     * DELEGATE
     */

    /**
     * @notice Updates the delegate key of a member
     * @param memberAddr The member doing the delegation
     * @param newDelegateKey The member who is being delegated to
     */
    function updateDelegateKey(address memberAddr, address newDelegateKey)
        external
        hasAccess(this, AclFlag.UPDATE_DELEGATE_KEY)
    {
        require(newDelegateKey != address(0x0), 'newDelegateKey cannot be 0');

        // skip checks if member is setting the delegate key to their member address
        if (newDelegateKey != memberAddr) {
            require(
                // newDelegate must not be delegated to
                memberAddressesByDelegatedKey[newDelegateKey] == address(0x0),
                'cannot overwrite existing delegated keys'
            );
        } else {
            require(
                memberAddressesByDelegatedKey[memberAddr] == address(0x0),
                'address already taken as delegated key'
            );
        }

        Member storage member = members[memberAddr];
        require(
            DaoHelper.getFlag(member.flags, uint8(MemberFlag.EXISTS)),
            'member does not exist'
        );

        // Reset the delegation of the previous delegate
        memberAddressesByDelegatedKey[
            getCurrentDelegateKey(memberAddr)
        ] = address(0x0);

        memberAddressesByDelegatedKey[newDelegateKey] = memberAddr;

        _createNewDelegateCheckpoint(memberAddr, newDelegateKey);
        emit UpdateDelegateKey(memberAddr, newDelegateKey);
    }

    /**
     * @param checkAddr The address to check for a delegate
     * @return the delegated address or the checked address if it is not a delegate
     */
    function getAddressIfDelegated(address checkAddr)
        external
        view
        returns (address)
    {
        address delegatedKey = memberAddressesByDelegatedKey[checkAddr];
        return delegatedKey == address(0x0) ? checkAddr : delegatedKey;
    }

    /**
     * @param memberAddr The member whose delegate will be returned
     * @return the delegate key at the current time for a member
     */
    function getCurrentDelegateKey(address memberAddr)
        public
        view
        returns (address)
    {
        uint32 nCheckpoints = _numCheckpoints[memberAddr];
        return
            nCheckpoints > 0
                ? _checkpoints[memberAddr][nCheckpoints - 1].delegateKey
                : memberAddr;
    }

    /**
     * @param memberAddr The member address to look up
     * @return The delegate key address for memberAddr at the second last checkpoint number
     */
    function getPreviousDelegateKey(address memberAddr)
        external
        view
        returns (address)
    {
        uint32 nCheckpoints = _numCheckpoints[memberAddr];
        return
            nCheckpoints > 1
                ? _checkpoints[memberAddr][nCheckpoints - 2].delegateKey
                : memberAddr;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param memberAddr The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The delegate key of the member
     */
    function getPriorDelegateKey(address memberAddr, uint256 blockNumber)
        external
        view
        returns (address)
    {
        require(blockNumber < block.number, 'getPriorDelegateKey: NYD');

        uint32 nCheckpoints = _numCheckpoints[memberAddr];
        if (nCheckpoints == 0) {
            return memberAddr;
        }

        // First check most recent balance
        if (
            _checkpoints[memberAddr][nCheckpoints - 1].fromBlock <= blockNumber
        ) {
            return _checkpoints[memberAddr][nCheckpoints - 1].delegateKey;
        }

        // Next check implicit zero balance
        if (_checkpoints[memberAddr][0].fromBlock > blockNumber) {
            return memberAddr;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            DelegateCheckpoint memory cp = _checkpoints[memberAddr][center];
            if (cp.fromBlock == blockNumber) {
                return cp.delegateKey;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return _checkpoints[memberAddr][lower].delegateKey;
    }

    /**
     * @notice Creates a new delegate checkpoint of a certain member
     * @param member The member whose delegate checkpoints will be added to
     * @param newDelegateKey The delegate key that will be written into the new checkpoint
     */
    function _createNewDelegateCheckpoint(
        address member,
        address newDelegateKey
    ) internal {
        uint32 nCheckpoints = _numCheckpoints[member];
        // The only condition that we should allow the deletegaKey upgrade
        // is when the block.number exactly matches the fromBlock value.
        // Anything different from that should generate a new checkpoint.
        if (
            //slither-disable-next-line incorrect-equality
            nCheckpoints > 0 &&
            _checkpoints[member][nCheckpoints - 1].fromBlock == block.number
        ) {
            _checkpoints[member][nCheckpoints - 1].delegateKey = newDelegateKey;
        } else {
            _checkpoints[member][nCheckpoints] = DelegateCheckpoint(
                uint96(block.number),
                newDelegateKey
            );
            _numCheckpoints[member] = nCheckpoints + 1;
        }
    }
}

pragma solidity ^0.8.0;
import "../core/DaoRegistry.sol";

// SPDX-License-Identifier: MIT

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

interface IExtension {
    function initialize(DaoRegistry dao, address creator) external;
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
import "../../core/DaoRegistry.sol";
import "../../core/CloneFactory.sol";
import "../IFactory.sol";
import "./Bank.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

contract BankFactory is IFactory, CloneFactory, ReentrancyGuard {
    address public identityAddress;

    event BankCreated(address daoAddress, address extensionAddress);

    mapping(address => address) private _extensions;

    constructor(address _identityAddress) {
        require(_identityAddress != address(0x0), "invalid addr");
        identityAddress = _identityAddress;
    }

    /**
     * @notice Creates a new extension using clone factory.
     * @notice It can set additional arguments to the extension.
     * @notice It initializes the extension and sets the DAO owner as the extension creator.
     * @notice The DAO owner is stored at index 1 in the members storage.
     * @notice The safest way to read the new extension address is to read it from the event.
     * @param dao The dao address that will be associated with the new extension.
     * @param maxExternalTokens The maximum number of external tokens stored in the Bank
     */
    // slither-disable-next-line reentrancy-events
    function create(DaoRegistry dao, uint8 maxExternalTokens)
        external
        nonReentrant
    {
        address daoAddress = address(dao);
        require(daoAddress != address(0x0), "invalid dao addr");
        address extensionAddr = _createClone(identityAddress);
        _extensions[daoAddress] = extensionAddr;

        BankExtension extension = BankExtension(extensionAddr);
        extension.setMaxExternalTokens(maxExternalTokens);
        // Member at index 1 is the DAO owner, but also the payer of the DAO deployment
        extension.initialize(dao, dao.getMemberAddress(1));
        // slither-disable-next-line reentrancy-events
        emit BankCreated(daoAddress, address(extension));
    }

    /**
     * @notice Returns the extension address created for that DAO, or 0x0... if it does not exist.
     * @notice Do not rely on the result returned by this right after the new extension is cloned,
     * because it is prone to front-running attacks. During the extension creation it is safer to
     * read the new extension address from the event generated in the create call transaction.
     */
    function getExtensionAddress(address dao)
        external
        view
        override
        returns (address)
    {
        return _extensions[dao];
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../../core/DaoRegistry.sol";
import "../../core/CloneFactory.sol";
import "../IFactory.sol";
import "./Executor.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

contract ExecutorExtensionFactory is IFactory, CloneFactory, ReentrancyGuard {
    address public identityAddress;

    event ExecutorCreated(address daoAddress, address extensionAddress);

    mapping(address => address) private _extensions;

    constructor(address _identityAddress) {
        require(_identityAddress != address(0x0), "invalid addr");
        identityAddress = _identityAddress;
    }

    /**
     * @notice Creates a new extension using clone factory.
     * @notice It can set additional arguments to the extension.
     * @notice It initializes the extension and sets the DAO owner as the extension creator.
     * @notice The safest way to read the new extension address is to read it from the event.
     * @param dao The dao address that will be associated with the new extension.
     */
    function create(DaoRegistry dao) external nonReentrant {
        address daoAddress = address(dao);
        require(daoAddress != address(0x0), "invalid dao addr");
        address payable extensionAddr = _createClone(identityAddress);
        _extensions[daoAddress] = extensionAddr;
        ExecutorExtension extension = ExecutorExtension(extensionAddr);
        extension.initialize(dao, address(0));
        // slither-disable-next-line reentrancy-events
        emit ExecutorCreated(daoAddress, address(extension));
    }

    /**
     * @notice Returns the extension address created for that DAO, or 0x0... if it does not exist.
     * @notice Do not rely on the result returned by this right after the new extension is cloned,
     * because it is prone to front-running attacks. During the extension creation it is safer to
     * read the new extension address from the event generated in the create call transaction.
     */
    function getExtensionAddress(address dao)
        external
        view
        override
        returns (address)
    {
        return _extensions[dao];
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
import "../../../core/DaoRegistry.sol";
import "../../../core/CloneFactory.sol";
import "../../IFactory.sol";
import "./ERC20TokenExtension.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

contract ERC20TokenExtensionFactory is IFactory, CloneFactory, ReentrancyGuard {
    address public identityAddress;

    event ERC20TokenExtensionCreated(
        address daoAddress,
        address extensionAddress
    );

    mapping(address => address) private _extensions;

    constructor(address _identityAddress) {
        require(_identityAddress != address(0x0), "invalid addr");
        identityAddress = _identityAddress;
    }

    /**
     * @notice Creates a new extension using clone factory.
     * @notice It can set additional arguments to the extension.
     * @notice It initializes the extension and sets the DAO owner as the extension creator.
     * @notice The safest way to read the new extension address is to read it from the event.
     * @param dao The dao address that will be associated with the new extension.
     * @param tokenName The name of the token.
     * @param tokenAddress The address of the ERC20 token.
     * @param tokenSymbol The symbol of the ERC20 token.
     * @param decimals The number of decimal places of the ERC20 token.
     */
    // slither-disable-next-line reentrancy-events
    function create(
        DaoRegistry dao,
        string calldata tokenName,
        address tokenAddress,
        string calldata tokenSymbol,
        uint8 decimals
    ) external nonReentrant {
        address daoAddress = address(dao);
        require(daoAddress != address(0x0), "invalid dao addr");
        address payable extensionAddr = _createClone(identityAddress);
        _extensions[daoAddress] = extensionAddr;
        ERC20Extension extension = ERC20Extension(extensionAddr);
        extension.setName(tokenName);
        extension.setToken(tokenAddress);
        extension.setSymbol(tokenSymbol);
        extension.setDecimals(decimals);
        extension.initialize(dao, address(0));
        // slither-disable-next-line reentrancy-events
        emit ERC20TokenExtensionCreated(daoAddress, address(extension));
    }

    /**
     * @notice Returns the extension address created for that DAO, or 0x0... if it does not exist.
     * @notice Do not rely on the result returned by this right after the new extension is cloned,
     * because it is prone to front-running attacks. During the extension creation it is safer to
     * read the new extension address from the event generated in the create call transaction.
     */
    function getExtensionAddress(address dao)
        external
        view
        override
        returns (address)
    {
        return _extensions[dao];
    }
}

pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import {Foundance} from "../../libraries/Foundance.sol";
import "../../core/DaoRegistry.sol";
import "../../core/CloneFactory.sol";
import "../IFactory.sol";
import "./DynamicEquityExtension.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract DynamicEquityExtensionFactory is
    IFactory,
    CloneFactory,
    ReentrancyGuard
{
    address public identityAddress;

    event DynamicEquityExtensionCreated(
        address daoAddress,
        address extensionAddress
    );

    mapping(address => address) private _extensions;

    constructor(address _identityAddress) {
        require(_identityAddress != address(0x0), "dynamicEquityExtFactory::invalid addr");
        identityAddress = _identityAddress;
    }

    function create(DaoRegistry dao) external nonReentrant {
        address daoAddress = address(dao);
        require(daoAddress != address(0x0), "dynamicEquityExtFactory::invalid dao addr");
        address payable extensionAddr = _createClone(identityAddress);
        _extensions[daoAddress] = extensionAddr;

        DynamicEquityExtension extension = DynamicEquityExtension(
            extensionAddr
        );

        extension.initialize(dao, address(0));
        emit DynamicEquityExtensionCreated(
            daoAddress,
            address(extension)
        );
    }
    
    function getExtensionAddress(address dao)
        external
        view
        override
        returns (address)
    {
        return _extensions[dao];
    }
}

pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import {Foundance} from "../../libraries/Foundance.sol";
import "../../core/DaoRegistry.sol";
import "../../core/CloneFactory.sol";
import "../IFactory.sol";
import "./CommunityIncentiveExtension.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract CommunityIncentiveExtensionFactory is
    IFactory,
    CloneFactory,
    ReentrancyGuard
{
    address public identityAddress;

    event CommunityIncentiveExtensionCreated(
        address daoAddress,
        address extensionAddress
    );

    mapping(address => address) private _extensions;

    constructor(address _identityAddress) {
        require(_identityAddress != address(0x0), "communityIncentiveExtFactory::invalid addr");
        identityAddress = _identityAddress;
    }

    function create(DaoRegistry dao) external nonReentrant {
        address daoAddress = address(dao);
        require(daoAddress != address(0x0), "communityIncentiveExtFactory::invalid dao addr");
        address payable extensionAddr = _createClone(identityAddress);
        _extensions[daoAddress] = extensionAddr;

        CommunityIncentiveExtension extension = CommunityIncentiveExtension(
            extensionAddr
        );

        extension.initialize(dao, address(0));
        emit CommunityIncentiveExtensionCreated(
            daoAddress,
            address(extension)
        );
    }
    
    function getExtensionAddress(address dao)
        external
        view
        override
        returns (address)
    {
        return _extensions[dao];
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import '../core/DaoRegistry.sol';
import '../extensions/bank/Bank.sol';
import '../guards/AdapterGuard.sol';
import './modifiers/Reimbursable.sol';
import '../utils/Signatures.sol';
import '../helpers/DaoHelper.sol';

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

contract Manager is Reimbursable, AdapterGuard, Signatures {
    enum UpdateType {
        UNKNOWN,
        ADAPTER,
        EXTENSION,
        CONFIGS
    }

    enum ConfigType {
        NUMERIC,
        ADDRESS
    }

    struct Configuration {
        bytes32 key;
        uint256 numericValue;
        address addressValue;
        ConfigType configType;
    }

    struct ProposalDetails {
        bytes32 adapterOrExtensionId;
        address adapterOrExtensionAddr;
        UpdateType updateType;
        uint128 flags;
        bytes32[] keys;
        uint256[] values;
        address[] extensionAddresses;
        uint128[] extensionAclFlags;
    }

    struct ManagingCoupon {
        address daoAddress;
        ProposalDetails proposal;
        Configuration[] configs;
        uint256 nonce;
    }

    mapping(address => uint256) public nonces;

    string public constant MANAGING_COUPON_MESSAGE_TYPE =
        'Message(address daoAddress,ProposalDetails proposal,Configuration[] configs,uint256 nonce)Configuration(bytes32 key,uint256 numericValue,address addressValue,uint8 configType)ProposalDetails(bytes32 adapterOrExtensionId,address adapterOrExtensionAddr,uint8 updateType,uint128 flags,bytes32[] keys,uint256[] values,address[] extensionAddresses,uint128[] extensionAclFlags)';
    bytes32 public constant MANAGING_COUPON_MESSAGE_TYPEHASH =
        keccak256(abi.encodePacked(MANAGING_COUPON_MESSAGE_TYPE));

    string public constant PROPOSAL_DETAILS_TYPE =
        'ProposalDetails(bytes32 adapterOrExtensionId,address adapterOrExtensionAddr,uint8 updateType,uint128 flags,bytes32[] keys,uint256[] values,address[] extensionAddresses,uint128[] extensionAclFlags)';
    bytes32 public constant PROPOSAL_DETAILS_TYPEHASH =
        keccak256(abi.encodePacked(PROPOSAL_DETAILS_TYPE));

    string public constant CONFIGURATION_DETAILS_TYPE =
        'Configuration(bytes32 key,uint256 numericValue,address addressValue,uint8 configType)';
    bytes32 public constant CONFIGURATION_DETAILS_TYPEHASH =
        keccak256(abi.encodePacked(CONFIGURATION_DETAILS_TYPE));

    bytes32 public constant SignerAddressConfig =
        keccak256('Manager.signerAddress');

    /**
     * @notice Configures the Adapter with the managing signer address.
     * @param signerAddress the address of the managing signer
     */
    function configureDao(DaoRegistry dao, address signerAddress)
        external
        onlyAdapter(dao)
    {
        dao.setAddressConfiguration(SignerAddressConfig, signerAddress);
    }

    function processSignedProposal(
        DaoRegistry dao,
        ProposalDetails calldata proposal,
        Configuration[] memory configs,
        uint256 nonce,
        bytes memory signature
    ) external {
        require(
            proposal.keys.length == proposal.values.length,
            'must be an equal number of config keys and values'
        );
        require(
            DaoHelper.isNotReservedAddress(proposal.adapterOrExtensionAddr),
            'address is reserved'
        );
        require(nonce > nonces[address(dao)], 'coupon already redeemed');
        nonces[address(dao)] = nonce;

        ManagingCoupon memory managingCoupon = ManagingCoupon(
            address(dao),
            proposal,
            configs,
            nonce
        );
        bytes32 hash = hashCouponMessage(dao, managingCoupon);

        require(
            SignatureChecker.isValidSignatureNow(
                dao.getAddressConfiguration(SignerAddressConfig),
                hash,
                signature
            ),
            'invalid sig'
        );

        _submitAndProcessProposal(dao, proposal, configs);
    }

    /**
     * @notice Submits and processes a proposal that was signed by the managing address.
     * @dev Reverts when the adapter address is already in use and it is an adapter addition.
     * @dev Reverts when the extension address is already in use and it is an extension addition.
     * @param dao The dao address.
     * @param proposal The proposal data.
     * @param configs The configurations to be updated.
     */
    // slither-disable-next-line reentrancy-benign
    function _submitAndProcessProposal(
        DaoRegistry dao,
        ProposalDetails calldata proposal,
        Configuration[] memory configs
    ) internal reimbursable(dao) {
        if (proposal.updateType == UpdateType.ADAPTER) {
            dao.replaceAdapter(
                proposal.adapterOrExtensionId,
                proposal.adapterOrExtensionAddr,
                proposal.flags,
                proposal.keys,
                proposal.values
            );

            // Grant new adapter access to extensions.
            for (uint256 i = 0; i < proposal.extensionAclFlags.length; i++) {
                _grantExtensionAccess(
                    dao,
                    proposal.extensionAddresses[i],
                    proposal.adapterOrExtensionAddr,
                    proposal.extensionAclFlags[i]
                );
            }
        } else if (proposal.updateType == UpdateType.EXTENSION) {
            _replaceExtension(dao, proposal);

            // Grant adapters access to new extension.
            for (uint256 i = 0; i < proposal.extensionAclFlags.length; i++) {
                _grantExtensionAccess(
                    dao,
                    proposal.adapterOrExtensionAddr,
                    proposal.extensionAddresses[i], // Adapters.
                    proposal.extensionAclFlags[i]
                );
            }
        } else if (proposal.updateType == UpdateType.CONFIGS) {
            for (uint256 i = 0; i < proposal.extensionAclFlags.length; i++) {
                _grantExtensionAccess(
                    dao,
                    proposal.extensionAddresses[i],
                    proposal.adapterOrExtensionAddr,
                    proposal.extensionAclFlags[i]
                );
            }
        } else {
            revert('unknown update type');
        }
        _saveDaoConfigurations(dao, configs);
    }

    /**
     * @notice If the extension is already registered, it removes the extension from the DAO Registry.
     * @notice If the adapterOrExtensionAddr is provided, the new address is added as a new extension to the DAO Registry.
     */
    function _replaceExtension(DaoRegistry dao, ProposalDetails memory proposal)
        internal
    {
        if (dao.extensions(proposal.adapterOrExtensionId) != address(0x0)) {
            dao.removeExtension(proposal.adapterOrExtensionId);
        }

        if (proposal.adapterOrExtensionAddr != address(0x0)) {
            try
                dao.addExtension(
                    proposal.adapterOrExtensionId,
                    IExtension(proposal.adapterOrExtensionAddr)
                )
            {} catch {
                // v1.0.6 signature
                dao.addExtension(
                    proposal.adapterOrExtensionId,
                    IExtension(proposal.adapterOrExtensionAddr),
                    // The creator of the extension must be set as the DAO owner,
                    // which is stored at index 0 in the members storage.
                    dao.getMemberAddress(0)
                );
            }
        }
    }

    /**
     * @notice Saves to the DAO Registry the ACL Flag that grants the access to the given `extensionAddresses`
     */
    function _grantExtensionAccess(
        DaoRegistry dao,
        address extensionAddr,
        address adapterAddr,
        uint128 acl
    ) internal {
        // It is fine to execute the external call inside the loop
        // because it is calling the correct function in the dao contract
        // it won't be calling a fallback that always revert.
        // slither-disable-next-line calls-loop
        dao.setAclToExtensionForAdapter(
            // It needs to be registered as extension
            extensionAddr,
            // It needs to be registered as adapter
            adapterAddr,
            // Indicate which access level will be granted
            acl
        );
    }

    /**
     * @notice Saves the numeric/address configurations to the DAO registry
     */
    function _saveDaoConfigurations(
        DaoRegistry dao,
        Configuration[] memory configs
    ) internal {
        for (uint256 i = 0; i < configs.length; i++) {
            Configuration memory config = configs[i];
            if (ConfigType.NUMERIC == config.configType) {
                // It is fine to execute the external call inside the loop
                // because it is calling the correct function in the dao contract
                // it won't be calling a fallback that always revert.
                // slither-disable-next-line calls-loop
                dao.setConfiguration(config.key, config.numericValue);
            } else if (ConfigType.ADDRESS == config.configType) {
                // It is fine to execute the external call inside the loop
                // because it is calling the correct function in the dao contract
                // it won't be calling a fallback that always revert.
                // slither-disable-next-line calls-loop
                dao.setAddressConfiguration(config.key, config.addressValue);
            }
        }
    }

    /**
     * @notice Hashes the provided coupon as an ERC712 hash.
     * @param dao is the DAO instance to be configured
     * @param coupon is the coupon to hash
     */
    function hashCouponMessage(DaoRegistry dao, ManagingCoupon memory coupon)
        public
        view
        returns (bytes32)
    {
        bytes32 message = keccak256(
            abi.encode(
                MANAGING_COUPON_MESSAGE_TYPEHASH,
                coupon.daoAddress,
                hashProposal(coupon.proposal),
                hashConfigurations(coupon.configs),
                coupon.nonce
            )
        );

        return hashMessage(dao, address(this), message);
    }

    function hashProposal(ProposalDetails memory proposal)
        public
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    PROPOSAL_DETAILS_TYPEHASH,
                    proposal.adapterOrExtensionId,
                    proposal.adapterOrExtensionAddr,
                    proposal.updateType,
                    proposal.flags,
                    keccak256(abi.encodePacked(proposal.keys)),
                    keccak256(abi.encodePacked(proposal.values)),
                    keccak256(abi.encodePacked(proposal.extensionAddresses)),
                    keccak256(abi.encodePacked(proposal.extensionAclFlags))
                )
            );
    }

    function hashConfigurations(Configuration[] memory configs)
        public
        pure
        returns (bytes32)
    {
        bytes32[] memory result = new bytes32[](configs.length);
        for (uint256 i = 0; i < configs.length; i++) {
            result[i] = keccak256(
                abi.encode(
                    CONFIGURATION_DETAILS_TYPEHASH,
                    configs[i].key,
                    configs[i].numericValue,
                    configs[i].addressValue,
                    configs[i].configType
                )
            );
        }

        return keccak256(abi.encodePacked(result));
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../../core/DaoRegistry.sol";
import "../../extensions/bank/Bank.sol";
import "../../guards/MemberGuard.sol";
import "../../guards/AdapterGuard.sol";
import "../interfaces/IVoting.sol";
import "../../helpers/DaoHelper.sol";
import "../modifiers/Reimbursable.sol";
import "../../helpers/GovernanceHelper.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

contract VotingContract is IVoting, MemberGuard, AdapterGuard, Reimbursable {
    struct Voting {
        uint256 nbYes;
        uint256 nbNo;
        uint256 startingTime;
        uint256 blockNumber;
        mapping(address => uint256) votes;
    }

    bytes32 constant VotingPeriod = keccak256("voting.votingPeriod");
    bytes32 constant GracePeriod = keccak256("voting.gracePeriod");

    mapping(address => mapping(bytes32 => Voting)) public votes;

    string public constant ADAPTER_NAME = "VotingContract";

    /**
     * @notice returns the adapter name. Useful to identify wich voting adapter is actually configurated in the DAO.
     */
    function getAdapterName() external pure override returns (string memory) {
        return ADAPTER_NAME;
    }

    /**
     * @notice Configures the DAO with the Voting and Gracing periods.
     * @param votingPeriod The voting period in seconds.
     * @param gracePeriod The grace period in seconds.
     */
    function configureDao(
        DaoRegistry dao,
        uint256 votingPeriod,
        uint256 gracePeriod
    ) external onlyAdapter(dao) {
        dao.setConfiguration(VotingPeriod, votingPeriod);
        dao.setConfiguration(GracePeriod, gracePeriod);
    }

    /**
     * @notice Stats a new voting proposal considering the block time and number.
     * @notice This function is called from an Adapter to compute the voting starting period for a proposal.
     * @param proposalId The proposal id that is being started.
     */
    function startNewVotingForProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata
    ) external override onlyAdapter(dao) {
        Voting storage vote = votes[address(dao)][proposalId];
        vote.startingTime = block.timestamp;
        vote.blockNumber = block.number;
    }

    /**
     * @notice Returns the sender address.
     * @notice This funcion is required by the IVoting, usually offchain voting have different rules to identify the sender, but it is not the case here, so we just return the fallback argument: sender.
     * @param sender The fallback sender address that should be return in case no other is found.
     */
    function getSenderAddress(
        DaoRegistry,
        address,
        bytes memory,
        address sender
    ) external pure override returns (address) {
        return sender;
    }

    /**
     * @notice Submits a vote to the DAO Registry.
     * @notice Vote has to be submitted after the starting time defined in startNewVotingForProposal.
     * @notice The vote needs to be submitted within the voting period.
     * @notice A member can not vote twice or more.
     * @param dao The DAO address.
     * @param proposalId The proposal needs to be sponsored, and not processed.
     * @param voteValue Only Yes (1) and No (2) votes are allowed.
     */
    // The function is protected against reentrancy with the reimbursable modifier
    //slither-disable-next-line reentrancy-no-eth,reentrancy-benign
    function submitVote(
        DaoRegistry dao,
        bytes32 proposalId,
        uint256 voteValue
    ) external onlyMember(dao) reimbursable(dao) {
        require(
            dao.getProposalFlag(proposalId, DaoRegistry.ProposalFlag.SPONSORED),
            "the proposal has not been sponsored yet"
        );

        require(
            !dao.getProposalFlag(
                proposalId,
                DaoRegistry.ProposalFlag.PROCESSED
            ),
            "the proposal has already been processed"
        );

        require(
            voteValue < 3 && voteValue > 0,
            "only yes (1) and no (2) are possible values"
        );

        Voting storage vote = votes[address(dao)][proposalId];
        // slither-disable-next-line timestamp
        require(
            vote.startingTime > 0,
            "this proposalId has no vote going on at the moment"
        );
        // slither-disable-next-line timestamp
        require(
            block.timestamp <
                vote.startingTime + dao.getConfiguration(VotingPeriod),
            "vote has already ended"
        );

        address memberAddr = DaoHelper.msgSender(dao, msg.sender);

        require(vote.votes[memberAddr] == 0, "member has already voted");
        uint256 votingWeight = GovernanceHelper.getVotingWeight(
            dao,
            memberAddr,
            proposalId,
            vote.blockNumber
        );
        if (votingWeight == 0) revert("vote not allowed");

        vote.votes[memberAddr] = voteValue;

        if (voteValue == 1) {
            vote.nbYes = vote.nbYes + votingWeight;
        } else if (voteValue == 2) {
            vote.nbNo = vote.nbNo + votingWeight;
        }
    }

    /**
     * @notice Computes the voting result based on a proposal.
     * @param dao The DAO address.
     * @param proposalId The proposal that needs to have the votes computed.
     * @return state
     * The possible results are:
     * 0: has not started
     * 1: tie
     * 2: pass
     * 3: not pass
     * 4: in progress
     */
    function voteResult(DaoRegistry dao, bytes32 proposalId)
        external
        view
        override
        returns (VotingState state)
    {
        Voting storage vote = votes[address(dao)][proposalId];
        if (vote.startingTime == 0) {
            return VotingState.NOT_STARTED;
        }

        if (
            // slither-disable-next-line timestamp
            block.timestamp <
            vote.startingTime + dao.getConfiguration(VotingPeriod)
        ) {
            return VotingState.IN_PROGRESS;
        }

        if (
            // slither-disable-next-line timestamp
            block.timestamp <
            vote.startingTime +
                dao.getConfiguration(VotingPeriod) +
                dao.getConfiguration(GracePeriod)
        ) {
            return VotingState.GRACE_PERIOD;
        }

        if (vote.nbYes > vote.nbNo) {
            return VotingState.PASS;
        } else if (vote.nbYes < vote.nbNo) {
            return VotingState.NOT_PASS;
        } else {
            return VotingState.TIE;
        }
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../core/DaoRegistry.sol";
import "../extensions/bank/Bank.sol";
import "../helpers/DaoHelper.sol";
import "../adapters/interfaces/IVoting.sol";
import "./modifiers/Reimbursable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

contract TributeContract is Reimbursable, AdapterGuard {
    using Address for address;
    using SafeERC20 for IERC20;

    struct ProposalDetails {
        // The proposal id.
        bytes32 id;
        // The applicant address (who will receive the DAO internal tokens and
        // become a member; this address may be different than the actual owner
        // of the ERC-20 tokens being provided as tribute).
        address applicant;
        // The address of the DAO internal token to be minted to the applicant.
        address tokenToMint;
        // The amount requested of DAO internal tokens.
        uint256 requestAmount;
        // The address of the ERC-20 tokens that will be transferred to the DAO
        // in exchange for DAO internal tokens.
        address token;
        // The amount of tribute tokens.
        uint256 tributeAmount;
        // The owner of the ERC-20 tokens being provided as tribute.
        address tributeTokenOwner;
    }

    // Keeps track of all tribute proposals handled by each DAO.
    mapping(address => mapping(bytes32 => ProposalDetails)) public proposals;

    /**
     * @notice Configures the adapter for a particular DAO.
     * @notice Registers the DAO internal token with the DAO Bank.
     * @dev Only adapters registered to the DAO can execute the function call (or if the DAO is in creation mode).
     * @dev A DAO Bank extension must exist and be configured with proper access for this adapter.
     * @param dao The DAO address.
     * @param tokenAddrToMint The internal token address to be registered with the DAO Bank.
     */
    function configureDao(DaoRegistry dao, address tokenAddrToMint)
        external
        onlyAdapter(dao)
    {
        BankExtension bank = BankExtension(
            dao.getExtensionAddress(DaoHelper.BANK)
        );
        bank.registerPotentialNewInternalToken(dao, tokenAddrToMint);
    }

    /**
     * @notice Creates and sponsors a tribute proposal to start the voting process.
     * @dev Applicant address must not be reserved.
     * @dev Only members of the DAO can sponsor a tribute proposal.
     * @param dao The DAO address.
     * @param proposalId The proposal id (managed by the client).
     * @param applicant The applicant address (who will receive the DAO internal tokens and become a member).
     * @param tokenToMint The address of the DAO internal token to be minted to the applicant.
     * @param requestAmount The amount requested of DAO internal tokens.
     * @param tokenAddr The address of the ERC-20 tokens that will be transferred to the DAO in exchange for DAO internal tokens.
     * @param tributeAmount The amount of tribute tokens.
     * @param tributeTokenOwner The owner of the ERC-20 tokens being provided as tribute.
     * @param data Additional information related to the tribute proposal.
     */
    // slither-disable-next-line reentrancy-benign
    function submitProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        address applicant,
        address tokenToMint,
        uint256 requestAmount,
        address tokenAddr,
        uint256 tributeAmount,
        address tributeTokenOwner,
        bytes memory data
    ) external reimbursable(dao) {
        require(
            DaoHelper.isNotReservedAddress(applicant),
            "applicant is reserved address"
        );

        dao.submitProposal(proposalId);
        IVoting votingContract = IVoting(
            dao.getAdapterAddress(DaoHelper.VOTING)
        );
        address sponsoredBy = votingContract.getSenderAddress(
            dao,
            address(this),
            data,
            msg.sender
        );

        dao.sponsorProposal(proposalId, sponsoredBy, address(votingContract));
        DaoHelper.potentialNewMember(
            applicant,
            dao,
            BankExtension(dao.getExtensionAddress(DaoHelper.BANK))
        );

        votingContract.startNewVotingForProposal(dao, proposalId, data);

        proposals[address(dao)][proposalId] = ProposalDetails(
            proposalId,
            applicant,
            tokenToMint,
            requestAmount,
            tokenAddr,
            tributeAmount,
            tributeTokenOwner
        );
    }

    /**
     * @notice Processes a tribute proposal to handle minting and exchange of DAO internal tokens for tribute tokens (passed vote).
     * @dev Proposal id must exist.
     * @dev Only proposals that have not already been processed are accepted.
     * @dev Only sponsored proposals with completed voting are accepted.
     * @dev The owner of the ERC-20 tokens provided as tribute must first separately `approve` the adapter as spender of those tokens (so the tokens can be transferred for a passed vote).
     * @dev ERC-20 tribute tokens must be registered with the DAO Bank (a passed proposal will check and register the token if needed).
     * @param dao The DAO address.
     * @param proposalId The proposal id.
     */
    function processProposal(DaoRegistry dao, bytes32 proposalId)
        external
        reimbursable(dao)
    {
        ProposalDetails memory proposal = proposals[address(dao)][proposalId];
        require(proposal.id == proposalId, "proposal does not exist");
        require(
            !dao.getProposalFlag(
                proposalId,
                DaoRegistry.ProposalFlag.PROCESSED
            ),
            "proposal already processed"
        );

        IVoting votingContract = IVoting(dao.votingAdapter(proposalId));
        require(address(votingContract) != address(0), "adapter not found");

        IVoting.VotingState voteResult = votingContract.voteResult(
            dao,
            proposalId
        );

        dao.processProposal(proposalId);

        if (voteResult == IVoting.VotingState.PASS) {
            BankExtension bank = BankExtension(
                dao.getExtensionAddress(DaoHelper.BANK)
            );
            address tokenToMint = proposal.tokenToMint;
            address applicant = proposal.applicant;
            uint256 tributeAmount = proposal.tributeAmount;
            address tributeTokenOwner = proposal.tributeTokenOwner;
            require(
                bank.isInternalToken(tokenToMint),
                "it can only mint internal tokens"
            );

            if (!bank.isTokenAllowed(proposal.token)) {
                bank.registerPotentialNewToken(dao, proposal.token);
            }
            IERC20 erc20 = IERC20(proposal.token);
            erc20.safeTransferFrom(
                tributeTokenOwner,
                address(bank),
                tributeAmount
            );

            bank.addToBalance(
                dao,
                applicant,
                tokenToMint,
                proposal.requestAmount
            );
            bank.addToBalance(
                dao,
                DaoHelper.GUILD,
                proposal.token,
                tributeAmount
            );
        } else if (
            voteResult == IVoting.VotingState.NOT_PASS ||
            voteResult == IVoting.VotingState.TIE
        ) {
            //do nothing
        } else {
            revert("proposal has not been voted on yet");
        }
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
import {Foundance} from "../../libraries/Foundance.sol";
import "../../core/DaoRegistry.sol";
import "../../guards/AdapterGuard.sol";
import "./../modifiers/Reimbursable.sol";
import "../../adapters/interfaces/IVoting.sol";
import "../../adapters/interfaces/IDynamicEquity.sol";
import "../../helpers/FairShareHelper.sol";
import "../../helpers/DaoHelper.sol";
import "../../extensions/bank/Bank.sol";
import "../../extensions/foundance/DynamicEquityExtension.sol";


contract DynamicEquityAdapter is IDynamicEquity, AdapterGuard, Reimbursable {

    //EVENT
    event SubmitSetDynamicEquityProposalEvent(address _address, bytes _data, bytes32 proposalId);
    event ProcessSetDynamicEquityProposalEvent(address _address, string _name);//TODO
    event SubmitSetDynamicEquityMemberProposalEvent(address _address, bytes _data, bytes32 proposalId);
    event ProcessSetDynamicEquityMemberProposalEvent(address _address, string _name);//TODO
    event SubmitSetVestingMemberProposalEvent(address _address, bytes _data, bytes32 proposalId);
    event SubmitRemoveDynamicEquityMemberProposalEvent(address _address, bytes _data, bytes32 proposalId);
    event ProcessRemoveDynamicEquityMemberProposalEvent(address _address, string _name);//TODO
    event SubmitRemoveVestingMemberProposalEvent(address _address, bytes _data, bytes32 proposalId);
    event ProcessRemoveVestingMemberProposalEvent(address _address, string _name);//TODO
    event SubmitChallengeDynamicEquityMemberEpochProposalEvent(address _address, bytes _data, bytes32 proposalId);
    event ProcessChallengeDynamicEquityMemberEpochProposalEvent(address _address, string _name);//TODO
    event SubmitUpdateDynamicEquityEpochProposalEvent(address _address, bytes _data, bytes32 proposalId);
    event SubmitUpdateDynamicEquityMemberEpochProposalEvent(address _address, bytes _data, bytes32 proposalId);
    event ProcessUpdateDynamicEquityMemberEpochProposalEvent(address _address, string _name);//TODO
    event DistributeDynamicEquityMemberEpochEvent(address _address, string _name);//TODO
    event DistributeVestingMemberEvent(address _address, string _name);//TODO
    //ENUM
    enum ProposalStatus {
        NOT_STARTED,
        IN_PROGRESS,
        DONE,
        FAILED
    }
    struct DynamicEquityProposal {
        ProposalStatus status;
        Foundance.DynamicEquityConfig configDynamicEquity;
        Foundance.EpochConfig configEpoch;
    }
    struct DynamicEquityMemberProposal {
        ProposalStatus status;
        Foundance.DynamicEquityMemberConfig config;
    }
    struct VestingMemberProposal {
        ProposalStatus status;
        Foundance.VestingMemberConfig config;
    }
    struct UpdateDynamicEquityEpochProposal {
        ProposalStatus status;
        uint256 config;
    }
    struct MemberProposal {
        ProposalStatus status;
        address memberAddress;
    }

    //DYNAMIC_EQUITY
    mapping(address => mapping(bytes32 => DynamicEquityProposal)) public setDynamicEquityProposal;
    mapping(address => mapping(bytes32 => DynamicEquityMemberProposal)) public setDynamicEquityMemberProposal;
    mapping(address => mapping(bytes32 => MemberProposal)) public removeDynamicEquityMemberProposal;
    mapping(address => mapping(bytes32 => MemberProposal)) public challengeDynamicEquityMemberEpochProposal;
    mapping(address => mapping(bytes32 => DynamicEquityMemberProposal)) public updateDynamicEquityMemberEpochProposal;
    mapping(address => mapping(bytes32 => UpdateDynamicEquityEpochProposal)) public updateDynamicEquityEpochProposal;
    mapping(address => bytes32) public ongoingSetDynamicEquity;
    mapping(address => bytes32) public ongoingSetDynamicEquityMember;
    mapping(address => bytes32) public ongoingRemoveDynamicEquityMember;
    mapping(address => bytes32) public ongoingChallengeDynamicEquityMemberEpoch;
    mapping(address => bytes32) public ongoingUpdateDynamicEquityMemberEpoch;
    mapping(address => bytes32) public ongoingUpdateDynamicEquityEpoch;
    //VESTING
    mapping(address => mapping(bytes32 => VestingMemberProposal)) public setVestingMemberProposal;
    mapping(address => mapping(bytes32 => MemberProposal)) public removeVestingMemberProposal;
    mapping(address => bytes32) public ongoingSetVestingMember;
    mapping(address => bytes32) public ongoingRemoveVestingMember;

    //PROPOSAL//SET
    function submitSetDynamicEquityProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        Foundance.DynamicEquityConfig calldata configDynamicEquity,
        Foundance.EpochConfig calldata configEpoch
    ) external override reimbursable(dao) {
        IVoting votingContract = IVoting(
            dao.getAdapterAddress(DaoHelper.VOTING)
        );
        address submittedBy = votingContract.getSenderAddress(
            dao,
            address(this),
            data,
            msg.sender
        );
        dao.submitProposal(proposalId);
        setDynamicEquityProposal[address(dao)][proposalId] = DynamicEquityProposal(
            ProposalStatus.NOT_STARTED,
            configDynamicEquity,
            configEpoch
        );
        votingContract.startNewVotingForProposal(dao, proposalId, data);
        dao.sponsorProposal(proposalId, submittedBy, address(votingContract));
        emit SubmitSetDynamicEquityProposalEvent(address(dao),data,proposalId);
    }
    function submitSetDynamicEquityMemberProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        Foundance.DynamicEquityMemberConfig calldata config
    ) external override reimbursable(dao) {
        IVoting votingContract = IVoting(
            dao.getAdapterAddress(DaoHelper.VOTING)
        );
        address submittedBy = votingContract.getSenderAddress(
            dao,
            address(this),
            data,
            msg.sender
        );
        dao.submitProposal(proposalId);
        setDynamicEquityMemberProposal[address(dao)][proposalId] = DynamicEquityMemberProposal(
            ProposalStatus.NOT_STARTED,
            config
        );
        votingContract.startNewVotingForProposal(dao, proposalId, data);
        dao.sponsorProposal(proposalId, submittedBy, address(votingContract));
        emit SubmitSetDynamicEquityMemberProposalEvent(address(dao),data,proposalId);

    }
    function submitSetVestingMemberProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        Foundance.VestingMemberConfig calldata config
    ) external override reimbursable(dao) {
        IVoting votingContract = IVoting(
            dao.getAdapterAddress(DaoHelper.VOTING)
        );
        address submittedBy = votingContract.getSenderAddress(
            dao,
            address(this),
            data,
            msg.sender
        );
        dao.submitProposal(proposalId);
        setVestingMemberProposal[address(dao)][proposalId] = VestingMemberProposal(
            ProposalStatus.NOT_STARTED,
            config
        );
        votingContract.startNewVotingForProposal(dao, proposalId, data);
        dao.sponsorProposal(proposalId, submittedBy, address(votingContract));
        emit SubmitSetVestingMemberProposalEvent(address(dao),data,proposalId);
    }
    //PROPOSAL//REMOVE
    function submitRemoveDynamicEquityMemberProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        address memberAddress
    ) external override reimbursable(dao) {
        IVoting votingContract = IVoting(
            dao.getAdapterAddress(DaoHelper.VOTING)
        );
        address submittedBy = votingContract.getSenderAddress(
            dao,
            address(this),
            data,
            msg.sender
        );
        dao.submitProposal(proposalId);
        removeDynamicEquityMemberProposal[address(dao)][proposalId] = MemberProposal(
            ProposalStatus.NOT_STARTED,
            memberAddress
        );
        votingContract.startNewVotingForProposal(dao, proposalId, data);
        dao.sponsorProposal(proposalId, submittedBy, address(votingContract));
        emit SubmitRemoveDynamicEquityMemberProposalEvent(address(dao),data,proposalId);

    }
    function submitRemoveVestingMemberProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        address memberAddress
    ) external override reimbursable(dao) {
        IVoting votingContract = IVoting(
            dao.getAdapterAddress(DaoHelper.VOTING)
        );
        address submittedBy = votingContract.getSenderAddress(
            dao,
            address(this),
            data,
            msg.sender
        );
        dao.submitProposal(proposalId);
        removeVestingMemberProposal[address(dao)][proposalId] = MemberProposal(
            ProposalStatus.NOT_STARTED,
            memberAddress
        );
        votingContract.startNewVotingForProposal(dao, proposalId, data);
        dao.sponsorProposal(proposalId, submittedBy, address(votingContract));
        emit SubmitRemoveVestingMemberProposalEvent(address(dao),data,proposalId);
    }
    //PROPOSAL//CHALLENGE
    function submitChallengeDynamicEquityMemberEpochProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        address memberAddress
    ) external override reimbursable(dao) {
        IVoting votingContract = IVoting(
            dao.getAdapterAddress(DaoHelper.VOTING)
        );
        address submittedBy = votingContract.getSenderAddress(
            dao,
            address(this),
            data,
            msg.sender
        );
        dao.submitProposal(proposalId);
        challengeDynamicEquityMemberEpochProposal[address(dao)][proposalId] = MemberProposal(
            ProposalStatus.NOT_STARTED,
            memberAddress
        );
        votingContract.startNewVotingForProposal(dao, proposalId, data);
        dao.sponsorProposal(proposalId, submittedBy, address(votingContract));
        emit SubmitChallengeDynamicEquityMemberEpochProposalEvent(address(dao),data,proposalId);
    }
    //PROPOSAL//UPDATE
    function submitUpdateDynamicEquityMemberEpochProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        Foundance.DynamicEquityMemberConfig calldata config
    ) external override reimbursable(dao) {
        IVoting votingContract = IVoting(
            dao.getAdapterAddress(DaoHelper.VOTING)
        );
        address submittedBy = votingContract.getSenderAddress(
            dao,
            address(this),
            data,
            msg.sender
        );
        dao.submitProposal(proposalId);
        updateDynamicEquityMemberEpochProposal[address(dao)][proposalId] = DynamicEquityMemberProposal(
            ProposalStatus.NOT_STARTED,
            config
        );
        votingContract.startNewVotingForProposal(dao, proposalId, data);
        dao.sponsorProposal(proposalId, submittedBy, address(votingContract));
        emit SubmitUpdateDynamicEquityMemberEpochProposalEvent(address(dao),data,proposalId);
    }
    function submitUpdateDynamicEquityEpochProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        uint256 config
    ) external override reimbursable(dao) {
        IVoting votingContract = IVoting(
            dao.getAdapterAddress(DaoHelper.VOTING)
        );
        address submittedBy = votingContract.getSenderAddress(
            dao,
            address(this),
            data,
            msg.sender
        );
        dao.submitProposal(proposalId);
        updateDynamicEquityEpochProposal[address(dao)][proposalId] = UpdateDynamicEquityEpochProposal(
            ProposalStatus.NOT_STARTED,
            config
        );
        votingContract.startNewVotingForProposal(dao, proposalId, data);
        dao.sponsorProposal(proposalId, submittedBy, address(votingContract));
        emit SubmitUpdateDynamicEquityEpochProposalEvent(address(dao),data,proposalId);
    }
    //PROCESS//SET
    function processSetDynamicEquityProposal(DaoRegistry dao, bytes32 proposalId)
        external
        override
        reimbursable(dao)
    {
        dao.processProposal(proposalId);
        DynamicEquityProposal storage setDynamicEquity = setDynamicEquityProposal[address(dao)][
            proposalId
        ];
        require(
            setDynamicEquity.status == ProposalStatus.NOT_STARTED,
            "dynamicEquityAdpt::proposal already completed or in progress"
        );
        bytes32 ongoingProposalId = ongoingSetDynamicEquity[address(dao)];
        require(
            ongoingProposalId == bytes32(0) ||
                setDynamicEquityProposal[address(dao)][ongoingProposalId].status !=
                ProposalStatus.IN_PROGRESS,
            "dynamicEquityAdpt::another proposal already in progress"
        );
        IVoting votingContract = IVoting(dao.votingAdapter(proposalId));
        require(address(votingContract) != address(0), "dynamicEquityAdpt::adapter not found");
        IVoting.VotingState voteResult = votingContract.voteResult(
            dao,
            proposalId
        );
        if (voteResult == IVoting.VotingState.PASS) {
            setDynamicEquity.status = ProposalStatus.IN_PROGRESS;
            ongoingSetDynamicEquity[address(dao)] = proposalId;
            DynamicEquityExtension dynamicEquity = DynamicEquityExtension(
                dao.getExtensionAddress(DaoHelper.DYNAMIC_EQUITY_EXT)
            );
            dynamicEquity.setDynamicEquity(
                dao,
                setDynamicEquity.configDynamicEquity,
                setDynamicEquity.configEpoch
            );
        } else if (
            voteResult == IVoting.VotingState.NOT_PASS ||
            voteResult == IVoting.VotingState.TIE
        ) {
            setDynamicEquity.status = ProposalStatus.FAILED;
        } else {
            revert("dynamicEquityAdpt::proposal has not been voted on");
        }
    }
    function processSetDynamicEquityMemberProposal(DaoRegistry dao, bytes32 proposalId)
        external
        override
        reimbursable(dao)
    {
        dao.processProposal(proposalId);
        DynamicEquityMemberProposal storage setDynamicEquityMember = setDynamicEquityMemberProposal[address(dao)][
            proposalId
        ];
        require(
            setDynamicEquityMember.status == ProposalStatus.NOT_STARTED,
            "dynamicEquityAdpt::proposal already completed or in progress"
        );
        bytes32 ongoingProposalId = ongoingSetDynamicEquityMember[address(dao)];
        require(
            ongoingProposalId == bytes32(0) ||
                setDynamicEquityMemberProposal[address(dao)][ongoingProposalId].status !=
                ProposalStatus.IN_PROGRESS,
            "dynamicEquityAdpt::another proposal already in progress"
        );
        IVoting votingContract = IVoting(dao.votingAdapter(proposalId));
        require(address(votingContract) != address(0), "dynamicEquityAdpt::adapter not found");
        IVoting.VotingState voteResult = votingContract.voteResult(
            dao,
            proposalId
        );
        if (voteResult == IVoting.VotingState.PASS) {
            setDynamicEquityMember.status = ProposalStatus.IN_PROGRESS;
            ongoingSetDynamicEquityMember[address(dao)] = proposalId;
            DynamicEquityExtension dynamicEquity = DynamicEquityExtension(
                dao.getExtensionAddress(DaoHelper.DYNAMIC_EQUITY_EXT)
            );
            dynamicEquity.setDynamicEquityMember(
                dao,
                setDynamicEquityMember.config
            );
        } else if (
            voteResult == IVoting.VotingState.NOT_PASS ||
            voteResult == IVoting.VotingState.TIE
        ) {
            setDynamicEquityMember.status = ProposalStatus.FAILED;
        } else {
            revert("dynamicEquityAdpt::proposal has not been voted on");
        }
    }
 function processSetVestingMemberProposal(DaoRegistry dao, bytes32 proposalId)
        external
        override
        reimbursable(dao)
    {
        dao.processProposal(proposalId);
        VestingMemberProposal storage setVestingMember = setVestingMemberProposal[address(dao)][
            proposalId
        ];
        require(
            setVestingMember.status == ProposalStatus.NOT_STARTED,
            "dynamicEquityAdpt::proposal already completed or in progress"
        );
        bytes32 ongoingProposalId = ongoingSetVestingMember[address(dao)];
        require(
            ongoingProposalId == bytes32(0) ||
                setVestingMemberProposal[address(dao)][ongoingProposalId].status !=
                ProposalStatus.IN_PROGRESS,
            "dynamicEquityAdpt::another proposal already in progress"
        );
        IVoting votingContract = IVoting(dao.votingAdapter(proposalId));
        require(address(votingContract) != address(0), "dynamicEquityAdpt::adapter not found");
        IVoting.VotingState voteResult = votingContract.voteResult(
            dao,
            proposalId
        );
        if (voteResult == IVoting.VotingState.PASS) {
            setVestingMember.status = ProposalStatus.IN_PROGRESS;
            ongoingSetVestingMember[address(dao)] = proposalId;
            DynamicEquityExtension dynamicEquity = DynamicEquityExtension(
                dao.getExtensionAddress(DaoHelper.DYNAMIC_EQUITY_EXT)
            );
            dynamicEquity.setVestingMember(
                dao,
                setVestingMember.config
            );
        } else if (
            voteResult == IVoting.VotingState.NOT_PASS ||
            voteResult == IVoting.VotingState.TIE
        ) {
            setVestingMember.status = ProposalStatus.FAILED;
        } else {
            revert("dynamicEquityAdpt::proposal has not been voted on");
        }
    }
    //PROCESS//REMOVE
    function processRemoveDynamicEquityMemberProposal(DaoRegistry dao, bytes32 proposalId)
        external
        override
        reimbursable(dao)
    {
        dao.processProposal(proposalId);
        MemberProposal storage removeDynamicEquityMember = removeDynamicEquityMemberProposal[address(dao)][
            proposalId
        ];
        require(
            removeDynamicEquityMember.status == ProposalStatus.NOT_STARTED,
            "dynamicEquityAdpt::proposal already completed or in progress"
        );
        bytes32 ongoingProposalId = ongoingRemoveDynamicEquityMember[address(dao)];
        require(
            ongoingProposalId == bytes32(0) ||
                removeDynamicEquityMemberProposal[address(dao)][ongoingProposalId].status !=
                ProposalStatus.IN_PROGRESS,
            "dynamicEquityAdpt::another proposal already in progress"
        );
        IVoting votingContract = IVoting(dao.votingAdapter(proposalId));
        require(address(votingContract) != address(0), "dynamicEquityAdpt::adapter not found");
        IVoting.VotingState voteResult = votingContract.voteResult(
            dao,
            proposalId
        );
        if (voteResult == IVoting.VotingState.PASS) {
            removeDynamicEquityMember.status = ProposalStatus.IN_PROGRESS;
            ongoingRemoveDynamicEquityMember[address(dao)] = proposalId;
            DynamicEquityExtension dynamicEquity = DynamicEquityExtension(
                dao.getExtensionAddress(DaoHelper.DYNAMIC_EQUITY_EXT)
            );
            dynamicEquity.removeDynamicEquityMember(
                dao,
                removeDynamicEquityMember.memberAddress
            );
        } else if (
            voteResult == IVoting.VotingState.NOT_PASS ||
            voteResult == IVoting.VotingState.TIE
        ) {
            removeDynamicEquityMember.status = ProposalStatus.FAILED;
        } else {
            revert("dynamicEquityAdpt::proposal has not been voted on");
        }
    }
   function processRemoveVestingMemberProposal(DaoRegistry dao, bytes32 proposalId)
        external
        override
        reimbursable(dao)
    {
        dao.processProposal(proposalId);
        MemberProposal storage removeVestingMember = removeVestingMemberProposal[address(dao)][
            proposalId
        ];
        require(
            removeVestingMember.status == ProposalStatus.NOT_STARTED,
            "dynamicEquityAdpt::proposal already completed or in progress"
        );
        bytes32 ongoingProposalId = ongoingRemoveVestingMember[address(dao)];
        require(
            ongoingProposalId == bytes32(0) ||
                removeVestingMemberProposal[address(dao)][ongoingProposalId].status !=
                ProposalStatus.IN_PROGRESS,
            "dynamicEquityAdpt::another proposal already in progress"
        );
        IVoting votingContract = IVoting(dao.votingAdapter(proposalId));
        require(address(votingContract) != address(0), "dynamicEquityAdpt::adapter not found");
        IVoting.VotingState voteResult = votingContract.voteResult(
            dao,
            proposalId
        );
        if (voteResult == IVoting.VotingState.PASS) {
            removeVestingMember.status = ProposalStatus.IN_PROGRESS;
            ongoingRemoveVestingMember[address(dao)] = proposalId;
            DynamicEquityExtension dynamicEquity = DynamicEquityExtension(
                dao.getExtensionAddress(DaoHelper.DYNAMIC_EQUITY_EXT)
            );
            dynamicEquity.removeVestingMember(
                dao,
                removeVestingMember.memberAddress
            );
        } else if (
            voteResult == IVoting.VotingState.NOT_PASS ||
            voteResult == IVoting.VotingState.TIE
        ) {
            removeVestingMember.status = ProposalStatus.FAILED;
        } else {
            revert("dynamicEquityAdpt::proposal has not been voted on");
        }
    }
    //PROCESS//CHALLENGE
    function processChallengeDynamicEquityMemberEpochProposal(DaoRegistry dao, bytes32 proposalId)
        external
        override
        reimbursable(dao)
    {
        dao.processProposal(proposalId);
        MemberProposal storage challengeDynamicEquityMemberEpoch = challengeDynamicEquityMemberEpochProposal[address(dao)][
            proposalId
        ];
        require(
            challengeDynamicEquityMemberEpoch.status == ProposalStatus.NOT_STARTED,
            "dynamicEquityAdpt::proposal already completed or in progress"
        );
        bytes32 ongoingProposalId = ongoingChallengeDynamicEquityMemberEpoch[address(dao)];
        require(
            ongoingProposalId == bytes32(0) ||
                challengeDynamicEquityMemberEpochProposal[address(dao)][ongoingProposalId].status !=
                ProposalStatus.IN_PROGRESS,
            "dynamicEquityAdpt::another proposal already in progress"
        );
        IVoting votingContract = IVoting(dao.votingAdapter(proposalId));
        require(address(votingContract) != address(0), "dynamicEquityAdpt::adapter not found");
        IVoting.VotingState voteResult = votingContract.voteResult(
            dao,
            proposalId
        );
        if (voteResult == IVoting.VotingState.PASS) {
            challengeDynamicEquityMemberEpoch.status = ProposalStatus.IN_PROGRESS;
            ongoingChallengeDynamicEquityMemberEpoch[address(dao)] = proposalId;
            DynamicEquityExtension dynamicEquity = DynamicEquityExtension(
                dao.getExtensionAddress(DaoHelper.DYNAMIC_EQUITY_EXT)
            );
            dynamicEquity.challengeDynamicEquityMemberEpoch(
                dao,
                challengeDynamicEquityMemberEpoch.memberAddress
            );
        } else if (
            voteResult == IVoting.VotingState.NOT_PASS ||
            voteResult == IVoting.VotingState.TIE
        ) {
            challengeDynamicEquityMemberEpoch.status = ProposalStatus.FAILED;
        } else {
            revert("dynamicEquityAdpt::proposal has not been voted on");
        }
    }
    //PROCESS//UPDATE
    function processUpdateDynamicEquityMemberEpochProposal(DaoRegistry dao, bytes32 proposalId)
        external
        override
        reimbursable(dao)
    {
        dao.processProposal(proposalId);
        DynamicEquityMemberProposal storage updateDynamicEquityMemberEpoch = updateDynamicEquityMemberEpochProposal[address(dao)][
            proposalId
        ];
        require(
            updateDynamicEquityMemberEpoch.status == ProposalStatus.NOT_STARTED,
            "dynamicEquityAdpt::proposal already completed or in progress"
        );
        bytes32 ongoingProposalId = ongoingUpdateDynamicEquityMemberEpoch[address(dao)];
        require(
            ongoingProposalId == bytes32(0) ||
                updateDynamicEquityMemberEpochProposal[address(dao)][ongoingProposalId].status !=
                ProposalStatus.IN_PROGRESS,
            "dynamicEquityAdpt::another proposal already in progress"
        );
        IVoting votingContract = IVoting(dao.votingAdapter(proposalId));
        require(address(votingContract) != address(0), "dynamicEquityAdpt::adapter not found");
        IVoting.VotingState voteResult = votingContract.voteResult(
            dao,
            proposalId
        );
        if (voteResult == IVoting.VotingState.PASS) {
            updateDynamicEquityMemberEpoch.status = ProposalStatus.IN_PROGRESS;
            ongoingUpdateDynamicEquityMemberEpoch[address(dao)] = proposalId;
            DynamicEquityExtension dynamicEquity = DynamicEquityExtension(
                dao.getExtensionAddress(DaoHelper.DYNAMIC_EQUITY_EXT)
            );
            dynamicEquity.updateDynamicEquityMemberEpoch(
                dao,
                updateDynamicEquityMemberEpoch.config
            );
        } else if (
            voteResult == IVoting.VotingState.NOT_PASS ||
            voteResult == IVoting.VotingState.TIE
        ) {
            updateDynamicEquityMemberEpoch.status = ProposalStatus.FAILED;
        } else {
            revert("dynamicEquityAdpt::proposal has not been voted on");
        }
    }
    function processUpdateDynamicEquityEpochProposal(DaoRegistry dao, bytes32 proposalId)
        external
        override
        reimbursable(dao)
    {
        dao.processProposal(proposalId);
        UpdateDynamicEquityEpochProposal storage updateDynamicEquityEpoch = updateDynamicEquityEpochProposal[address(dao)][
            proposalId
        ];
        require(
            updateDynamicEquityEpoch.status == ProposalStatus.NOT_STARTED,
            "dynamicEquityAdpt::proposal already completed or in progress"
        );
        bytes32 ongoingProposalId = ongoingUpdateDynamicEquityEpoch[address(dao)];
        require(
            ongoingProposalId == bytes32(0) ||
                updateDynamicEquityEpochProposal[address(dao)][ongoingProposalId].status !=
                ProposalStatus.IN_PROGRESS,
            "dynamicEquityAdpt::another proposal already in progress"
        );
        IVoting votingContract = IVoting(dao.votingAdapter(proposalId));
        require(address(votingContract) != address(0), "dynamicEquityAdpt::adapter not found");
        IVoting.VotingState voteResult = votingContract.voteResult(
            dao,
            proposalId
        );
        if (voteResult == IVoting.VotingState.PASS) {
            updateDynamicEquityEpoch.status = ProposalStatus.IN_PROGRESS;
            ongoingUpdateDynamicEquityEpoch[address(dao)] = proposalId;
            DynamicEquityExtension dynamicEquity = DynamicEquityExtension(
                dao.getExtensionAddress(DaoHelper.DYNAMIC_EQUITY_EXT)
            );
            dynamicEquity.updateDynamicEquityEpoch(
                dao,
                updateDynamicEquityEpoch.config
            );
        } else if (
            voteResult == IVoting.VotingState.NOT_PASS ||
            voteResult == IVoting.VotingState.TIE
        ) {
            updateDynamicEquityEpoch.status = ProposalStatus.FAILED;
        } else {
            revert("dynamicEquityAdpt::proposal has not been voted on");
        }
    }
    //DISTRIBUTE
    function distributeDynamicEquityMemberEpoch(DaoRegistry dao)
        external
        override
        reimbursable(dao)
    {
        BankExtension bank = BankExtension(
            dao.getExtensionAddress(DaoHelper.BANK)
        );
        DynamicEquityExtension dynamicEquity = DynamicEquityExtension(
            dao.getExtensionAddress(DaoHelper.DYNAMIC_EQUITY_EXT)
        );
        uint256 blockTimestamp = block.timestamp;
        uint256 nbMembers = dao.getNbMembers();
        Foundance.EpochConfig memory epochConfig = dynamicEquity.getEpochConfig();
        Foundance.DynamicEquityConfig memory dynamicEquityConfig = dynamicEquity.getDynamicEquityConfig();
        while(epochConfig.epochLast+epochConfig.epochDuration<blockTimestamp){
            for (uint256 i = 0; i < nbMembers; i++) {
                address memberAddress = dao.getMemberAddress(i);
                uint amount = dynamicEquity.getDynamicEquityEpochAmount(memberAddress);
                address token = DaoHelper.UNITS;
                require(bank.isTokenAllowed(token), "token not allowed");
                if(amount>0){
                bank.addToBalance(
                    dao,
                    memberAddress,
                    token,
                    amount
                );
                }
            }
            dynamicEquity.updateDynamicEquityEpoch(dao, epochConfig.epochDuration+epochConfig.epochLast);
        }
    }
    function distributeVestingMember(DaoRegistry dao, address memberAddress)
        external
        override
        reimbursable(dao)
    {
        BankExtension bank = BankExtension(
            dao.getExtensionAddress(DaoHelper.BANK)
        );
        DynamicEquityExtension dynamicEquity = DynamicEquityExtension(
            dao.getExtensionAddress(DaoHelper.DYNAMIC_EQUITY_EXT)
        );
        if (memberAddress != address(0x0)) {
                Foundance.VestingMemberConfig memory vestingMemberConfig = dynamicEquity.getVestingMemberEpoch(memberAddress);
                address token = DaoHelper.UNITS;
                require(bank.isTokenAllowed(token), "token not allowed");
                uint amount = vestingMemberConfig.amount;
                dynamicEquity.removeVestingMemberAmount(dao, memberAddress);       
                uint newAmount = dynamicEquity.getVestingMemberAmount(memberAddress);
                uint toBeDistributed = newAmount-amount;
                if(toBeDistributed>0){
                    bank.addToBalance(
                        dao,
                        memberAddress,
                        token,
                        toBeDistributed
                    );
                }
        }else{
                _distributeVestingMember(dao);          
        }
    }
    function _distributeVestingMember(DaoRegistry dao)
        public
    {
        BankExtension bank = BankExtension(
            dao.getExtensionAddress(DaoHelper.BANK)
        );
        DynamicEquityExtension dynamicEquity = DynamicEquityExtension(
            dao.getExtensionAddress(DaoHelper.DYNAMIC_EQUITY_EXT)
        );
        uint256 nbMembers = dao.getNbMembers();
        for (uint256 i = 0; i < nbMembers; i++) {
            address _memberAddress = dao.getMemberAddress(i);
            Foundance.VestingMemberConfig memory vestingMemberConfig = dynamicEquity.getVestingMemberEpoch(_memberAddress); 
            address token = DaoHelper.UNITS;
            require(bank.isTokenAllowed(token), "token not allowed");
            uint amount = vestingMemberConfig.amount;
            dynamicEquity.removeVestingMemberAmount(dao, _memberAddress);       
            uint newAmount = dynamicEquity.getVestingMemberAmount(_memberAddress);
            uint toBeDistributed = newAmount-amount;
            if(toBeDistributed>0){
                bank.addToBalance(
                    dao,
                    _memberAddress,
                    token,
                    toBeDistributed
                );
            }        
        }
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
import {Foundance} from "../../libraries/Foundance.sol";
import "../../core/DaoRegistry.sol";
import "../../guards/AdapterGuard.sol";
import "./../modifiers/Reimbursable.sol";
import "../../adapters/interfaces/IVoting.sol";
import "../../adapters/interfaces/ICommunityIncentive.sol";
import "../../helpers/FairShareHelper.sol";
import "../../helpers/DaoHelper.sol";
import "../../extensions/bank/Bank.sol";
import "../../extensions/foundance/CommunityIncentiveExtension.sol";

contract CommunityIncentiveAdapter is ICommunityIncentive, AdapterGuard, Reimbursable {
    //EVENT
    //ENUM
    enum ProposalStatus {
        NOT_STARTED,
        IN_PROGRESS,
        DONE,
        FAILED
    }
}

pragma solidity ^0.8.0;
import "../extensions/bank/Bank.sol";
import "../core/DaoRegistry.sol";

// SPDX-License-Identifier: MIT

/**
MIT License

Copyright (c) 2021 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */
library DaoHelper {
    // Adapters
    bytes32 internal constant DYNAMIC_EQUITY_ADAPT = keccak256("dynamic-equity-adpt");
    bytes32 internal constant COMMUNITY_INCENTIVE_ADAPT = keccak256("community-incentive-adpt");
    bytes32 internal constant VOTING = keccak256("voting");
    bytes32 internal constant ONBOARDING = keccak256("onboarding");
    bytes32 internal constant NONVOTING_ONBOARDING =
        keccak256("nonvoting-onboarding");
    bytes32 internal constant TRIBUTE = keccak256("tribute");
    bytes32 internal constant FINANCING = keccak256("financing");
    bytes32 internal constant MANAGING = keccak256("managing");
    bytes32 internal constant RAGEQUIT = keccak256("ragequit");
    bytes32 internal constant GUILDKICK = keccak256("guildkick");
    bytes32 internal constant CONFIGURATION = keccak256("configuration");
    bytes32 internal constant DISTRIBUTE = keccak256("distribute");

    bytes32 internal constant TRIBUTE_NFT = keccak256("tribute-nft");
    bytes32 internal constant REIMBURSEMENT = keccak256("reimbursement");
    bytes32 internal constant TRANSFER_STRATEGY =
        keccak256("erc20-transfer-strategy");
    bytes32 internal constant DAO_REGISTRY_ADAPT = keccak256("daoRegistry");
    bytes32 internal constant BANK_ADAPT = keccak256("bank");
    bytes32 internal constant ERC721_ADAPT = keccak256("nft");
    bytes32 internal constant ERC1155_ADAPT = keccak256("erc1155-adpt");
    bytes32 internal constant ERC1271_ADAPT = keccak256("signatures");
    bytes32 internal constant SNAPSHOT_PROPOSAL_ADPT =
        keccak256("snapshot-proposal-adpt");
    bytes32 internal constant VOTING_HASH_ADPT = keccak256("voting-hash-adpt");
    bytes32 internal constant KICK_BAD_REPORTER_ADPT =
        keccak256("kick-bad-reporter-adpt");
    bytes32 internal constant COUPON_ONBOARDING_ADPT =
        keccak256("coupon-onboarding");
    bytes32 internal constant LEND_NFT_ADPT = keccak256("lend-nft");
    bytes32 internal constant ERC20_TRANSFER_STRATEGY_ADPT =
        keccak256("erc20-transfer-strategy");

    // Extensions
    bytes32 internal constant BANK = keccak256("bank");
    bytes32 internal constant ERC1271 = keccak256("erc1271");
    bytes32 internal constant NFT = keccak256("nft");
    bytes32 internal constant EXECUTOR_EXT = keccak256("executor-ext");
    bytes32 internal constant INTERNAL_TOKEN_VESTING_EXT = keccak256("internal-token-vesting-ext");
    bytes32 internal constant DYNAMIC_EQUITY_EXT = keccak256("dynamic-equity-ext");
    bytes32 internal constant COMMUNITY_INCENTIVE_EXT = keccak256("community-incentive-ext");
    bytes32 internal constant ERC1155_EXT = keccak256("erc1155-ext");
    bytes32 internal constant ERC20_EXT = keccak256("erc20-ext");

    // Reserved Addresses
    address internal constant GUILD = address(0xdead);
    address internal constant ESCROW = address(0x4bec);
    address internal constant TOTAL = address(0xbabe);
    address internal constant UNITS = address(0xFF1CE);
    address internal constant LOOT = address(0xB105F00D);
    address internal constant ETH_TOKEN = address(0x0);
    address internal constant MEMBER_COUNT = address(0xDECAFBAD);

    uint8 internal constant MAX_TOKENS_GUILD_BANK = 200;


    function totalTokens(BankExtension bank) internal view returns (uint256) {
        return memberTokens(bank, TOTAL) - memberTokens(bank, GUILD); //GUILD is accounted for twice otherwise
    }

    /**
     * @notice calculates the total number of units.
     */
    function priorTotalTokens(BankExtension bank, uint256 at)
        internal
        view
        returns (uint256)
    {
        return
            priorMemberTokens(bank, TOTAL, at) -
            priorMemberTokens(bank, GUILD, at);
    }

    function memberTokens(BankExtension bank, address member)
        internal
        view
        returns (uint256)
    {
        return bank.balanceOf(member, UNITS) + bank.balanceOf(member, LOOT);
    }

    function msgSender(DaoRegistry dao, address addr)
        internal
        view
        returns (address)
    {
        address memberAddress = dao.getAddressIfDelegated(addr);
        address delegatedAddress = dao.getCurrentDelegateKey(addr);

        require(
            memberAddress == delegatedAddress || delegatedAddress == addr,
            "call with your delegate key"
        );

        return memberAddress;
    }

    /**
     * @notice calculates the total number of units.
     */
    function priorMemberTokens(
        BankExtension bank,
        address member,
        uint256 at
    ) internal view returns (uint256) {
        return
            bank.getPriorAmount(member, UNITS, at) +
            bank.getPriorAmount(member, LOOT, at);
    }

    //helper
    function getFlag(uint256 flags, uint256 flag) internal pure returns (bool) {
        return (flags >> uint8(flag)) % 2 == 1;
    }

    function setFlag(
        uint256 flags,
        uint256 flag,
        bool value
    ) internal pure returns (uint256) {
        if (getFlag(flags, flag) != value) {
            if (value) {
                return flags + 2**flag;
            } else {
                return flags - 2**flag;
            }
        } else {
            return flags;
        }
    }

    /**
     * @notice Checks if a given address is reserved.
     */
    function isNotReservedAddress(address addr) internal pure returns (bool) {
        return addr != GUILD && addr != TOTAL && addr != ESCROW;
    }

    /**
     * @notice Checks if a given address is zeroed.
     */
    function isNotZeroAddress(address addr) internal pure returns (bool) {
        return addr != address(0x0);
    }

    function potentialNewMember(
        address memberAddress,
        DaoRegistry dao,
        BankExtension bank
    ) internal {
        dao.potentialNewMember(memberAddress);
        require(memberAddress != address(0x0), "invalid member address");
        if (address(bank) != address(0x0)) {
            if (bank.balanceOf(memberAddress, MEMBER_COUNT) == 0) {
                bank.addToBalance(dao, memberAddress, MEMBER_COUNT, 1);
            }
        }
    }

    /**
     * A DAO is in creation mode is the state of the DAO is equals to CREATION and
     * 1. The number of members in the DAO is ZERO or,
     * 2. The sender of the tx is a DAO member (usually the DAO owner) or,
     * 3. The sender is an adapter.
     */
    // slither-disable-next-line calls-loop
    function isInCreationModeAndHasAccess(DaoRegistry dao)
        internal
        view
        returns (bool)
    {
        return
            dao.state() == DaoRegistry.DaoState.CREATION &&
            (dao.getNbMembers() == 0 ||
                dao.isMember(msg.sender) ||
                dao.isAdapter(msg.sender));
    }
}

pragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

/*
The MIT License (MIT)
Copyright (c) 2018 Murray Software, LLC.
Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:
The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
//solhint-disable max-line-length
//solhint-disable no-inline-assembly

contract CloneFactory {
    function _createClone(address target)
        internal
        returns (address payable result)
    {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            result := create(0, clone, 0x37)
        }
        require(result != address(0), "create failed");
    }

    function _isClone(address target, address query)
        internal
        view
        returns (bool result)
    {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x363d3d373d3d3d363d7300000000000000000000000000000000000000000000
            )
            mstore(add(clone, 0xa), targetBytes)
            mstore(
                add(clone, 0x1e),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )

            let other := add(clone, 0x40)
            extcodecopy(query, other, 0, 0x2d)
            result := and(
                eq(mload(clone), mload(other)),
                eq(mload(add(clone, 0xd)), mload(add(other, 0xd)))
            )
        }
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../core/DaoRegistry.sol";
import "../helpers/DaoHelper.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */
abstract contract AdapterGuard {
    /**
     * @dev Only registered adapters are allowed to execute the function call.
     */
    modifier onlyAdapter(DaoRegistry dao) {
        require(
            dao.isAdapter(msg.sender) ||
                DaoHelper.isInCreationModeAndHasAccess(dao),
            "onlyAdapter"
        );
        _;
    }

    modifier reentrancyGuard(DaoRegistry dao) {
        require(dao.lockedAt() != block.number, "reentrancy guard");
        dao.lockSession();
        _;
        dao.unlockSession();
    }

    modifier executorFunc(DaoRegistry dao) {
        address executorAddr = dao.getExtensionAddress(
            keccak256("executor-ext")
        );
        require(address(this) == executorAddr, "only callable by the executor");
        _;
    }

    modifier hasAccess(DaoRegistry dao, DaoRegistry.AclFlag flag) {
        require(
            DaoHelper.isInCreationModeAndHasAccess(dao) ||
                dao.hasAdapterAccess(msg.sender, flag),
            "accessDenied"
        );
        _;
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../core/DaoRegistry.sol";
import "../extensions/bank/Bank.sol";
import "../helpers/DaoHelper.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */
abstract contract MemberGuard {
    /**
     * @dev Only members of the DAO are allowed to execute the function call.
     */
    modifier onlyMember(DaoRegistry dao) {
        _onlyMember(dao, msg.sender);
        _;
    }

    modifier onlyMember2(DaoRegistry dao, address _addr) {
        _onlyMember(dao, _addr);
        _;
    }

    function _onlyMember(DaoRegistry dao, address _addr) internal view {
        require(isActiveMember(dao, _addr), "onlyMember");
    }

    function isActiveMember(DaoRegistry dao, address _addr)
        public
        view
        returns (bool)
    {
        address bankAddress = dao.extensions(DaoHelper.BANK);
        if (bankAddress != address(0x0)) {
            address memberAddr = DaoHelper.msgSender(dao, _addr);
            return
                dao.isMember(_addr) &&
                BankExtension(bankAddress).balanceOf(
                    memberAddr,
                    DaoHelper.UNITS
                ) >
                0;
        }

        return dao.isMember(_addr);
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
import '../../core/DaoRegistry.sol';
import '../IExtension.sol';
import '../../guards/AdapterGuard.sol';
import '../../helpers/DaoHelper.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

contract BankExtension is IExtension, ERC165 {
    using Address for address payable;
    using SafeERC20 for IERC20;

    uint8 public maxExternalTokens; // the maximum number of external tokens that can be stored in the bank

    bool public initialized = false; // internally tracks deployment under eip-1167 proxy pattern
    DaoRegistry public dao;

    enum AclFlag {
        ADD_TO_BALANCE,
        SUB_FROM_BALANCE,
        INTERNAL_TRANSFER,
        WITHDRAW,
        REGISTER_NEW_TOKEN,
        REGISTER_NEW_INTERNAL_TOKEN,
        UPDATE_TOKEN
    }

    modifier noProposal() {
        require(dao.lockedAt() < block.number, 'proposal lock');
        _;
    }

    /// @dev - Events for Bank
    event NewBalance(address member, address tokenAddr, uint160 amount);

    event Withdraw(address account, address tokenAddr, uint160 amount);

    event WithdrawTo(
        address accountFrom,
        address accountTo,
        address tokenAddr,
        uint160 amount
    );

    /*
     * STRUCTURES
     */

    struct Checkpoint {
        // A checkpoint for marking number of votes from a given block
        uint96 fromBlock;
        uint160 amount;
    }

    address[] public tokens;
    address[] public internalTokens;
    // tokenAddress => availability
    mapping(address => bool) public availableTokens;
    mapping(address => bool) public availableInternalTokens;
    // tokenAddress => memberAddress => checkpointNum => Checkpoint
    mapping(address => mapping(address => mapping(uint32 => Checkpoint)))
        public checkpoints;
    // tokenAddress => memberAddress => numCheckpoints
    mapping(address => mapping(address => uint32)) public numCheckpoints;

    /// @notice Clonable contract must have an empty constructor
    constructor() {}

    // slither-disable-next-line calls-loop
    modifier hasExtensionAccess(DaoRegistry _dao, AclFlag flag) {
        require(
            dao == _dao &&
                (address(this) == msg.sender ||
                    address(dao) == msg.sender ||
                    !initialized ||
                    DaoHelper.isInCreationModeAndHasAccess(dao) ||
                    dao.hasAdapterAccessToExtension(
                        msg.sender,
                        address(this),
                        uint8(flag)
                    )),
            'bank::accessDenied'
        );
        _;
    }

    /**
     * @notice Initialises the DAO
     * @dev Involves initialising available tokens, checkpoints, and membership of creator
     * @dev Can only be called once
     * @param creator The DAO's creator, who will be an initial member
     */
    function initialize(DaoRegistry _dao, address creator) external override {
        require(!initialized, 'already initialized');
        require(_dao.isMember(creator), 'not a member');
        dao = _dao;

        availableInternalTokens[DaoHelper.UNITS] = true;
        internalTokens.push(DaoHelper.UNITS);

        availableInternalTokens[DaoHelper.MEMBER_COUNT] = true;
        internalTokens.push(DaoHelper.MEMBER_COUNT);
        uint256 nbMembers = _dao.getNbMembers();
        for (uint256 i = 0; i < nbMembers; i++) {
            //slither-disable-next-line calls-loop
            addToBalance(
                _dao,
                _dao.getMemberAddress(i),
                DaoHelper.MEMBER_COUNT,
                1
            );
        }

        _createNewAmountCheckpoint(creator, DaoHelper.UNITS, 1);
        _createNewAmountCheckpoint(DaoHelper.TOTAL, DaoHelper.UNITS, 1);
        initialized = true;
    }

    function withdraw(
        DaoRegistry _dao,
        address payable member,
        address tokenAddr,
        uint256 amount
    ) external hasExtensionAccess(_dao, AclFlag.WITHDRAW) {
        require(
            balanceOf(member, tokenAddr) >= amount,
            'bank::withdraw::not enough funds'
        );
        subtractFromBalance(_dao, member, tokenAddr, amount);
        if (tokenAddr == DaoHelper.ETH_TOKEN) {
            member.sendValue(amount);
        } else {
            IERC20(tokenAddr).safeTransfer(member, amount);
        }

        //slither-disable-next-line reentrancy-events
        emit Withdraw(member, tokenAddr, uint160(amount));
    }

    function withdrawTo(
        DaoRegistry _dao,
        address memberFrom,
        address payable memberTo,
        address tokenAddr,
        uint256 amount
    ) external hasExtensionAccess(_dao, AclFlag.WITHDRAW) {
        require(
            balanceOf(memberFrom, tokenAddr) >= amount,
            'bank::withdraw::not enough funds'
        );
        subtractFromBalance(_dao, memberFrom, tokenAddr, amount);
        if (tokenAddr == DaoHelper.ETH_TOKEN) {
            memberTo.sendValue(amount);
        } else {
            IERC20(tokenAddr).safeTransfer(memberTo, amount);
        }

        //slither-disable-next-line reentrancy-events
        emit WithdrawTo(memberFrom, memberTo, tokenAddr, uint160(amount));
    }

    /**
     * @return Whether or not the given token is an available internal token in the bank
     * @param token The address of the token to look up
     */
    function isInternalToken(address token) external view returns (bool) {
        return availableInternalTokens[token];
    }

    /**
     * @return Whether or not the given token is an available token in the bank
     * @param token The address of the token to look up
     */
    function isTokenAllowed(address token) public view returns (bool) {
        return availableTokens[token];
    }

    /**
     * @notice Sets the maximum amount of external tokens allowed in the bank
     * @param maxTokens The maximum amount of token allowed
     */
    function setMaxExternalTokens(uint8 maxTokens) external {
        require(!initialized, 'already initialized');
        require(
            maxTokens > 0 && maxTokens <= DaoHelper.MAX_TOKENS_GUILD_BANK,
            'maxTokens should be (0,200]'
        );
        maxExternalTokens = maxTokens;
    }

    /*
     * BANK
     */

    /**
     * @notice Registers a potential new token in the bank
     * @dev Cannot be a reserved token or an available internal token
     * @param token The address of the token
     */
    function registerPotentialNewToken(DaoRegistry _dao, address token)
        external
        hasExtensionAccess(_dao, AclFlag.REGISTER_NEW_TOKEN)
    {
        require(DaoHelper.isNotReservedAddress(token), 'reservedToken');
        require(!availableInternalTokens[token], 'internalToken');
        require(
            tokens.length <= maxExternalTokens,
            'exceeds the maximum tokens allowed'
        );

        if (!availableTokens[token]) {
            availableTokens[token] = true;
            tokens.push(token);
        }
    }

    /**
     * @notice Registers a potential new internal token in the bank
     * @dev Can not be a reserved token or an available token
     * @param token The address of the token
     */
    function registerPotentialNewInternalToken(DaoRegistry _dao, address token)
        external
        hasExtensionAccess(_dao, AclFlag.REGISTER_NEW_INTERNAL_TOKEN)
    {
        require(DaoHelper.isNotReservedAddress(token), 'reservedToken');
        require(!availableTokens[token], 'availableToken');

        if (!availableInternalTokens[token]) {
            availableInternalTokens[token] = true;
            internalTokens.push(token);
        }
    }

    function updateToken(DaoRegistry _dao, address tokenAddr)
        external
        hasExtensionAccess(_dao, AclFlag.UPDATE_TOKEN)
    {
        require(isTokenAllowed(tokenAddr), 'token not allowed');
        uint256 totalBalance = balanceOf(DaoHelper.TOTAL, tokenAddr);

        uint256 realBalance;

        if (tokenAddr == DaoHelper.ETH_TOKEN) {
            realBalance = address(this).balance;
        } else {
            IERC20 erc20 = IERC20(tokenAddr);
            realBalance = erc20.balanceOf(address(this));
        }

        if (totalBalance < realBalance) {
            addToBalance(
                _dao,
                DaoHelper.GUILD,
                tokenAddr,
                realBalance - totalBalance
            );
        } else if (totalBalance > realBalance) {
            uint256 tokensToRemove = totalBalance - realBalance;
            uint256 guildBalance = balanceOf(DaoHelper.GUILD, tokenAddr);
            if (guildBalance > tokensToRemove) {
                subtractFromBalance(
                    _dao,
                    DaoHelper.GUILD,
                    tokenAddr,
                    tokensToRemove
                );
            } else {
                subtractFromBalance(
                    _dao,
                    DaoHelper.GUILD,
                    tokenAddr,
                    guildBalance
                );
            }
        }
    }

    /**
     * Public read-only functions
     */

    /**
     * Internal bookkeeping
     */

    /**
     * @return The token from the bank of a given index
     * @param index The index to look up in the bank's tokens
     */
    function getToken(uint256 index) external view returns (address) {
        return tokens[index];
    }

    /**
     * @return The amount of token addresses in the bank
     */
    function nbTokens() external view returns (uint256) {
        return tokens.length;
    }

    /**
     * @return All the tokens registered in the bank.
     */
    function getTokens() external view returns (address[] memory) {
        return tokens;
    }

    /**
     * @return The internal token at a given index
     * @param index The index to look up in the bank's array of internal tokens
     */
    function getInternalToken(uint256 index) external view returns (address) {
        return internalTokens[index];
    }

    /**
     * @return The amount of internal token addresses in the bank
     */
    function nbInternalTokens() external view returns (uint256) {
        return internalTokens.length;
    }

    function addToBalance(
        address,
        address,
        uint256
    ) external payable {
        revert('not implemented');
    }

    /**
     * @notice Adds to a member's balance of a given token
     * @param member The member whose balance will be updated
     * @param token The token to update
     * @param amount The new balance
     */
    function addToBalance(
        DaoRegistry _dao,
        address member,
        address token,
        uint256 amount
    ) public payable hasExtensionAccess(_dao, AclFlag.ADD_TO_BALANCE) {
        require(
            availableTokens[token] || availableInternalTokens[token],
            'unknown token address'
        );
        uint256 newAmount = balanceOf(member, token) + amount;
        uint256 newTotalAmount = balanceOf(DaoHelper.TOTAL, token) + amount;

        _createNewAmountCheckpoint(member, token, newAmount);
        _createNewAmountCheckpoint(DaoHelper.TOTAL, token, newTotalAmount);
    }

    /**
     * @notice Remove from a member's balance of a given token
     * @param member The member whose balance will be updated
     * @param token The token to update
     * @param amount The new balance
     */
    function subtractFromBalance(
        DaoRegistry _dao,
        address member,
        address token,
        uint256 amount
    ) public hasExtensionAccess(_dao, AclFlag.SUB_FROM_BALANCE) {
        uint256 newAmount = balanceOf(member, token) - amount;
        uint256 newTotalAmount = balanceOf(DaoHelper.TOTAL, token) - amount;

        _createNewAmountCheckpoint(member, token, newAmount);
        _createNewAmountCheckpoint(DaoHelper.TOTAL, token, newTotalAmount);
    }

    function subtractFromBalance(
        address,
        address,
        uint256
    ) external pure {
        revert('not implemented');
    }

    function internalTransfer(
        address,
        address,
        address,
        uint256
    ) external pure {
        revert('not implemented');
    }

    /**
     * @notice Make an internal token transfer
     * @param from The member who is sending tokens
     * @param to The member who is receiving tokens
     * @param amount The new amount to transfer
     */
    function internalTransfer(
        DaoRegistry _dao,
        address from,
        address to,
        address token,
        uint256 amount
    ) external hasExtensionAccess(_dao, AclFlag.INTERNAL_TRANSFER) {
        require(dao.notJailed(from), 'no transfer from jail');
        require(dao.notJailed(to), 'no transfer from jail');
        uint256 newAmount = balanceOf(from, token) - amount;
        uint256 newAmount2 = balanceOf(to, token) + amount;

        _createNewAmountCheckpoint(from, token, newAmount);
        _createNewAmountCheckpoint(to, token, newAmount2);
    }

    /**
     * @notice Returns an member's balance of a given token
     * @param member The address to look up
     * @param tokenAddr The token where the member's balance of which will be returned
     * @return The amount in account's tokenAddr balance
     */
    function balanceOf(address member, address tokenAddr)
        public
        view
        returns (uint160)
    {
        uint32 nCheckpoints = numCheckpoints[tokenAddr][member];
        return
            nCheckpoints > 0
                ? checkpoints[tokenAddr][member][nCheckpoints - 1].amount
                : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorAmount(
        address account,
        address tokenAddr,
        uint256 blockNumber
    ) external view returns (uint256) {
        require(
            blockNumber < block.number,
            'bank::getPriorAmount: not yet determined'
        );

        uint32 nCheckpoints = numCheckpoints[tokenAddr][account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (
            checkpoints[tokenAddr][account][nCheckpoints - 1].fromBlock <=
            blockNumber
        ) {
            return checkpoints[tokenAddr][account][nCheckpoints - 1].amount;
        }

        // Next check implicit zero balance
        if (checkpoints[tokenAddr][account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[tokenAddr][account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.amount;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[tokenAddr][account][lower].amount;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            super.supportsInterface(interfaceId) ||
            this.withdrawTo.selector == interfaceId;
    }

    /**
     * @notice Creates a new amount checkpoint for a token of a certain member
     * @dev Reverts if the amount is greater than 2**64-1
     * @param member The member whose checkpoints will be added to
     * @param token The token of which the balance will be changed
     * @param amount The amount to be written into the new checkpoint
     */
    function _createNewAmountCheckpoint(
        address member,
        address token,
        uint256 amount
    ) internal {
        bool isValidToken = false;
        if (availableInternalTokens[token]) {
            require(
                amount < type(uint88).max,
                'token amount exceeds the maximum limit for internal tokens'
            );
            isValidToken = true;
        } else if (availableTokens[token]) {
            require(
                amount < type(uint160).max,
                'token amount exceeds the maximum limit for external tokens'
            );
            isValidToken = true;
        }
        uint160 newAmount = uint160(amount);

        require(isValidToken, 'token not registered');

        uint32 nCheckpoints = numCheckpoints[token][member];
        if (
            // The only condition that we should allow the amount update
            // is when the block.number exactly matches the fromBlock value.
            // Anything different from that should generate a new checkpoint.
            //slither-disable-next-line incorrect-equality
            nCheckpoints > 0 &&
            checkpoints[token][member][nCheckpoints - 1].fromBlock ==
            block.number
        ) {
            checkpoints[token][member][nCheckpoints - 1].amount = newAmount;
        } else {
            checkpoints[token][member][nCheckpoints] = Checkpoint(
                uint96(block.number),
                newAmount
            );
            numCheckpoints[token][member] = nCheckpoints + 1;
        }
        //slither-disable-next-line reentrancy-events
        emit NewBalance(member, token, newAmount);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
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

pragma solidity ^0.8.0;

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
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

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
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
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
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
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

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
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

pragma solidity ^0.8.0;
import "../core/DaoRegistry.sol";

// SPDX-License-Identifier: MIT

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

interface IFactory {
    /**
     * @notice Do not rely on the result returned by this right after the new extension is cloned,
     * because it is prone to front-running attacks. During the extension creation it is safer to
     * read the new extension address from the event generated in the create call transaction.
     */
    function getExtensionAddress(address dao) external view returns (address);
}

// SPDX-License-Identifier: MIT

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

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../../core/DaoRegistry.sol";
import "../IExtension.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

/**
 * @dev Proxy contract which executes delegated calls to another contract using the EVM
 * instruction `delegatecall`, the call is triggered via fallback function.
 * The call is executed in the target contract identified by its address via `implementation` argument.
 * The success and return data of the delegated call are be returned back to the caller of the proxy.
 * Only contracts with the ACL Flag: EXECUTOR are allowed to use the proxy delegated call function.
 * This contract was based on the OpenZeppelin Proxy contract:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/Proxy.sol
 */
contract ExecutorExtension is IExtension {
    using Address for address payable;

    bool public initialized = false; // internally tracks deployment under eip-1167 proxy pattern
    DaoRegistry public dao;

    enum AclFlag {
        EXECUTE
    }

    /// @notice Clonable contract must have an empty constructor
    constructor() {}

    modifier hasExtensionAccess(AclFlag flag) {
        require(
            (address(this) == msg.sender ||
                address(dao) == msg.sender ||
                !initialized ||
                DaoHelper.isInCreationModeAndHasAccess(dao) ||
                dao.hasAdapterAccessToExtension(
                    msg.sender,
                    address(this),
                    uint8(flag)
                )),
            "executorExt::accessDenied"
        );
        _;
    }

    /**
     * @notice Initialises the Executor extension to be associated with a DAO
     * @dev Can only be called once
     * @param _dao The dao address that will be associated with the new extension.
     */
    function initialize(DaoRegistry _dao, address) external override {
        require(!initialized, "already initialized");
        dao = _dao;
        initialized = true;
    }

    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internall call site, it will return directly to the external caller.
     */
    function _delegate(address implementation)
        internal
        virtual
        hasExtensionAccess(AclFlag.EXECUTE)
    {
        require(
            DaoHelper.isNotZeroAddress(implementation),
            "executorExt: impl address can not be zero"
        );
        require(
            DaoHelper.isNotReservedAddress(implementation),
            "executorExt: impl address can not be reserved"
        );

        address daoAddr;
        bytes memory data = msg.data;
        assembly {
            daoAddr := mload(add(data, 36))
        }

        require(daoAddr == address(dao), "wrong dao!");

        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())
            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(
                gas(),
                implementation,
                0,
                calldatasize(),
                0,
                0
            )

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev Delegates the current call to the sender address.
     *
     * This function does not return to its internall call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _delegate(msg.sender);
    }

    /**
     * @dev Fallback function that delegates calls to the sender address. Will run if no other
     * function in the contract matches the call data.
     */
    // Only senders with the EXECUTE ACL Flag enabled is allowed to send eth.
    //slither-disable-next-line locked-ether
    fallback() external payable {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    // Only senders with the EXECUTE ACL Flag enabled is allowed to send eth.
    //slither-disable-next-line locked-ether
    receive() external payable {
        _fallback();
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
import "../../../core/DaoRegistry.sol";
import "../../../helpers/DaoHelper.sol";
import "../../../guards/AdapterGuard.sol";
import "../../IExtension.sol";
import "../../bank/Bank.sol";
import "./IERC20TransferStrategy.sol";
import "../../../guards/AdapterGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

/**
 *
 * The ERC20Extension is a contract to give erc20 functionality
 * to the internal token units held by DAO members inside the DAO itself.
 */
contract ERC20Extension is AdapterGuard, IExtension, IERC20 {
    // The DAO address that this extension belongs to
    DaoRegistry public dao;

    // Internally tracks deployment under eip-1167 proxy pattern
    bool public initialized = false;

    // The token address managed by the DAO that tracks the internal transfers
    address public tokenAddress;

    // The name of the token managed by the DAO
    string public tokenName;

    // The symbol of the token managed by the DAO
    string public tokenSymbol;

    // The number of decimals of the token managed by the DAO
    uint8 public tokenDecimals;

    // Tracks all the token allowances: owner => spender => amount
    mapping(address => mapping(address => uint256)) private _allowances;

    /// @notice Clonable contract must have an empty constructor
    constructor() {}

    /**
     * @notice Initializes the extension with the DAO that it belongs to,
     * and checks if the parameters were set.
     * @param _dao The address of the DAO that owns the extension.
     */
    function initialize(DaoRegistry _dao, address) external override {
        require(!initialized, "already initialized");
        require(tokenAddress != address(0x0), "missing token address");
        require(bytes(tokenName).length != 0, "missing token name");
        require(bytes(tokenSymbol).length != 0, "missing token symbol");
        initialized = true;
        dao = _dao;
    }

    /**
     * @dev Returns the token address managed by the DAO that tracks the
     * internal transfers.
     */
    function token() external view virtual returns (address) {
        return tokenAddress;
    }

    /**
     * @dev Sets the token address if the extension is not initialized,
     * not reserved and not zero.
     */
    function setToken(address _tokenAddress) external {
        require(!initialized, "already initialized");
        require(_tokenAddress != address(0x0), "invalid token address");
        require(
            DaoHelper.isNotReservedAddress(_tokenAddress),
            "token address already in use"
        );

        tokenAddress = _tokenAddress;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() external view virtual returns (string memory) {
        return tokenName;
    }

    /**
     * @dev Sets the name of the token if the extension is not initialized.
     */
    function setName(string memory _name) external {
        require(!initialized, "already initialized");
        tokenName = _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view virtual returns (string memory) {
        return tokenSymbol;
    }

    /**
     * @dev Sets the token symbol if the extension is not initialized.
     */
    function setSymbol(string memory _symbol) external {
        require(!initialized, "already initialized");
        tokenSymbol = _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     */
    function decimals() external view virtual returns (uint8) {
        return tokenDecimals;
    }

    /**
     * @dev Sets the token decimals if the extension is not initialized.
     */
    function setDecimals(uint8 _decimals) external {
        require(!initialized, "already initialized");
        tokenDecimals = _decimals;
    }

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() public view override returns (uint256) {
        BankExtension bank = BankExtension(
            dao.getExtensionAddress(DaoHelper.BANK)
        );
        return bank.balanceOf(DaoHelper.TOTAL, tokenAddress);
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) public view override returns (uint256) {
        BankExtension bank = BankExtension(
            dao.getExtensionAddress(DaoHelper.BANK)
        );
        return bank.balanceOf(account, tokenAddress);
    }

    /**
     * @dev Returns the amount of tokens owned by `account` considering the snapshot.
     */
    function getPriorAmount(address account, uint256 snapshot)
        external
        view
        returns (uint256)
    {
        BankExtension bank = BankExtension(
            dao.getExtensionAddress(DaoHelper.BANK)
        );
        return bank.getPriorAmount(account, tokenAddress, snapshot);
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     * @param spender The address account that will have the units decremented.
     * @param amount The amount to decrement from the spender account.
     * @return a boolean value indicating whether the operation succeeded.
     *
     * Emits an {Approval} event.
     */
    // slither-disable-next-line reentrancy-benign
    function approve(address spender, uint256 amount)
        public
        override
        reentrancyGuard(dao)
        returns (bool)
    {
        address senderAddr = dao.getAddressIfDelegated(msg.sender);
        require(
            DaoHelper.isNotZeroAddress(senderAddr),
            "ERC20: approve from the zero address"
        );
        require(
            DaoHelper.isNotZeroAddress(spender),
            "ERC20: approve to the zero address"
        );
        require(dao.isMember(senderAddr), "sender is not a member");
        require(
            DaoHelper.isNotReservedAddress(spender),
            "spender can not be a reserved address"
        );

        _allowances[senderAddr][spender] = amount;
        // slither-disable-next-line reentrancy-events
        emit Approval(senderAddr, spender, amount);
        return true;
    }

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     * @dev The transfer operation follows the DAO configuration specified
     * by the ERC20_EXT_TRANSFER_TYPE property.
     * @param recipient The address account that will have the units incremented.
     * @param amount The amount to increment in the recipient account.
     * @return a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        return
            transferFrom(
                dao.getAddressIfDelegated(msg.sender),
                recipient,
                amount
            );
    }

    function _transferInternal(
        address senderAddr,
        address recipient,
        uint256 amount,
        BankExtension bank
    ) internal {
        DaoHelper.potentialNewMember(recipient, dao, bank);
        bank.internalTransfer(dao, senderAddr, recipient, tokenAddress, amount);
    }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     * @dev The transfer operation follows the DAO configuration specified
     * by the ERC20_EXT_TRANSFER_TYPE property.
     * @param sender The address account that will have the units decremented.
     * @param recipient The address account that will have the units incremented.
     * @param amount The amount to decrement from the sender account.
     * @return a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            DaoHelper.isNotZeroAddress(recipient),
            "ERC20: transfer to the zero address"
        );

        IERC20TransferStrategy strategy = IERC20TransferStrategy(
            dao.getAdapterAddress(DaoHelper.TRANSFER_STRATEGY)
        );
        (
            IERC20TransferStrategy.ApprovalType approvalType,
            uint256 allowedAmount
        ) = strategy.evaluateTransfer(
                dao,
                tokenAddress,
                sender,
                recipient,
                amount,
                msg.sender
            );

        BankExtension bank = BankExtension(
            dao.getExtensionAddress(DaoHelper.BANK)
        );

        if (approvalType == IERC20TransferStrategy.ApprovalType.NONE) {
            revert("transfer not allowed");
        }

        if (approvalType == IERC20TransferStrategy.ApprovalType.SPECIAL) {
            _transferInternal(sender, recipient, amount, bank);
            //slither-disable-next-line reentrancy-events
            emit Transfer(sender, recipient, amount);
            return true;
        }

        if (sender != msg.sender) {
            uint256 currentAllowance = _allowances[sender][msg.sender];
            //check if sender has approved msg.sender to spend amount
            require(
                currentAllowance >= amount,
                "ERC20: transfer amount exceeds allowance"
            );

            if (allowedAmount >= amount) {
                _allowances[sender][msg.sender] = currentAllowance - amount;
            }
        }

        if (allowedAmount >= amount) {
            _transferInternal(sender, recipient, amount, bank);
            //slither-disable-next-line reentrancy-events
            emit Transfer(sender, recipient, amount);
            return true;
        }

        return false;
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
import "../../../core/DaoRegistry.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

/**
 *
 * The ERC20Extension is a contract to give erc20 functionality
 * to the internal token units held by DAO members inside the DAO itself.
 */
interface IERC20TransferStrategy {
    enum AclFlag {
        REGISTER_TRANSFER
    }
    enum ApprovalType {
        NONE,
        STANDARD,
        SPECIAL
    }

    function evaluateTransfer(
        DaoRegistry dao,
        address tokenAddr,
        address from,
        address to,
        uint256 amount,
        address caller
    ) external view returns (ApprovalType, uint256);
}

pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import {Foundance} from "../../libraries/Foundance.sol";
import "../../core/DaoRegistry.sol";
import "../../extensions/IExtension.sol";
import "../../helpers/DaoHelper.sol";

contract DynamicEquityExtension is IExtension {

    enum AclFlag {
        SET_DYNAMIC_EQUITY,
        REMOVE_DYNAMIC_EQUITY,
        UPDATE_DYNAMIC_EQUITY
    }

    bool public initialized;

    DaoRegistry private _dao;

    modifier hasExtensionAccess(DaoRegistry dao, AclFlag flag) {
        require(
            dao == _dao &&
                (DaoHelper.isInCreationModeAndHasAccess(dao) ||
                    !initialized ||
                    _dao.hasAdapterAccessToExtension(
                        msg.sender,
                        address(this),
                        uint8(flag)
                    )),
            "dynamicEquityExt::accessDenied"
        );
        _;
    }

    Foundance.EpochConfig public epochConfig;
    Foundance.DynamicEquityConfig public dynamicEquityConfig;
    mapping(uint256 => mapping(address => Foundance.DynamicEquityMemberConfig)) public dynamicEquityEpochs;
    Foundance.DynamicEquityMemberConfig[] public dynamicEquityMemberConfig;
    mapping(address => uint) public dynamicEquityMemberIndex;
    Foundance.VestingMemberConfig[] public vestingMemberConfig;
    mapping(address => uint) public vestingMemberIndex;

    constructor() {}

    function initialize(DaoRegistry dao, address) external override {
        require(!initialized, "dynamicEquityExt::already initialized");
        initialized = true;
        _dao = dao;
    }

    //SET 
    function setDynamicEquity(
        DaoRegistry dao,
        Foundance.DynamicEquityConfig calldata config,
        Foundance.EpochConfig calldata _epochConfig
    ) external hasExtensionAccess(dao, AclFlag.SET_DYNAMIC_EQUITY) {
        dynamicEquityConfig = config;
        epochConfig = _epochConfig;
        epochConfig.epochLast = epochConfig.epochStart;
    }
    function setDynamicEquityMember(
        DaoRegistry dao,
        Foundance.DynamicEquityMemberConfig calldata config
    ) external hasExtensionAccess(dao, AclFlag.SET_DYNAMIC_EQUITY) {
        uint length = dynamicEquityMemberConfig.length;
        if(dynamicEquityMemberIndex[config.memberAddress]==0){
            dynamicEquityMemberIndex[config.memberAddress]=length+1;
            dynamicEquityMemberConfig.push(config);
        }else{
            dynamicEquityMemberConfig[dynamicEquityMemberIndex[config.memberAddress]-1] = config;
        } 
    }
    function setDynamicEquityMemberSuspended(
        DaoRegistry dao,
        address _member,
        uint256 suspendedUntil
    ) external hasExtensionAccess(dao, AclFlag.SET_DYNAMIC_EQUITY) {
        require(dynamicEquityMemberIndex[_member]>0, "dynamicEquityExt::member not set");
        dynamicEquityMemberConfig[dynamicEquityMemberIndex[_member]-1].suspendedUntil = suspendedUntil;
    }
    function setVestingMember(
        DaoRegistry dao,
        Foundance.VestingMemberConfig calldata config
    ) external hasExtensionAccess(dao, AclFlag.SET_DYNAMIC_EQUITY) {
        uint length = vestingMemberConfig.length;
        if(vestingMemberIndex[config.memberAddress]==0){
            vestingMemberIndex[config.memberAddress]=length+1;
            vestingMemberConfig.push(config);
        }else{
            vestingMemberConfig[vestingMemberIndex[config.memberAddress]-1] = config;
        } 
    }

    //REMOVE
    function removeDynamicEquityMember(
        DaoRegistry dao,
        address _member
    ) external view hasExtensionAccess(dao, AclFlag.REMOVE_DYNAMIC_EQUITY) {
        require(dynamicEquityMemberIndex[_member]>0, "dynamicEquityExt::member not set");
        dynamicEquityMemberIndex[_member]==0;
    }
    function removeVestingMember(
        DaoRegistry dao,
        address _member
    ) external view hasExtensionAccess(dao, AclFlag.REMOVE_DYNAMIC_EQUITY) {
        require(vestingMemberIndex[_member]>0, "dynamicEquityExt::member not set");
        vestingMemberIndex[_member]==0;
    }
    function removeVestingMemberAmount(
        DaoRegistry dao,
        address _member
    ) external hasExtensionAccess(dao, AclFlag.REMOVE_DYNAMIC_EQUITY) {
        uint blockTimestamp = block.timestamp;
        Foundance.VestingMemberConfig storage _vestingMemberConfig = vestingMemberConfig[vestingMemberIndex[_member]-1];
        require(blockTimestamp>_vestingMemberConfig.start+_vestingMemberConfig.cliff,"dynamicEquityExt::cliff not yet exceeded");
        _vestingMemberConfig.amount -= getVestingMemberDistributionAmount(_member);
        _vestingMemberConfig.start = blockTimestamp;
        _vestingMemberConfig.cliff = blockTimestamp;
        uint prolongedDuration = blockTimestamp-_vestingMemberConfig.start;
        _vestingMemberConfig.duration -= prolongedDuration;

    }

    //CHALLENGE
    function challengeDynamicEquityMemberEpoch(
        DaoRegistry dao,
        address _member
    ) external hasExtensionAccess(dao, AclFlag.UPDATE_DYNAMIC_EQUITY) {
        require(dynamicEquityMemberIndex[_member]>0,"dynamicEquityExt::member not set");
        Foundance.DynamicEquityMemberConfig storage _config = dynamicEquityEpochs[epochConfig.epochLast+epochConfig.epochDuration][_member];
        _config.salary=0;
        _config.salaryMarket=0;
        _config.availability=0;
        _config.expense=0;
    }

    //UPDATE
    function updateDynamicEquityMemberEpoch(
        DaoRegistry dao,
        Foundance.DynamicEquityMemberConfig calldata config
    ) external hasExtensionAccess(dao, AclFlag.UPDATE_DYNAMIC_EQUITY) {
        require(dynamicEquityMemberIndex[config.memberAddress]>0,"dynamicEquityExt::member not set");
        require(config.expense>dynamicEquityMemberConfig[dynamicEquityMemberIndex[config.memberAddress]-1].expenseThreshold,"dynamicEquityExt::expenses surpassed expensBudget");
        dynamicEquityEpochs[epochConfig.epochLast+epochConfig.epochDuration][config.memberAddress] = config;
    }
    function updateDynamicEquityEpoch(
        DaoRegistry dao,
        uint256 newEpochLast
    ) external hasExtensionAccess(dao, AclFlag.UPDATE_DYNAMIC_EQUITY) {
        require(epochConfig.epochLast<block.timestamp,"dynamicEquityExt::epoch not in past");
        require(epochConfig.epochLast>newEpochLast,"dynamicEquityExt::epoch not incremental to previous one");
        epochConfig.epochLast = newEpochLast;
    }

    //GET
    function getDynamicEquityMemberEpoch(
        address _member
    ) external view returns (Foundance.DynamicEquityMemberConfig memory) {
        return dynamicEquityEpochs[epochConfig.epochLast][_member];
    }
    function getVestingMemberEpoch(
        address _member
    ) external view returns (Foundance.VestingMemberConfig memory) {
        return vestingMemberConfig[vestingMemberIndex[_member]-1];
    }
    function getDynamicEquityEpochAmount(
        address _member
    ) external view returns (uint) {
        Foundance.DynamicEquityMemberConfig memory _epochMemberConfig = dynamicEquityEpochs[epochConfig.epochLast][_member];
        if(_epochMemberConfig.expense+_epochMemberConfig.availability>0){
            return getDynamicEquityEpochAmountInternal(
                _epochMemberConfig
            );
        }else{
            return getDynamicEquityEpochAmountInternal(
                dynamicEquityMemberConfig[dynamicEquityMemberIndex[_member]-1]
            );
        }
    }
    function getDynamicEquityEpochAmountInternal(
        Foundance.DynamicEquityMemberConfig memory dynamicEquityMemberEpochConfig
    ) public view returns (uint) {
        uint precisionFactor = 10**Foundance.FOUNDANCE_PRECISION;
        uint availabilityFactor = (dynamicEquityMemberEpochConfig.availability*precisionFactor/Foundance.FOUNDANCE_WORKDAYS_WEEK/Foundance.FOUNDANCE_MONTHS_YEAR);
        availabilityFactor *= 10**Foundance.FOUNDANCE_WEEKS_MONTH_PRECISION/Foundance.FOUNDANCE_WEEKS_MONTH;
        uint salaryEpoch = (dynamicEquityMemberEpochConfig.salary*availabilityFactor)/precisionFactor;
        uint salaryMarketEpoch = (dynamicEquityMemberEpochConfig.salaryMarket*availabilityFactor)/precisionFactor;
        uint timeEquity = 0;
        if(dynamicEquityMemberEpochConfig.salaryMarket>dynamicEquityMemberEpochConfig.salary){
            timeEquity = (( salaryMarketEpoch - salaryEpoch) * dynamicEquityConfig.timeMultiplier / 10**Foundance.FOUNDANCE_PRECISION );
        }
        uint riskEquity = ( dynamicEquityMemberEpochConfig.expense * dynamicEquityConfig.riskMultiplier / 10**Foundance.FOUNDANCE_PRECISION);
        return timeEquity + riskEquity;
    }
    function getVestingMemberDistributionAmount(
        address _member
    ) public view returns (uint) {
        Foundance.VestingMemberConfig storage _vestingMemberConfig = vestingMemberConfig[vestingMemberIndex[_member]-1];
        uint amount = 0;
        uint256 blockTimestamp = block.timestamp;
        if(blockTimestamp>_vestingMemberConfig.start+_vestingMemberConfig.cliff){
            if(_vestingMemberConfig.start+_vestingMemberConfig.duration<blockTimestamp){
                uint prolongedDuration = blockTimestamp-_vestingMemberConfig.start;
                uint toBeDistributed = (prolongedDuration/_vestingMemberConfig.duration)*_vestingMemberConfig.amount;
                return toBeDistributed;
            }else{
                return _vestingMemberConfig.amount;
            }
        }
        return amount;
    }
    function getVestingMemberAmount(
        address _member
    ) external view returns (uint) {
        return vestingMemberConfig[vestingMemberIndex[_member]-1].amount;
    }
    function getEpochConfig(
    ) public view returns (Foundance.EpochConfig memory) {
        return epochConfig;
    }
    function getDynamicEquityConfig(
    ) public view returns (Foundance.DynamicEquityConfig memory) {
        return dynamicEquityConfig;
    }

}

pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import {Foundance} from "../../libraries/Foundance.sol";
import "../../core/DaoRegistry.sol";
import "../../extensions/IExtension.sol";
import "../../helpers/DaoHelper.sol";

contract CommunityIncentiveExtension is IExtension {

    enum AclFlag {
        SET_COMMUNITY_INCENTIVE,
        REMOVE_COMMUNITY_INCENTIVE,
        UPDATE_COMMUNITY_INCENTIVE
    }

    bool public initialized;

    DaoRegistry private _dao;

    modifier hasExtensionAccess(DaoRegistry dao, AclFlag flag) {
        require(
            dao == _dao &&
                (DaoHelper.isInCreationModeAndHasAccess(dao) ||
                    !initialized ||
                    _dao.hasAdapterAccessToExtension(
                        msg.sender,
                        address(this),
                        uint8(flag)
                    )),
            "communityIncentive::accessDenied"
        );
        _;
    }

    Foundance.EpochConfig public epochConfig;
    Foundance.CommunityIncentiveConfig public communityIncentiveConfig;
    Foundance.CommunityIncentiveMemberConfig[] public communityIncentiveMemberConfig;
    mapping(address => uint) public communityIncentiveMemberIndex;

    constructor() {}
    
    function initialize(DaoRegistry dao, address) external override {
        require(!initialized, "communityIncentive::already initialized");
        initialized = true;
        _dao = dao;
    }

    //SET
    function setCommunityIncentive(
        DaoRegistry dao,
        Foundance.CommunityIncentiveConfig calldata _communityIncentiveConfig,
        Foundance.EpochConfig calldata _epochConfig
    ) external hasExtensionAccess(dao, AclFlag.SET_COMMUNITY_INCENTIVE) {
        communityIncentiveConfig = _communityIncentiveConfig;
        epochConfig = _epochConfig;
        epochConfig.epochLast = epochConfig.epochStart;
        //TODO remove tokens from guild for existing Config
        //TODO mint tokens to guild for new Config
    }
    function setCommunityIncentiveMember(
        DaoRegistry dao,
        Foundance.CommunityIncentiveMemberConfig calldata _communityIncentiveMemberConfig
    ) external hasExtensionAccess(dao, AclFlag.SET_COMMUNITY_INCENTIVE) {
        uint length = communityIncentiveMemberConfig.length;
        if(communityIncentiveMemberIndex[_communityIncentiveMemberConfig.memberAddress]==0){
            communityIncentiveMemberIndex[_communityIncentiveMemberConfig.memberAddress]=length+1;
            communityIncentiveMemberConfig.push(_communityIncentiveMemberConfig);
        }else{
            communityIncentiveMemberConfig[communityIncentiveMemberIndex[_communityIncentiveMemberConfig.memberAddress]-1] = _communityIncentiveMemberConfig;
        } 
    }

    //REMOVE
    function removeCommunityIncentiveMember(
        DaoRegistry dao,
        address _member
    ) external view hasExtensionAccess(dao, AclFlag.REMOVE_COMMUNITY_INCENTIVE) {
        require(communityIncentiveMemberIndex[_member]>0, "communityIncentive::member not set");
        communityIncentiveMemberIndex[_member]==0;
    }

    //UPDATE
        //TODO updateDistributionMember

    //GET
        //TODO getDistributionAllowance

    function getEpochConfig(
    ) public view returns (Foundance.EpochConfig memory) {
        return epochConfig;
    }
    function getCommunityIncentiveConfig(
    ) public view returns (Foundance.CommunityIncentiveConfig memory) {
        return communityIncentiveConfig;
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../../core/DaoRegistry.sol";
import "../../companion/interfaces/IReimbursement.sol";
import "./ReimbursableLib.sol";

/**
MIT License

Copyright (c) 2021 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */
abstract contract Reimbursable {
    struct ReimbursementData {
        uint256 gasStart; // how much gas is left before executing anything
        bool shouldReimburse; // should the transaction be reimbursed or not ?
        uint256 spendLimitPeriod; // how long (in seconds) is the spend limit period
        IReimbursement reimbursement; // which adapter address is used for reimbursement
    }

    /**
     * @dev Only registered adapters are allowed to execute the function call.
     */
    modifier reimbursable(DaoRegistry dao) {
        ReimbursementData memory data = ReimbursableLib.beforeExecution(dao);
        _;
        ReimbursableLib.afterExecution(dao, data);
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../core/DaoRegistry.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

abstract contract Signatures {
    string public constant EIP712_DOMAIN =
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,address actionId)";

    bytes32 public constant EIP712_DOMAIN_TYPEHASH =
        keccak256(abi.encodePacked(EIP712_DOMAIN));

    function hashMessage(
        DaoRegistry dao,
        address actionId,
        bytes32 message
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator(dao, actionId),
                    message
                )
            );
    }

    function domainSeparator(DaoRegistry dao, address actionId)
        public
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    keccak256("Snapshot Message"), // string name
                    keccak256("4"), // string version
                    block.chainid, // uint256 chainId
                    address(dao), // address verifyingContract,
                    actionId
                )
            );
    }

    function isValidSignature(
        address signer,
        bytes32 hash,
        bytes memory sig
    ) external view returns (bool) {
        return SignatureChecker.isValidSignatureNow(signer, hash, sig);
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../../core/DaoRegistry.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

interface IReimbursement {
    function reimburseTransaction(
        DaoRegistry dao,
        address payable caller,
        uint256 gasUsage,
        uint256 spendLimitPeriod
    ) external;

    function shouldReimburse(DaoRegistry dao, uint256 gasLeft)
        external
        view
        returns (bool, uint256);
}

pragma solidity ^0.8.0;

import "../../core/DaoRegistry.sol";
import "../../companion/interfaces/IReimbursement.sol";
import "./Reimbursable.sol";

// SPDX-License-Identifier: MIT

/**
MIT License

Copyright (c) 2021 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */
library ReimbursableLib {
    function beforeExecution(DaoRegistry dao)
        internal
        returns (Reimbursable.ReimbursementData memory data)
    {
        data.gasStart = gasleft();
        require(dao.lockedAt() != block.number, "reentrancy guard");
        dao.lockSession();
        address reimbursementAdapter = dao.adapters(DaoHelper.REIMBURSEMENT);
        if (reimbursementAdapter == address(0x0)) {
            data.shouldReimburse = false;
        } else {
            data.reimbursement = IReimbursement(reimbursementAdapter);

            (bool shouldReimburse, uint256 spendLimitPeriod) = data
                .reimbursement
                .shouldReimburse(dao, data.gasStart);

            data.shouldReimburse = shouldReimburse;
            data.spendLimitPeriod = spendLimitPeriod;
        }
    }

    function afterExecution(
        DaoRegistry dao,
        Reimbursable.ReimbursementData memory data
    ) internal {
        afterExecution2(dao, data, payable(msg.sender));
    }

    function afterExecution2(
        DaoRegistry dao,
        Reimbursable.ReimbursementData memory data,
        address payable caller
    ) internal {
        if (data.shouldReimburse) {
            data.reimbursement.reimburseTransaction(
                dao,
                caller,
                data.gasStart - gasleft(),
                data.spendLimitPeriod
            );
        }
        dao.unlockSession();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ECDSA.sol";
import "../Address.sol";
import "../../interfaces/IERC1271.sol";

/**
 * @dev Signature verification helper: Provide a single mechanism to verify both private-key (EOA) ECDSA signature and
 * ERC1271 contract sigantures. Using this instead of ECDSA.recover in your contract will make them compatible with
 * smart contract wallets such as Argent and Gnosis.
 *
 * Note: unlike ECDSA signatures, contract signature's are revocable, and the outcome of this function can thus change
 * through time. It could return true at block N and false at block N+1 (or the opposite).
 *
 * _Available since v4.1._
 */
library SignatureChecker {
    function isValidSignatureNow(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal view returns (bool) {
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, signature);
        if (error == ECDSA.RecoverError.NoError && recovered == signer) {
            return true;
        }

        (bool success, bytes memory result) = signer.staticcall(
            abi.encodeWithSelector(IERC1271.isValidSignature.selector, hash, signature)
        );
        return (success && result.length == 32 && abi.decode(result, (bytes4)) == IERC1271.isValidSignature.selector);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        // Check the signature length
        // - case 65: r,s,v signature (standard)
        // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return tryRecover(hash, r, vs);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s;
        uint8 v;
        assembly {
            s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            v := add(shr(255, vs), 27)
        }
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC1271 standard signature validation method for
 * contracts as defined in https://eips.ethereum.org/EIPS/eip-1271[ERC-1271].
 *
 * _Available since v4.1._
 */
interface IERC1271 {
    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param signature Signature byte array associated with _data
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../../core/DaoRegistry.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

interface IVoting {
    enum VotingState {
        NOT_STARTED,
        TIE,
        PASS,
        NOT_PASS,
        IN_PROGRESS,
        GRACE_PERIOD
    }

    function getAdapterName() external pure returns (string memory);

    function startNewVotingForProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data
    ) external;

    function getSenderAddress(
        DaoRegistry dao,
        address actionId,
        bytes memory data,
        address sender
    ) external returns (address);

    function voteResult(DaoRegistry dao, bytes32 proposalId)
        external
        returns (VotingState state);
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../helpers/DaoHelper.sol";
import "../core/DaoRegistry.sol";
import "../extensions/bank/Bank.sol";
import "../extensions/token/erc20/ERC20TokenExtension.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */
library GovernanceHelper {
    string public constant ROLE_PREFIX = "governance.role.";
    bytes32 public constant DEFAULT_GOV_TOKEN_CFG =
        keccak256(abi.encodePacked(ROLE_PREFIX, "default"));

    /*
     * @dev Checks if the member address holds enough funds to be considered a governor.
     * @param dao The DAO Address.
     * @param memberAddr The message sender to be verified as governor.
     * @param proposalId The proposal id to retrieve the governance token address if configured.
     * @param snapshot The snapshot id to check the balance of the governance token for that member configured.
     */
    function getVotingWeight(
        DaoRegistry dao,
        address voterAddr,
        bytes32 proposalId,
        uint256 snapshot
    ) internal view returns (uint256) {
        (address adapterAddress, ) = dao.proposals(proposalId);

        // 1st - if there is any governance token configuration
        // for the adapter address, then read the voting weight based on that token.
        address governanceToken = dao.getAddressConfiguration(
            keccak256(abi.encodePacked(ROLE_PREFIX, adapterAddress))
        );
        if (DaoHelper.isNotZeroAddress(governanceToken)) {
            return getVotingWeight(dao, governanceToken, voterAddr, snapshot);
        }

        // 2nd - if there is no governance token configured for the adapter,
        // then check if exists a default governance token.
        // If so, then read the voting weight based on that token.
        governanceToken = dao.getAddressConfiguration(DEFAULT_GOV_TOKEN_CFG);
        if (DaoHelper.isNotZeroAddress(governanceToken)) {
            return getVotingWeight(dao, governanceToken, voterAddr, snapshot);
        }

        // 3rd - if none of the previous options are available, assume the
        // governance token is UNITS, then read the voting weight based on that token.
        return
            BankExtension(dao.getExtensionAddress(DaoHelper.BANK))
                .getPriorAmount(voterAddr, DaoHelper.UNITS, snapshot);
    }

    function getVotingWeight(
        DaoRegistry dao,
        address governanceToken,
        address voterAddr,
        uint256 snapshot
    ) internal view returns (uint256) {
        BankExtension bank = BankExtension(
            dao.getExtensionAddress(DaoHelper.BANK)
        );
        if (bank.isInternalToken(governanceToken)) {
            return bank.getPriorAmount(voterAddr, governanceToken, snapshot);
        }

        // The external token must implement the getPriorAmount function,
        // otherwise this call will fail and revert the voting process.
        // The actual revert does not show a clear reason, so we catch the error
        // and revert with a better error message.
        // slither-disable-next-line unused-return
        try
            ERC20Extension(governanceToken).getPriorAmount(voterAddr, snapshot)
        returns (
            // slither-disable-next-line uninitialized-local,variable-scope
            uint256 votingWeight
        ) {
            return votingWeight;
        } catch {
            revert("getPriorAmount not implemented");
        }
    }
}

pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import {Foundance} from "../../libraries/Foundance.sol";
import "../../core/DaoRegistry.sol";



interface IDynamicEquity {

    //SET
    function submitSetDynamicEquityProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        Foundance.DynamicEquityConfig calldata configDynamicEquity,
        Foundance.EpochConfig calldata configEpoch
    ) external;
    function processSetDynamicEquityProposal(DaoRegistry dao, bytes32 proposalId) external;

    function submitSetDynamicEquityMemberProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        Foundance.DynamicEquityMemberConfig calldata config
    ) external;
    function processSetDynamicEquityMemberProposal(DaoRegistry dao, bytes32 proposalId) external;

    function submitSetVestingMemberProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        Foundance.VestingMemberConfig calldata config
    ) external;
    function processSetVestingMemberProposal(DaoRegistry dao, bytes32 proposalId) external;

    //REMOVE
    function submitRemoveDynamicEquityMemberProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        address memberAdress
    ) external;
    function processRemoveDynamicEquityMemberProposal(DaoRegistry dao, bytes32 proposalId) external;

    function submitRemoveVestingMemberProposal(
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        address memberAdress
    ) external;
    function processRemoveVestingMemberProposal(DaoRegistry dao, bytes32 proposalId) external;

    //CHALLENGE
        function submitChallengeDynamicEquityMemberEpochProposal( 
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        address memberAdress
    ) external;
    function processChallengeDynamicEquityMemberEpochProposal(DaoRegistry dao, bytes32 proposalId) external;

    //UPDATE
    function submitUpdateDynamicEquityMemberEpochProposal( 
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        Foundance.DynamicEquityMemberConfig calldata config
    ) external;
    function processUpdateDynamicEquityMemberEpochProposal(DaoRegistry dao, bytes32 proposalId) external;

    function submitUpdateDynamicEquityEpochProposal( 
        DaoRegistry dao,
        bytes32 proposalId,
        bytes calldata data,
        uint256 config
    ) external;
    function processUpdateDynamicEquityEpochProposal(DaoRegistry dao, bytes32 proposalId) external;

    //DISTRIBUTE
    function distributeDynamicEquityMemberEpoch(DaoRegistry dao) external;
    function distributeVestingMember(DaoRegistry dao, address memberAddress) external;

}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

/**
MIT License

Copyright (c) 2020 Openlaw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */
library FairShareHelper {
    /**
     * @notice calculates the fair unit amount based the total units and current balance.
     */
    function calc(
        uint256 balance,
        uint256 units,
        uint256 totalUnits
    ) internal pure returns (uint256) {
        require(totalUnits > 0, "totalUnits must be greater than 0");
        require(
            units <= totalUnits,
            "units must be less than or equal to totalUnits"
        );
        if (balance == 0) {
            return 0;
        }
        // The balance for Internal and External tokens are limited to 2^64-1 (see Bank.sol:L411-L421)
        // The maximum number of units is limited to 2^64-1 (see ...)
        // Worst case cenario is: balance=2^64-1 * units=2^64-1, no overflows.
        uint256 prod = balance * units;
        return prod / totalUnits;
    }
}

pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import {Foundance} from "../../libraries/Foundance.sol";
import "../../core/DaoRegistry.sol";

interface ICommunityIncentive {

    
}