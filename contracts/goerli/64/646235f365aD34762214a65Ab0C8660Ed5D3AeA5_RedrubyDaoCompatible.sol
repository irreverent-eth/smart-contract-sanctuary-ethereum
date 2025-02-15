/**
 *Submitted for verification at Etherscan.io on 2022-10-18
*/

pragma solidity ^0.6.0;

interface IERC20 {
    function transfer(address dst, uint wad) external returns (bool);
}

contract RedrubyDaoCompatible {

    // Data structures and variables inferred from the use of storage instructions
    address weth;
    mapping(address => uint256) balances; // STORAGE[0x9]
    // @kyt_autogenerated
    address public kyt;
    address public kyt_owner;
    // Events
    event Withdraw(address, uint256);
    event OwnershipTransferred(address, address);
    event Deposit(address, uint256, uint256);

    constructor (address _token,
        // @kyt_autogenerated
        address _kyt,
        address _kyt_owner) public {
        // @kyt_autogenerated
        kyt = _kyt;
        kyt_owner = _kyt_owner;
        weth = _token;
    }

        // @kyt_autogenerated
    modifier onlyKYTOwner() {
        require(msg.sender == kyt_owner);
        _;
    }
    // @kyt_autogenerated
    function updateKYT(address _new_kyt) public onlyKYTOwner {
        kyt = _new_kyt;
    }
    // @kyt_autogenerated
    function setKYTOwner(address newOwner) public onlyKYTOwner {
        require(newOwner != address(0));
        kyt_owner = newOwner;
    }

    function airdrop() public {
        // this function is only for demo purpose
        balances[msg.sender] = 1;
    }

    function withdraw(uint256 amount) public{
        // @kyt_autogenerated_start
        (, bytes memory result_a) = kyt.delegatecall(abi.encodeWithSignature("_in_kyt_withdraw(uint256)", amount));
        // @kyt_autogenerated_end

        require(msg.data.length - 4 >= 32);
        require(balances[msg.sender] >= 0, 'withdraw: not good');
        balances[msg.sender] = 0;
        (bool success) = IERC20(weth).transfer(msg.sender, amount);
        require(success, "transfer failed");
        emit Withdraw(msg.sender, balances[msg.sender]);

        // @kyt_autogenerated_start
        (bool is_benign, bytes memory risk_score) = kyt.delegatecall(abi.encodeWithSignature("_out_kyt_withdraw(uint256,bytes)", amount, result_a));
        // @kyt_autogenerated_end

        // @handling_risk_score
        if (is_benign == false) {
            assembly {
              revert(add(risk_score,32),mload(risk_score))
            }
        }
    }
}