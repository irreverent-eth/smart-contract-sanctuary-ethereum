/**
 *Submitted for verification at Etherscan.io on 2022-10-01
*/

// File: contracts/external/multisig/MultiSig.sol

/*

    Copyright 2019 dYdX Trading Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

*/

pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;


/**
 * @title MultiSig
 * @author dYdX
 *
 * Multi-Signature Wallet.
 * Allows multiple parties to agree on transactions before execution.
 * Adapted from Stefan George's MultiSigWallet contract.
 *
 * Logic Changes:
 *  - Removed the fallback function
 *  - Ensure newOwner is notNull
 *
 * Syntax Changes:
 *  - Update Solidity syntax for 0.5.X: use `emit` keyword (events), use `view` keyword (functions)
 *  - Add braces to all `if` and `for` statements
 *  - Remove named return variables
 *  - Add space before and after comparison operators
 *  - Add ADDRESS_ZERO as a constant
 *  - uint => uint256
 *  - external_call => externalCall
 */
contract MultiSig {

    // ============ Events ============

    event Confirmation(address indexed sender, uint256 indexed transactionId);
    event Revocation(address indexed sender, uint256 indexed transactionId);
    event Submission(uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId, string error);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint256 required);

    // ============ Constants ============

    uint256 constant public MAX_OWNER_COUNT = 50;
    address constant ADDRESS_ZERO = address(0x0);

    // ============ Storage ============

    mapping (uint256 => Transaction) public transactions;
    mapping (uint256 => mapping (address => bool)) public confirmations;
    mapping (address => bool) public isOwner;
    address[] public owners;
    uint256 public required;
    uint256 public transactionCount;

    // ============ Structs ============

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
    }

    // ============ Modifiers ============

    modifier onlyWallet() {
        require(msg.sender == address(this), "ONLY_WALLET");
        _;
    }

    modifier ownerDoesNotExist(
        address owner
    ) {
        require(!isOwner[owner], "OWNER_EXISTS");
        _;
    }

    modifier ownerExists(
        address owner
    ) {
        require(isOwner[owner], "OWNER_DOES_NOT_EXIST");
        _;
    }

    modifier transactionExists(
        uint256 transactionId
    ) {
        require(transactions[transactionId].destination != ADDRESS_ZERO, "TRANSACTION_DOES_NOT_EXIST");
        _;
    }

    modifier confirmed(
        uint256 transactionId,
        address owner
    ) {
        require(confirmations[transactionId][owner], "TRANSACTION_NOT_CONFIRMED");
        _;
    }

    modifier notConfirmed(
        uint256 transactionId,
        address owner
    ) {
        require(!confirmations[transactionId][owner], "TRANSACTION_ALREADY_CONFIRMED");
        _;
    }

    modifier notExecuted(
        uint256 transactionId
    ) {
        require(!transactions[transactionId].executed, "TRANSACTION_ALREADY_EXECUTED");
        _;
    }

    modifier notNull(
        address _address
    ) {
        require(_address != ADDRESS_ZERO, "ADDRESS_IS_NULL");
        _;
    }

    modifier validRequirement(
        uint256 ownerCount,
        uint256 _required
    ) {
        require(
            ownerCount <= MAX_OWNER_COUNT
            && _required <= ownerCount
            && _required != 0
            && ownerCount != 0,
            "NO_REQUIREMENTS"
        );
        _;
    }

    // ============ Constructor ============

    /**
     * Contract constructor sets initial owners and required number of confirmations.
     *
     * @param  _owners    List of initial owners.
     * @param  _required  Number of required confirmations.
     */
    constructor(
        address[] memory _owners,
        uint256 _required
    )
        public
        validRequirement(_owners.length, _required)
    {
        for (uint256 i = 0; i < _owners.length; i++) {
            require(!isOwner[_owners[i]] && _owners[i] != ADDRESS_ZERO, "ALREADY_OWNER");
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
    }

    // ============ Wallet-Only Functions ============

    /**
     * Allows to add a new owner. Transaction has to be sent by wallet.
     *
     * @param  owner  Address of new owner.
     */
    function addOwner(
        address owner
    )
        public
        onlyWallet
        ownerDoesNotExist(owner)
        notNull(owner)
        validRequirement(owners.length + 1, required)
    {
        isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAddition(owner);
    }

    /**
     * Allows to remove an owner. Transaction has to be sent by wallet.
     *
     * @param  owner  Address of owner.
     */
    function removeOwner(
        address owner
    )
        public
        onlyWallet
        ownerExists(owner)
    {
        isOwner[owner] = false;
        for (uint256 i = 0; i < owners.length - 1; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }
        owners.length -= 1;
        if (required > owners.length) {
            changeRequirement(owners.length);
        }
        emit OwnerRemoval(owner);
    }

    /**
     * Allows to replace an owner with a new owner. Transaction has to be sent by wallet.
     *
     * @param  owner     Address of owner to be replaced.
     * @param  newOwner  Address of new owner.
     */
    function replaceOwner(
        address owner,
        address newOwner
    )
        public
        onlyWallet
        ownerExists(owner)
        ownerDoesNotExist(newOwner)
        notNull(newOwner)
    {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = newOwner;
                break;
            }
        }
        isOwner[owner] = false;
        isOwner[newOwner] = true;
        emit OwnerRemoval(owner);
        emit OwnerAddition(newOwner);
    }

    /**
     * Allows to change the number of required confirmations. Transaction has to be sent by wallet.
     *
     * @param  _required  Number of required confirmations.
     */
    function changeRequirement(
        uint256 _required
    )
        public
        onlyWallet
        validRequirement(owners.length, _required)
    {
        required = _required;
        emit RequirementChange(_required);
    }

    // ============ Admin Functions ============

    /**
     * Allows an owner to submit and confirm a transaction.
     *
     * @param  destination  Transaction target address.
     * @param  value        Transaction ether value.
     * @param  data         Transaction data payload.
     * @return              Transaction ID.
     */
    function submitTransaction(
        address destination,
        uint256 value,
        bytes memory data
    )
        public
        returns (uint256)
    {
        uint256 transactionId = _addTransaction(destination, value, data);
        confirmTransaction(transactionId);
        return transactionId;
    }

    /**
     * Allows an owner to confirm a transaction.
     *
     * @param  transactionId  Transaction ID.
     */
    function confirmTransaction(
        uint256 transactionId
    )
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    /**
     * Allows an owner to revoke a confirmation for a transaction.
     *
     * @param  transactionId  Transaction ID.
     */
    function revokeConfirmation(
        uint256 transactionId
    )
        public
        ownerExists(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        confirmations[transactionId][msg.sender] = false;
        emit Revocation(msg.sender, transactionId);
    }

    /**
     * Allows an owner to execute a confirmed transaction.
     *
     * @param  transactionId  Transaction ID.
     */
    function executeTransaction(
        uint256 transactionId
    )
        public
        ownerExists(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        if (isConfirmed(transactionId)) {
            Transaction storage txn = transactions[transactionId];
            txn.executed = true;
            (bool success, string memory error) = _externalCall(txn.destination, txn.value, txn.data);
            if (success) {
                emit Execution(transactionId);
            } else {
                emit ExecutionFailure(transactionId, error);
                txn.executed = false;
            }
        }
    }

    // ============ Getter Functions ============

    /**
     * Returns the confirmation status of a transaction.
     *
     * @param  transactionId  Transaction ID.
     * @return                Confirmation status.
     */
    function isConfirmed(
        uint256 transactionId
    )
        public
        view
        returns (bool)
    {
        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                count += 1;
            }
            if (count == required) {
                return true;
            }
        }
        return false;
    }

    /**
     * Returns number of confirmations of a transaction.
     *
     * @param  transactionId  Transaction ID.
     * @return                Number of confirmations.
     */
    function getConfirmationCount(
        uint256 transactionId
    )
        public
        view
        returns (uint256)
    {
        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                count += 1;
            }
        }
        return count;
    }

    /**
     * Returns total number of transactions after filers are applied.
     *
     * @param  pending   Include pending transactions.
     * @param  executed  Include executed transactions.
     * @return           Total number of transactions after filters are applied.
     */
    function getTransactionCount(
        bool pending,
        bool executed
    )
        public
        view
        returns (uint256)
    {
        uint256 count = 0;
        for (uint256 i = 0; i < transactionCount; i++) {
            if (
                pending && !transactions[i].executed
                || executed && transactions[i].executed
            ) {
                count += 1;
            }
        }
        return count;
    }

    /**
     * Returns array of owners.
     *
     * @return  Array of owner addresses.
     */
    function getOwners()
        public
        view
        returns (address[] memory)
    {
        return owners;
    }

    /**
     * Returns array with owner addresses, which confirmed transaction.
     *
     * @param  transactionId  Transaction ID.
     * @return                Array of owner addresses.
     */
    function getConfirmations(
        uint256 transactionId
    )
        public
        view
        returns (address[] memory)
    {
        address[] memory confirmationsTemp = new address[](owners.length);
        uint256 count = 0;
        uint256 i;
        for (i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                confirmationsTemp[count] = owners[i];
                count += 1;
            }
        }
        address[] memory _confirmations = new address[](count);
        for (i = 0; i < count; i++) {
            _confirmations[i] = confirmationsTemp[i];
        }
        return _confirmations;
    }

    /**
     * Returns list of transaction IDs in defined range.
     *
     * @param  from      Index start position of transaction array.
     * @param  to        Index end position of transaction array.
     * @param  pending   Include pending transactions.
     * @param  executed  Include executed transactions.
     * @return           Array of transaction IDs.
     */
    function getTransactionIds(
        uint256 from,
        uint256 to,
        bool pending,
        bool executed
    )
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory transactionIdsTemp = new uint256[](transactionCount);
        uint256 count = 0;
        uint256 i;
        for (i = 0; i < transactionCount; i++) {
            if (
                pending && !transactions[i].executed
                || executed && transactions[i].executed
            ) {
                transactionIdsTemp[count] = i;
                count += 1;
            }
        }
        uint256[] memory _transactionIds = new uint256[](to - from);
        for (i = from; i < to; i++) {
            _transactionIds[i - from] = transactionIdsTemp[i];
        }
        return _transactionIds;
    }

    // ============ Helper Functions ============

    // call has been separated into its own function in order to take advantage
    // of the Solidity's code generator to produce a loop that copies tx.data into memory.
    function _externalCall(
        address destination,
        uint256 value,
        bytes memory data
    )
        internal
        returns (bool, string memory)
    {
        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory result) = destination.call.value(value)(data);
        if (!success) {
            string memory targetString = _addressToString(destination);
            if (result.length < 68) {
                return (false, string(abi.encodePacked("MultiSig::_externalCall: revert at <", targetString, ">")));
            } else {
                // solium-disable-next-line security/no-inline-assembly
                assembly {
                    result := add(result, 0x04)
                }
                return (
                    false,
                    string(
                        abi.encodePacked(
                            "MultiSig::_externalCall: revert at <",
                            targetString,
                            "> with reason: ",
                            abi.decode(result, (string))
                        )
                    )
                );
            }
        } else {
            return (true, "");
        }
    }

    /**
     * Adds a new transaction to the transaction mapping, if transaction does not exist yet.
     *
     * @param  destination  Transaction target address.
     * @param  value        Transaction ether value.
     * @param  data         Transaction data payload.
     * @return              Transaction ID.
     */
    function _addTransaction(
        address destination,
        uint256 value,
        bytes memory data
    )
        internal
        notNull(destination)
        returns (uint256)
    {
        uint256 transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false
        });
        transactionCount += 1;
        emit Submission(transactionId);
        return transactionId;
    }

    function _addressToString(address _address) internal pure returns(string memory) {
        bytes32 _bytes = bytes32(uint256(_address));
        bytes memory HEX = "0123456789abcdef";
        bytes memory _string = new bytes(42);
        _string[0] = "0";
        _string[1] = "x";
        for (uint i = 0; i < 20; i++) {
            _string[2 + i * 2] = HEX[uint8(_bytes[i + 12] >> 4)];
            _string[3 + i * 2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
        }
        return string(_string);
    }
}

// File: contracts/external/multisig/DelayedMultiSig.sol

/*

    Copyright 2019 dYdX Trading Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

*/

pragma solidity ^0.5.7;



/**
 * @title DelayedMultiSig
 * @author dYdX
 *
 * Multi-Signature Wallet with delay in execution.
 * Allows multiple parties to execute a transaction after a time lock has passed.
 * Adapted from Amir Bandeali's MultiSigWalletWithTimeLock contract.

 * Logic Changes:
 *  - Only owners can execute transactions
 *  - Require that each transaction succeeds
 *  - Added function to execute multiple transactions within the same Ethereum transaction
 */
contract DelayedMultiSig is
    MultiSig
{
    // ============ Events ============

    event ConfirmationTimeSet(uint256 indexed transactionId, uint256 confirmationTime);
    event TimeLockChange(uint32 secondsTimeLocked);

    // ============ Storage ============

    uint32 public secondsTimeLocked;
    mapping (uint256 => uint256) public confirmationTimes;

    // ============ Modifiers ============

    modifier notFullyConfirmed(
        uint256 transactionId
    ) {
        require(
            !isConfirmed(transactionId),
            "TX_FULLY_CONFIRMED"
        );
        _;
    }

    modifier fullyConfirmed(
        uint256 transactionId
    ) {
        require(
            isConfirmed(transactionId),
            "TX_NOT_FULLY_CONFIRMED"
        );
        _;
    }

    modifier pastTimeLock(
        uint256 transactionId
    ) {
        require(
            block.timestamp >= confirmationTimes[transactionId] + secondsTimeLocked,
            "TIME_LOCK_INCOMPLETE"
        );
        _;
    }

    // ============ Constructor ============

    /**
     * Contract constructor sets initial owners, required number of confirmations, and time lock.
     *
     * @param  _owners             List of initial owners.
     * @param  _required           Number of required confirmations.
     * @param  _secondsTimeLocked  Duration needed after a transaction is confirmed and before it
     *                             becomes executable, in seconds.
     */
    constructor (
        address[] memory _owners,
        uint256 _required,
        uint32 _secondsTimeLocked
    )
        public
        MultiSig(_owners, _required)
    {
        secondsTimeLocked = _secondsTimeLocked;
    }

    // ============ Wallet-Only Functions ============

    /**
     * Changes the duration of the time lock for transactions.
     *
     * @param  _secondsTimeLocked  Duration needed after a transaction is confirmed and before it
     *                             becomes executable, in seconds.
     */
    function changeTimeLock(
        uint32 _secondsTimeLocked
    )
        public
        onlyWallet
    {
        secondsTimeLocked = _secondsTimeLocked;
        emit TimeLockChange(_secondsTimeLocked);
    }

    // ============ Admin Functions ============

    /**
     * Allows an owner to confirm a transaction.
     * Overrides the function in MultiSig.
     *
     * @param  transactionId  Transaction ID.
     */
    function confirmTransaction(
        uint256 transactionId
    )
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
        notFullyConfirmed(transactionId)
    {
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        if (isConfirmed(transactionId)) {
            setConfirmationTime(transactionId, block.timestamp);
        }
    }

    /**
     * Allows an owner to execute a confirmed transaction.
     * Overrides the function in MultiSig.
     *
     * @param  transactionId  Transaction ID.
     */
    function executeTransaction(
        uint256 transactionId
    )
        public
        ownerExists(msg.sender)
        notExecuted(transactionId)
        fullyConfirmed(transactionId)
        pastTimeLock(transactionId)
    {
        Transaction storage txn = transactions[transactionId];
        txn.executed = true;
        (bool success, string memory errorMessage) = _externalCall(
            txn.destination,
            txn.value,
            txn.data
        );
        require(
            success,
            errorMessage
        );
        emit Execution(transactionId);
    }

    /**
     * Allows an owner to execute multiple confirmed transactions.
     *
     * @param  transactionIds  List of transaction IDs.
     */
    function executeMultipleTransactions(
        uint256[] memory transactionIds
    )
        public
        ownerExists(msg.sender)
    {
        for (uint256 i = 0; i < transactionIds.length; i++) {
            executeTransaction(transactionIds[i]);
        }
    }

    // ============ Helper Functions ============

    /**
     * Sets the time of when a submission first passed.
     */
    function setConfirmationTime(
        uint256 transactionId,
        uint256 confirmationTime
    )
        internal
    {
        confirmationTimes[transactionId] = confirmationTime;
        emit ConfirmationTimeSet(transactionId, confirmationTime);
    }
}