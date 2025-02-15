// SPDX-License-Identifier:MIT
pragma solidity ^0.8.3;

import "./PiggyBank.sol";

contract PiggyBankFactory {
    PiggyBank[] public banks;
    mapping(address =>  PiggyBank[]) individualBanks; 

    event newClone(PiggyBank indexed , uint256 indexed position, string indexed purpose);

    //@dev This functions creates piggy banks with unique addresses
    function createBank(address _devAdd, uint _timeLock, string memory _savingPurpose) external returns (PiggyBank newPiggyBank, uint length) {
        address ownerAddress = msg.sender;
        newPiggyBank = new PiggyBank(ownerAddress, _devAdd, _timeLock, _savingPurpose);
        banks.push(newPiggyBank);
        length = banks.length;
        individualBanks[msg.sender].push(newPiggyBank);
        emit newClone(newPiggyBank, length, _savingPurpose);
    }

    function bankCount() external view returns (uint totalBank) {
        totalBank = banks.length;
    }

    function getBanks() external view returns (PiggyBank[] memory allBanks) {
        allBanks = banks;
    }

    function getContractsForEachBank() external view returns(PiggyBank[] memory ) {
        return individualBanks[msg.sender];
    }

}

// SPDX-License-Identifier:MIT

pragma solidity ^0.8.3;

//import "./IStable.sol";


contract PiggyBank {
    event Deposit(uint amount);
    event Withdraw(uint amount);

    string public savingPurpose;

    address public immutable owner;
    address immutable devAddr;
    uint immutable timeLock;

    constructor(address ownerAddress, address _devAdd, uint _timeLock, string memory _savingPurpose) {
        owner = ownerAddress;
        devAddr = _devAdd;
        timeLock =  block.timestamp + (_timeLock * 1 days);
        savingPurpose = _savingPurpose;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "requires only owner");
        _;
    }

    function deposit() external payable{
       require(msg.value > 0, "You can't deposit less than 0");
    }

    
    //@dev function to withdraw funds after lock time is reached
    function safeWithdraw() external onlyOwner {
        require(block.timestamp > timeLock, "Lock period not reached");
        require(msg.sender != address(0), "You cant withdraw into zero address");
        require(address(this).balance > 0, "no funds deposited");

        uint bal = address(this).balance;
        uint commission = savingCommission();

        uint withdrawable = bal - commission;

        payable(owner).transfer(withdrawable);
        payable(devAddr).transfer(commission);

        emit Withdraw(withdrawable);
    }

    function savingCommission () private view returns(uint commission) {
        commission = (address(this).balance * 1) / 1000;
    }

    //@dev function called for emergency withdrawal and 15% is withdrawn as chanrges (for penal fee) 
    function emergencyWithdawal () external onlyOwner {
        uint contractBal = address(this).balance;
        uint penalFee = penalPercentage();

        uint withdrawBal = contractBal - penalFee;

        payable(owner).transfer(withdrawBal);

        devWithdraw(penalFee);
        
    }

    //@dev this function allows dev to withdraw the percentage gotten after emergency funds have been withdrawn 
    function devWithdraw (uint _penalFee) internal {
        require(msg.sender != address(0), "Can't withdraw to this addess");

        payable(devAddr).transfer(_penalFee);
    }

     function penalPercentage () private view returns(uint percent){
        percent = (address(this).balance / 15) * 100;
    }

    function getContractBalance() external view returns (uint bal) {
        bal = address(this).balance;
    }

    receive() external payable {
        emit Deposit(msg.value);
    }
}