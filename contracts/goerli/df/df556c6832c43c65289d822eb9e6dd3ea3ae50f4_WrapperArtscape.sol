/**
 *Submitted for verification at Etherscan.io on 2022-11-29
*/

// SPDX-License-Identifier: MIT
// File: contracts/marketplace/interfaces/IRequest.sol


pragma solidity ^0.8.0;

interface IRequest {
    event RequestTx(uint8 TxType, address owner, address buyer, address requestAddress, address voucherAddress, uint indexed tokenId, address indexed tokenAddress, uint price, bool isComplete);

    function createRequest(uint _tokenId, address _tokenAddress, uint _price) external returns(address);
    function acceptRequest(address _requestAddress) external;
    function rejectedRequest(address _requestAddress) external;
}
// File: contracts/marketplace/EscowVault.sol


pragma solidity ^0.8.0;
contract EscowVault{
    /** status true=available false=unavailable */
    mapping(address=>mapping(uint=> bool))public activeSell;
    mapping(address=>mapping(uint=> bool))public activeAuction;
    mapping(address=>mapping(uint=> bool))public activeRequest;
    function transferEscowOnSell(address _tokenAddress, uint _tokenId) internal virtual {
        activeSell[_tokenAddress][_tokenId] = true;
    }
    function escowSellCheck(address _tokenAddress, uint _tokenId) internal view returns(bool){
       return activeSell[_tokenAddress][_tokenId];
    }
    function withdrawalSell(address _tokenAddress, uint _tokenId) internal virtual {
        activeSell[_tokenAddress][_tokenId]=false;
    }
    function transferEscowAuction(address _tokenAddress, uint _tokenId) internal virtual {
        activeAuction[_tokenAddress][_tokenId] = true;
    }
    function withdrawalAuction(address _tokenAddress, uint _tokenId) internal virtual {
        activeAuction[_tokenAddress][_tokenId] = false;
    }
    function escowAuctionCheck(address _tokenAddress, uint _tokenId) internal view returns(bool){
       return activeAuction[_tokenAddress][_tokenId];
    }
    function transferEscowRequest(address _tokenAddress, uint _tokenId) internal virtual {
        activeRequest[_tokenAddress][_tokenId] = true;
    }
    function withdrawalRequest(address _tokenAddress, uint _tokenId) internal virtual {
        activeRequest[_tokenAddress][_tokenId] = false;
    }
    function escowRequestCheck(address _tokenAddress, uint _tokenId) internal view returns(bool){
       return activeRequest[_tokenAddress][_tokenId];
    }
}
// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


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

// File: contracts/marketplace/interfaces/IMarketplace.sol


pragma solidity ^0.8.0;

interface IMarketplace {

    event MarketTransaction(uint8 TxType, address new_owner, uint indexed tokenId, uint indexed itemId, address indexed tokenAddress, address owner, uint price, bool isSold);
    event MarketResell(uint indexed tokenId, uint indexed itemId,address indexed tokenAddress, address owner, uint old_price, uint new_price, bool isSold);
    event AuctionTransaction(uint8 TxType, uint indexed tokenId, uint indexed itemId, address indexed tokenAddress, uint highprice, address highestbidder, uint auctionEndTime, bool end);
    event TransactionTransfer(uint8 TxType, address to, uint value, uint indexed tokenId,address indexed tokenAddress);
    event AuctionWithdraw(address receiver, uint amount);

    function getOffer(uint _tokenId, address _tokenAddress) external view returns ( address seller, address owners, uint price,uint price_fee, uint index, uint tokenId, address tokenAddress, bool isSold);
    function addTokentoMarket(uint _tokenId, address _tokenAddress, uint _price) external;
    function buyArtwork (uint _tokenId, address _tokenAddress, address _receiver) external payable;
}
// File: contracts/royalties/contracts/LibRoyaltiesV2.sol



pragma solidity >=0.6.2 <0.9.0;

library LibRoyaltiesV2 {
    /*
     * bytes4(keccak256('getRaribleV2Royalties(uint256)')) == 0xcad96cca
     */
    bytes4 constant _INTERFACE_ID_ROYALTIES = 0xcad96cca;
}

// File: contracts/royalties/contracts/LibPart.sol



pragma solidity >=0.6.2 <0.9.0;

library LibPart {
    bytes32 public constant TYPE_HASH = keccak256("Part(address account,uint96 value)");

    struct Part {
        address payable account;
        uint96 value;
    }

    function hash(Part memory part) internal pure returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, part.account, part.value));
    }
}

// File: contracts/royalties/contracts/RoyaltiesV2.sol



pragma solidity >=0.6.2 <0.9.0;
pragma abicoder v2;


interface RoyaltiesV2 {
    event RoyaltiesSet(uint256 tokenId, LibPart.Part[] royalties);

    function getRaribleV2Royalties(uint256 id) external view returns (LibPart.Part[] memory);
}

// File: contracts/royalties/contracts/impl/AbstractRoyalties.sol



pragma solidity >=0.6.2 <0.9.0;


abstract contract AbstractRoyalties {
    mapping (uint256 => LibPart.Part[]) internal royalties;

    function _saveRoyalties(uint256 id, LibPart.Part[] memory _royalties) internal {
        uint256 totalValue;
        for (uint i = 0; i < _royalties.length; i++) {
            require(_royalties[i].account != address(0x0), "Recipient should be present");
            require(_royalties[i].value != 0, "Royalty value should be positive");
            totalValue += _royalties[i].value;
            royalties[id].push(_royalties[i]);
        }
        require(totalValue < 10000, "Royalty total value should be < 10000");
        _onRoyaltiesSet(id, _royalties);
    }

    function _updateAccount(uint256 _id, address _from, address _to) internal {
        uint length = royalties[_id].length;
        for(uint i = 0; i < length; i++) {
            if (royalties[_id][i].account == _from) {
                royalties[_id][i].account = payable(_to);
            }
        }
    }

    function _onRoyaltiesSet(uint256 id, LibPart.Part[] memory _royalties) virtual internal;
}

// File: contracts/royalties/contracts/impl/RoyaltiesV2Impl.sol



pragma solidity >=0.6.2 <0.9.0;
contract RoyaltiesV2Impl is AbstractRoyalties, RoyaltiesV2 {

    function getRaribleV2Royalties(uint256 id) override external view returns (LibPart.Part[] memory) {
        return royalties[id];
    }

    function _onRoyaltiesSet(uint256 id, LibPart.Part[] memory _royalties) override internal {
        emit RoyaltiesSet(id, _royalties);
    }
}

// File: @openzeppelin/contracts/utils/Counters.sol


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

// File: @openzeppelin/contracts/access/IAccessControl.sol


// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// File: @openzeppelin/contracts/utils/Strings.sol


// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// File: @openzeppelin/contracts/utils/Context.sol


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

// File: @openzeppelin/contracts/utils/Address.sol


// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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
                /// @solidity memory-safe-assembly
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

// File: @openzeppelin/contracts/proxy/utils/Initializable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;


/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!Address.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }
}

// File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol


// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

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

// File: @openzeppelin/contracts/utils/introspection/ERC165.sol


// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;


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

// File: @openzeppelin/contracts/utils/introspection/ERC165Storage.sol


// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165Storage.sol)

pragma solidity ^0.8.0;


/**
 * @dev Storage based implementation of the {IERC165} interface.
 *
 * Contracts may inherit from this and call {_registerInterface} to declare
 * their support of an interface.
 */
abstract contract ERC165Storage is ERC165 {
    /**
     * @dev Mapping of interface ids to whether or not it's supported.
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId) || _supportedInterfaces[interfaceId];
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
}

// File: @openzeppelin/contracts/access/AccessControl.sol


// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;





/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// File: contracts/marketplace/ControlNode.sol


pragma solidity ^0.8.0;


/** this is for managing gas system and control/admin roles
 */
contract ControlNode is AccessControl, Initializable{
    bytes32 public constant STAFF_ROLE = keccak256("STAFF_ROLE");
    bytes32 public constant TOP_ROLE = keccak256("TOP_ROLE");
    address payable multisig_wallet;
    
    constructor() initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(STAFF_ROLE, msg.sender);
    }
    function initialize() initializer public {}
    function register(address _address) public onlyRole(DEFAULT_ADMIN_ROLE){
        require(hasRole(STAFF_ROLE, _address) == false, "Already");
        _grantRole(STAFF_ROLE, _address);
    }
    function deregister(address _address) public onlyRole(DEFAULT_ADMIN_ROLE){
        require(hasRole(STAFF_ROLE, _address) == true, "!inlist");
        _revokeRole(STAFF_ROLE, _address);
    }
    function setupWallet(address _wallet) public onlyRole(DEFAULT_ADMIN_ROLE){
        multisig_wallet = payable(_wallet);
    }
    function getWallet() public view returns(address){
        return multisig_wallet;
    }
}
// File: contracts/marketplace/Fee.sol


pragma solidity ^0.8.0;

contract Fee is ControlNode{
    uint listFee;
    event ChangeFee(uint old_price, uint new_price);

    function setFee(uint _price) onlyRole(STAFF_ROLE) public {
        uint old_fee = listFee;
        emit ChangeFee(old_fee, _price);
        listFee=_price;
    }
    function getFee() public view returns(uint){
        return listFee;
    }
}
// File: contracts/Wallet/ArtscapeWallet.sol


pragma solidity ^0.8.0;
contract ArtscapeWallet is AccessControl {
    uint limit;
    uint private counter;
    bytes32 public constant WHITELIST_ROLE = keccak256("WHITELIST_ROLE");
    
    struct Transfer{
        uint amount;
        address payable receiver;
        uint approvals;
        bool hasBeenSent;
        uint id;
    }
    
    Transfer[] public transferRequests;
    
    mapping(address => mapping(uint => bool)) public approvals;
    
    event TransferTransaction(address request, address receiver, uint amount,uint id, bool hasBeenSent);
    event Approved(address aprover, uint id);

    constructor(uint _limit) {
        require(_limit > 0, "The limit must be more that 0 ");
        limit = _limit;
        counter = 0;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(WHITELIST_ROLE, msg.sender);
    }
    function deposit() public payable returns(bool){ return true;}
    function register(address _address) public onlyRole(DEFAULT_ADMIN_ROLE){
        require(hasRole(WHITELIST_ROLE, _address) == false, "already have role");
        _grantRole(WHITELIST_ROLE, _address);
    }
    function deregister(address _address) public onlyRole(DEFAULT_ADMIN_ROLE){
        require(hasRole(WHITELIST_ROLE, _address) == true, "Not in the list");
        _revokeRole(WHITELIST_ROLE, _address);
    }
    function getTotalBalance() public view returns(uint){
        return address(this).balance;
    }
    function getlimit() public view returns(uint){
        return limit;
    }
    function setNewLimit(uint _nlimit) public onlyRole(DEFAULT_ADMIN_ROLE){
        limit = _nlimit;
    }
    //Create an instance of the Transfer struct and add it to the transferRequests array
    function createTransfer(uint _amount, address payable _receiver) public onlyRole(WHITELIST_ROLE) {
        require(_amount<=address(this).balance, "exceed balance");
        Transfer memory _transfer = Transfer({
            amount: _amount,
            receiver: payable(_receiver),
            approvals: 0,
            hasBeenSent: false,
            id:counter
        });
        transferRequests.push(_transfer);
        approve(counter);
        counter++;
        emit TransferTransaction(msg.sender, _receiver, _amount, counter-1, false);
    }

    function approve(uint _id) public onlyRole(WHITELIST_ROLE) {
        require(approvals[msg.sender][_id]==false," you already vote");
        require(transferRequests[_id].hasBeenSent == false,"Already approved!");
        Transfer storage _transfer = transferRequests[_id];
        if(_transfer.approvals < limit)
        {
            _transfer.approvals++;
            approvals[msg.sender][_id] = true;
            emit Approved(msg.sender, _id);
        }
        if(_transfer.approvals == limit){
            payable(_transfer.receiver).transfer(_transfer.amount);
            _transfer.hasBeenSent = true;
            emit TransferTransaction(address(this), _transfer.receiver, _transfer.amount, _transfer.id, true);
        }
    }
    function getTransferRequests() public view returns (Transfer[] memory){
        Transfer[] memory _tran = new Transfer[](transferRequests.length);
        for(uint i =0; i<transferRequests.length; i++)
        {
            _tran[i] = transferRequests[i];
        }
        return _tran;
    }    
}
// File: @openzeppelin/contracts/token/ERC721/IERC721.sol


// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;


/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
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
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

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
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// File: @openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;


/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// File: @openzeppelin/contracts/token/ERC721/ERC721.sol


// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;








/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// File: @openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol


// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/extensions/ERC721URIStorage.sol)

pragma solidity ^0.8.0;


/**
 * @dev ERC721 token with storage based token URI management.
 */
abstract contract ERC721URIStorage is ERC721 {
    using Strings for uint256;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev See {ERC721-_burn}. This override additionally checks to see if a
     * token-specific URI was set for the token, and if so, it deletes the token URI from
     * the storage mapping.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
}

// File: contracts/tokens/Artscape721.sol


pragma solidity ^0.8.2;










contract Artscape721 is ERC721, ERC721URIStorage,ERC165Storage, AccessControl, RoyaltiesV2Impl  {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    address contractAddress; 
    address[] artists;
    bytes description;
    string public link;
    uint8 percent;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    
    event ArtscapeMint (address owner, uint tokenId, string metadata, string time);
    event Royalties(address owner, uint tokenId, address artist, uint96 _percentageBasisPoints);
    
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address marketplaceAddress, string memory collectionS, string memory collectionN, address _artist, string memory _link,uint8 _percent) ERC721(collectionN, collectionS) {
        _initialize();
        contractAddress = marketplaceAddress;
        link = _link;
        percent = _percent;
        artists.push(_artist);
        _registerInterface(_INTERFACE_ID_ERC721);
        _registerInterface(_INTERFACE_ID_ERC2981);
        _registerInterface(LibRoyaltiesV2._INTERFACE_ID_ROYALTIES);
    }

    function _initialize() internal{
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }
    function safeMint(address to, string memory uri, string memory time) public onlyRole(MINTER_ROLE) returns(uint){
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        setApprovalForAll(contractAddress, true);
        setRoyalties(tokenId, payable(artists[0]), uint96(uint96(percent)*100));
        emit ArtscapeMint(msg.sender, tokenId, uri, time);
        return tokenId;
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    function setRoyalties(uint _tokenId, address payable _royaltiesReceipientAddress, uint96 _percentageBasisPoints) public onlyRole(MINTER_ROLE) {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _percentageBasisPoints;
        _royalties[0].account = _royaltiesReceipientAddress;
        _saveRoyalties(_tokenId, _royalties);
        emit Royalties(msg.sender, _tokenId, _royalties[0].account, _percentageBasisPoints);
    }
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC165Storage, AccessControl)
        returns (bool)
    {
        if(interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES || interfaceId == _INTERFACE_ID_ERC2981 || interfaceId == _INTERFACE_ID_ERC721) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    }
    function totalSupply() public view returns(uint256){
        return _tokenIdCounter.current();
    }
    function setDescription(string memory desp) public onlyRole(MINTER_ROLE){
        description = bytes(desp);
    }
    function getDescription() public view returns(string memory){
        return string(description);
    }
    function getArtist() public view returns(address[] memory){
        return artists;
    }
    function addArtist(address _artist) public onlyRole(MINTER_ROLE){
        artists.push(_artist);
    }
}

// File: contracts/marketplace/Request.sol


pragma solidity ^0.8.0;





contract Request is ReentrancyGuard,Initializable{
    using Counters for Counters.Counter;
    address payable owners;
    address payable buyer;
    address market;
    address payable wallet_market;
    uint price;
    uint tokenId;
    address tokenAddress;
    bool private isComplete;

    constructor(address payable _owner, address payable _buyer, address _market,address payable _wmarket, uint _price, uint _tokenId, address _tokenAddress)initializer{
        require (Artscape721(_tokenAddress).ownerOf(_tokenId) != _market, "Token is already up on sale");
        require(Artscape721(_tokenAddress).ownerOf(_tokenId) != tx.origin, "You are owner");
        require (_price > 0, "Price must be higher than 1 Wei");
        owners = _owner;
        buyer = _buyer;
        market = _market;
        wallet_market = _wmarket;
        price = _price;
        tokenId = _tokenId;
        tokenAddress = _tokenAddress;
        isComplete = false;
    }
    function getDetail() public view returns(address, address, address, address,address, uint, uint, bool){
        return (owners, buyer, market, wallet_market, tokenAddress, tokenId, price, isComplete);
    }
    function getOwner() public view returns(address){
        return owners;
    }
    function getBuyer() public view returns(address){
        return buyer;
    }
    function getTokenAddress() public view returns(address){
        return tokenAddress;
    }
    function getTokenId() public view returns(uint){
        return tokenId;
    }
    function getPrice() public view returns(uint){
        return price;
    }
    function available() public view returns(bool){
        return !isComplete;
    }
    function completed() external nonReentrant{
        require((tx.origin == owners || tx.origin == market), "!Owner|Market");
        isComplete = true;
    }
    function rejected() external nonReentrant{
        require((tx.origin == owners || tx.origin == market), "!Owner|Market");
        isComplete = true;
    }
}
// File: contracts/marketplace/Offer.sol


pragma solidity ^0.8.0;





contract Offer is EscowVault, Fee, ReentrancyGuard{
    using Counters for Counters.Counter;
    Counters.Counter public _itemIds;
    Counters.Counter public _itemSold;
    struct Items {
        uint itemId;
        address payable owners;
        address payable seller;
        uint price;
        uint tokenId;
        address tokenAddress;
        bool isSold;
        bool isAuction;
    }
    mapping(address=> mapping(uint=>  Items)) public nft2Item;
    event ChangePrice(uint indexed itemId, uint indexed tokenId, uint old_price, uint new_price);
    event ChangeOwner(uint indexed itemId, uint indexed tokenId, address new_owner, address old_owner);

    function createSellItems(uint _tokenId, address _tokenAddress, uint _price) public returns(uint) {
    //     //to resell owner need to setApprovalForAll to marketplaceAddress
        require (Artscape721(_tokenAddress).ownerOf(_tokenId) == msg.sender, "MustBowner");
        require (activeSell[_tokenAddress][_tokenId]==false, "OnSale");
        require (_price > 0, "must>1Wei");
        uint newTokenId = _itemIds.current();
        Items memory _Items = Items({
            seller: payable(msg.sender),
            price: _price,
            isSold: false,
            tokenId: _tokenId,
            tokenAddress: _tokenAddress,
            itemId: newTokenId,
            owners: payable(address(0)),
            isAuction: false
        }
            );
        nft2Item[_tokenAddress][_tokenId] = _Items;
        transferEscowOnSell(_tokenAddress,_tokenId);
        Artscape721(_tokenAddress).transferFrom(msg.sender, address(this), _tokenId);
        _itemIds.increment(); 
        return newTokenId;
    }
     function reTokentoMarket(uint _tokenId, address _tokenAddress, uint _price)internal returns(uint) {
        require (_price > 0, "must > 1 Wei");
        require (Artscape721(_tokenAddress).ownerOf(_tokenId) == msg.sender, "MustBowner");
        require (nft2Item[_tokenAddress][_tokenId].owners != address(0), "NotOnM");
        Items memory _Items = Items({
            seller: payable(msg.sender),
            price: _price,
            isSold: false,
            tokenId: _tokenId,
            tokenAddress: _tokenAddress,
            itemId: nft2Item[_tokenAddress][_tokenId].itemId,
            owners: payable(address(0)),
            isAuction: false
        }
            );
        nft2Item[_tokenAddress][_tokenId] = _Items;
        transferEscowOnSell(_tokenAddress,_tokenId);
        Artscape721(_tokenAddress).transferFrom(msg.sender, address(this), _tokenId);
        return nft2Item[_tokenAddress][_tokenId].itemId;
    }
    function changePrice(uint _tokenId, address _tokenAddress, uint _nprice) public virtual{
        require(nft2Item[_tokenAddress][_tokenId].seller == msg.sender, "!seller");
        uint old_price = nft2Item[_tokenAddress][_tokenId].price;
        nft2Item[_tokenAddress][_tokenId].price = _nprice;
        emit ChangePrice(nft2Item[_tokenAddress][_tokenId].itemId, nft2Item[_tokenAddress][_tokenId].tokenId, old_price, nft2Item[_tokenAddress][_tokenId].price);    
    }
    function changeOwner(uint _tokenId, address _tokenAddress, address _nowner) public virtual{
    //     Items memory Items = tokenIdToItems[_tokenAddress][_tokenId];
        require(nft2Item[_tokenAddress][_tokenId].seller == msg.sender, "!seller");
        nft2Item[_tokenAddress][_tokenId].owners = payable(_nowner);
        emit ChangeOwner(nft2Item[_tokenAddress][_tokenId].itemId, nft2Item[_tokenAddress][_tokenId].tokenId, _nowner, nft2Item[_tokenAddress][_tokenId].owners);    
    }
    function cancel(uint _tokenId, address _tokenAddress) public virtual{
        require(nft2Item[_tokenAddress][_tokenId].seller == msg.sender, "!seller");
        Artscape721(_tokenAddress).transferFrom(address(this), msg.sender, _tokenId); 
        nft2Item[_tokenAddress][_tokenId].owners = payable(msg.sender);
        nft2Item[_tokenAddress][_tokenId].isSold = true;
        withdrawalSell(_tokenAddress, _tokenId);
        emit ChangeOwner(nft2Item[_tokenAddress][_tokenId].itemId, nft2Item[_tokenAddress][_tokenId].tokenId, msg.sender, address(0x0));    
    }
    function setStatusAuction(uint _tokenId, address _tokenAddress, uint _price) internal virtual{
        //TODO: Setup Auction Offer
        uint newTokenId = _itemIds.current();
        Items memory _Items = Items({
            seller: payable(msg.sender),
            price: _price,
            isSold: false,
            tokenId: _tokenId,
            tokenAddress: _tokenAddress,
            itemId: newTokenId,
            owners: payable(address(0)),
            isAuction: true
        }
            );
        nft2Item[_tokenAddress][_tokenId] = _Items;
        transferEscowAuction(_tokenAddress,_tokenId);
        Artscape721(_tokenAddress).transferFrom(msg.sender, address(this), _tokenId);
        _itemIds.increment(); 
    }
}
// File: contracts/marketplace/AuctionV1.sol


pragma solidity ^0.8.0;







contract AuctionV1 is ReentrancyGuard{
    address payable beneficial;
    uint auctionEndTime;
    address highestBidder;
    uint highestBid;
    uint tokenid;
    address tokenAddress;
    address owner_address;
    address payable market;
    uint fee;

    mapping(address => uint)public pendingReturns;
    address[] public participant;
    
    bool ended = false;
    event HighestBidderIncrease(address bidder, uint amount);
    event AuctionsEnd(address winner, uint amount);
    event AuctionDetail(uint biddingTime, address beneficial, uint start_price, uint tokenId, address tokenAddress);
    event AuctionWithdraw(address receiver, uint amount);
    event AuctionSend(address reveiver, uint amount);

    constructor(uint _biddingTime, address payable _owner, uint _start, uint _tokenId, address _tokenAddress, address multisig, uint _fee) {
        beneficial = _owner;
        highestBid = _start;
        tokenid = _tokenId;
        tokenAddress = _tokenAddress;
        auctionEndTime = block.timestamp + _biddingTime;
        owner_address = payable(multisig);
        market = payable(msg.sender);
        fee = _fee;
        emit AuctionDetail(auctionEndTime, beneficial, _start, _tokenId, _tokenAddress);
    }
    function bid() external payable{
        require(block.timestamp < auctionEndTime,"Ended");
        require(msg.value > highestBid,"MustBHigher");
        require(tx.origin != highestBidder,"!overbid");
        if(highestBid != 0){
            pendingReturns[highestBidder] += highestBid;}
        highestBidder = msg.sender;
        highestBid = msg.value;
        emit HighestBidderIncrease(msg.sender, msg.value);
        if(pendingReturns[highestBidder] == 0){
            participant.push(highestBidder);
        }

    }
    function bid(address _sender) external payable{
        require(block.timestamp < auctionEndTime,"Ended");
        require(msg.value > highestBid,"MustBHigher");
        require(tx.origin != highestBidder,"!overbid");
        if(highestBid != 0){pendingReturns[highestBidder] += highestBid;}
        highestBidder = _sender;
        highestBid = msg.value;
        emit HighestBidderIncrease(_sender, msg.value);
        if(pendingReturns[highestBidder] == 0){
            participant.push(highestBidder);
        }
    }
    function withdrawal() public nonReentrant returns (bool){
        uint amount = pendingReturns[msg.sender];
        require(amount > 0, "must>0");
        pendingReturns[msg.sender] = 0;
        if(!payable(msg.sender).send(amount)){
            pendingReturns[msg.sender] = amount;
            return false;
        }
        emit AuctionWithdraw(msg.sender, amount);
        return true;
    }
    function auctionTimeNow() external view returns(uint){
        return block.timestamp;
    }
    function withdrawal(address _address) public nonReentrant returns (bool){
        uint amount = pendingReturns[_address];
        require(amount > 0, "must>0");
        pendingReturns[_address] = 0;
        if(!payable(_address).send(amount)){
            pendingReturns[_address] = amount;
            return false;
        }
        emit AuctionWithdraw(_address, amount);
        return true;
    }
    function auctionEnd() public returns(bool){
        //require(block.timestamp >= auctionEndTime, "The auction is not ended yet");
        require(tx.origin==this.getTokenOwner(), "!allow");
        require(!ended,"Ended");
        if(address(this).balance != 0){
            _auctionEnd();     
            return ended;
        }else{
            ended=true;
            return ended;
        }
        
    }
    function checkReturn() external view returns(uint){
        return pendingReturns[msg.sender];
    }
    function _auctionEnd() internal{
        address _royalty = this.getRoyaltyAddress();
        uint royalty_price;
        uint price_send; 
        uint get_fee = this.getFeePrice();
        royalty_price = this.getRoyaltyPrice();
        price_send = this.getHighestBid()-get_fee-royalty_price;
        if(highestBid > 0){
            if(get_fee > 0){
                ArtscapeWallet(owner_address).deposit{value:get_fee}();
                emit AuctionSend(owner_address, get_fee); 
            }
            if(royalty_price > 0){
                price_send = highestBid-get_fee-royalty_price;
                (bool sent, ) = beneficial.call{value: price_send}("");
                require(sent, "FailedB");
                emit AuctionSend(beneficial, price_send); 
                (bool sent2, ) = payable(_royalty).call{value: royalty_price}("");
                require(sent2, "FailedRY");
                emit AuctionSend( _royalty, royalty_price); 
            }else{
                price_send = highestBid-get_fee;
                (bool sent, ) =  beneficial.call{value: price_send}("");
                require(sent, "FailedF");
                emit AuctionSend(beneficial, price_send); 
            }
        }
        
        ended = true;
        pendingReturns[highestBidder] = 0;
        for(uint i = 0; i < participant.length; i++){
            if(pendingReturns[participant[i]]!=0){
                withdrawal(participant[i]);
            }
        }
    }
    function getTotalBalance() public view returns(uint){
        return address(this).balance;
    }
    function getHighestBid() external view returns(uint){
        return highestBid;
    }
    function getHighestBidder() external view returns(address){
        return highestBidder;
    }
    function getEndTime() external view returns(uint){
        return auctionEndTime;
    }
    function isEnd() external view returns(bool){
        return ended;
    }
    function getTokenOwner() external view returns(address){
        return beneficial;
    }
    function getRoyaltyPercent()external view returns(uint){
        uint _percent;
        (, _percent) = _getRoyaltyData(tokenid, tokenAddress);
        return _percent;
    } 
    function getRoyaltyAddress()external view returns(address){
        address _royalty;
        (_royalty,) = _getRoyaltyData(tokenid, tokenAddress);
        return _royalty;
    } 
    function getFeePrice()external view returns(uint){
        return highestBid*fee/100;
    } 
    function getRoyaltyPrice()external view returns(uint){
        return ((highestBid-this.getFeePrice())*this.getRoyaltyPercent())/10000;
    } 
    function _getRoyaltyData(uint _tokenId, address _tokenAddress) internal view returns (address artist, uint percent){
        address _address;
        uint _percent;
        if(Artscape721(_tokenAddress).getRaribleV2Royalties(_tokenId).length != 0){
            _address = Artscape721(_tokenAddress).getRaribleV2Royalties(_tokenId)[0].account;
            _percent = Artscape721(_tokenAddress).getRaribleV2Royalties(_tokenId)[0].value;
        }
        return (_address, _percent);
    }
}
// File: contracts/marketplace/MarketAuction.sol


pragma solidity ^0.8.0;







contract MarketAuction is ReentrancyGuard, Offer{
    using Counters for Counters.Counter;
    Counters.Counter public _aucIds;
    address wallet;

    mapping(address => mapping(uint=> address)) public nft2Auction;
    address[] auctionList;
    event AuctionTransaction(uint8 TxType, uint indexed tokenId, address indexed tokenAddress, address auction,uint highprice, address highestbidder, uint auctionEndTime, bool end);
    
    function setAuctionV1(uint _biddingTime, uint _tokenId, address _tokenAddress, uint start_price) public{
        require (Artscape721(_tokenAddress).ownerOf(_tokenId) == msg.sender, "!Owner");
        require (activeSell[_tokenAddress][_tokenId]==false, "OnSale");
        require (activeAuction[_tokenAddress][_tokenId]==false, "On");
        setStatusAuction(_tokenId,_tokenAddress,start_price);
        AuctionV1 auction = new AuctionV1(_biddingTime, payable(msg.sender) ,start_price, _tokenId, _tokenAddress, wallet, getFee());
        nft2Auction[_tokenAddress][_tokenId] = address(auction);
        auctionList.push(address(auction));
        transferEscowAuction(_tokenAddress,_tokenId);
        _aucIds.increment();
        emit AuctionTransaction(1, _tokenId, _tokenAddress, address(auction),  AuctionV1(nft2Auction[_tokenAddress][_tokenId]).getHighestBid(),AuctionV1(nft2Auction[_tokenAddress][_tokenId]).getHighestBidder(), AuctionV1(nft2Auction[_tokenAddress][_tokenId]).getEndTime(), false);
    }
    function setupW(address _mul)internal{
        wallet = _mul;
    }

    function bid(address _tokenAddress, uint _tokenId ) public payable {
        require(nft2Auction[_tokenAddress][_tokenId]!= address(0x0), "!Auction");
        require(tx.origin != this.getHighestBidder(_tokenAddress,_tokenId), "overBid");
        AuctionV1(nft2Auction[_tokenAddress][_tokenId]).bid{value: msg.value}(tx.origin);
        emit AuctionTransaction(2, _tokenId, _tokenAddress, nft2Auction[_tokenAddress][_tokenId], AuctionV1(nft2Auction[_tokenAddress][_tokenId]).getHighestBid(),AuctionV1(nft2Auction[_tokenAddress][_tokenId]).getHighestBidder(), AuctionV1(nft2Auction[_tokenAddress][_tokenId]).getEndTime(), false);
    }
    function end(address _tokenAddress, uint _tokenId) public{
        require(activeAuction[_tokenAddress][_tokenId] == true,"!avai");
        require(AuctionV1(nft2Auction[_tokenAddress][_tokenId]).isEnd()==false, "!end");
        AuctionV1 auctionContract = AuctionV1(nft2Auction[_tokenAddress][_tokenId]);
        _sendToken(_tokenAddress,_tokenId,auctionContract.getHighestBidder());
        AuctionV1(nft2Auction[_tokenAddress][_tokenId]).auctionEnd();
        withdrawalAuction(_tokenAddress,_tokenId);
        delete(nft2Auction[_tokenAddress][_tokenId]);
        emit AuctionTransaction(3, _tokenId, _tokenAddress, nft2Auction[_tokenAddress][_tokenId], auctionContract.getHighestBid(),auctionContract.getHighestBidder(),auctionContract.getEndTime(), true);
    }
    function _sendToken(address _tokenAddress, uint _tokenId, address _receiver) internal{
        Artscape721(_tokenAddress).transferFrom(address(this), _receiver,_tokenId);
    }
    function getHighestBid(address _tokenAddress, uint _tokenId) public view returns(uint highestbid) {
        require(nft2Auction[_tokenAddress][_tokenId] != address(0x0), "!Auction");
        return AuctionV1(nft2Auction[_tokenAddress][_tokenId]).getHighestBid();
    }
    function getHighestBidder(address _tokenAddress, uint _tokenId) public view returns(address highestbidder) {
        require(nft2Auction[_tokenAddress][_tokenId] != address(0x0), "!Auction");
        return AuctionV1(nft2Auction[_tokenAddress][_tokenId]).getHighestBidder();
    }
    function getTotalAuction() public view returns(uint){
        return _aucIds.current();
    }
    function getAuctionDetail(address _tokenAddress, uint _tokenId) public view returns(bool is_end, address highestBidder, uint highestBid, address owner, uint EndTime){
        AuctionV1 auction = AuctionV1(nft2Auction[_tokenAddress][_tokenId]);
        return (auction.isEnd(), auction.getHighestBidder(), auction.getHighestBid(), auction.getTokenOwner(), auction.getEndTime());
    }
}
// File: contracts/marketplace/VoucherV1.sol


pragma solidity ^0.8.0;





contract VoucherV1 is ReentrancyGuard, Initializable{
    address payable beneficial;
    address payable receiver;
    address market;
    address payable market_wallet;
    uint public tokenId;
    uint price;
    address public tokenAddress;
    uint public marketFee;
    bool isWithdraw;
    
    modifier isOwner(){
        require(msg.sender == beneficial, "!owner");
        _;
    }
    modifier isReceiver(){
        require(msg.sender == receiver || msg.sender == market , "!allow");
        _;
    }
    event voucherEvent(string TxType, address indexed owner, address receiver,address market,address wallet_market, address indexed tokenAddress, uint indexed tokenId, uint price);
    event moneySend(address reveiver, uint amount);

    constructor(address payable _beneficial, address payable _receiver, address _market,address payable _mwallet, uint _tokenId, address _tokenAddress, uint _price) initializer {
        beneficial = _beneficial;
        receiver = _receiver;
        market = _market;
        market_wallet = _mwallet;
        tokenId = _tokenId;
        price = _price;
        tokenAddress = _tokenAddress;
        isWithdraw = false;
        Artscape721(_tokenAddress).setApprovalForAll(_market, true);
        emit voucherEvent("Create", beneficial, receiver, market,market_wallet, tokenAddress, tokenId, price);
    }
    function withdrawal() isReceiver() public payable{
        require(Artscape721(tokenAddress).ownerOf(tokenId) == address(this), "Token!Here");
        require(isWithdraw == false, "AlreadyWithdrawal");
        require(msg.sender == this.getBuyer(), "NotAllow");
        require(msg.value == this.getPrice(),"!price");
        _transfer();
        Artscape721(tokenAddress).transferFrom(address(this), receiver, tokenId);
        isWithdraw = true;
        emit voucherEvent("Withdrawal", beneficial, receiver, market,market_wallet, tokenAddress, tokenId, price);
    }
    function _transfer() internal{
        address _royalty = this.getRoyaltyAddress();
        uint royalty_price;
        uint price_send; 
        uint get_fee = this.getFeePrice();
        royalty_price = this.getRoyaltyPrice();
        price_send = price-get_fee-royalty_price;
        if(get_fee > 0){
            ArtscapeWallet(market_wallet).deposit{value:get_fee}();
            emit moneySend(market_wallet, get_fee); 
        }
        if(royalty_price > 0){
            price_send = price-get_fee-royalty_price;
            payable(beneficial).transfer(price_send);
            emit moneySend(beneficial, price_send); 
            payable(_royalty).transfer(royalty_price);
            emit moneySend( _royalty, royalty_price); 
        }else{
            price_send = price-get_fee;
            payable(beneficial).transfer(price_send);
            emit moneySend(beneficial, price_send); 
            }
        emit voucherEvent("Transfer", beneficial, receiver, market, market_wallet, tokenAddress, tokenId, price);
        
    }
    function getDetail() public view returns(address, address, address, uint, address, uint, uint){
        return (beneficial, receiver, market, marketFee, tokenAddress, tokenId, price);
    }
    function getBuyer() public view returns(address){
        return receiver;
    }
    function getOwner() public view returns(address){
        return beneficial;
    }
    function getTokenAddress() public view returns(address){
        return tokenAddress;
    }
    function getTokenId() public view returns(uint){
        return tokenId;
    }
    function getPrice() public view returns(uint){
        return price;
    }
    function available() public view returns(bool){
        return !isWithdraw;
    }
    function getTokenOwner() external view returns(address){
        return beneficial;
    }
    function getRoyaltyPercent()external view returns(uint){
        uint _percent;
        (, _percent) = _getRoyaltyData(tokenId, tokenAddress);
        return _percent;
    } 
    function getRoyaltyAddress()external view returns(address){
        address _royalty;
        (_royalty,) = _getRoyaltyData(tokenId, tokenAddress);
        return _royalty;
    } 
    function getFeePrice()external view returns(uint){
        return price*marketFee/100;
    } 
    function getRoyaltyPrice()external view returns(uint){
        return ((price-this.getFeePrice())*this.getRoyaltyPercent())/10000;
    } 
    function _getRoyaltyData(uint _tokenId, address _tokenAddress) internal view returns (address artist, uint percent){
        address _address;
        uint _percent;
        if(Artscape721(_tokenAddress).getRaribleV2Royalties(_tokenId).length != 0){
            _address = Artscape721(_tokenAddress).getRaribleV2Royalties(_tokenId)[0].account;
            _percent = Artscape721(_tokenAddress).getRaribleV2Royalties(_tokenId)[0].value;
        }
        return (_address, _percent);
    }
}
// File: contracts/marketplace/MarketRequest.sol


pragma solidity ^0.8.0;






contract MarketRequest is IRequest, EscowVault,Initializable{
    using Counters for Counters.Counter;
    address market;
    address payable wallet_market;
    Counters.Counter public _reqIds;
    mapping(address => mapping(uint=> mapping(address=> address))) public address2Request;
    mapping(address => mapping(uint=> address[])) public nft2Request;
    mapping(address => mapping(uint=> address)) public tokenId2Accept;
    event Response(bool success, bytes data);

    constructor(
        address payable _wallet_address,
        address _market
    ){
        market = _market;
        wallet_market = _wallet_address;
    }

    function initialize() initializer public {}
    function createRequest(uint _tokenId, address _tokenAddress, uint _price) override external returns(address){
        require(Artscape721(_tokenAddress).ownerOf(_tokenId) !=  msg.sender, "must!owner");
        if(_price < 0){revert();}
        if(activeSell[_tokenAddress][_tokenId]){revert("AOS");}
        Request _reqcontract= new Request(payable(Artscape721(_tokenAddress).ownerOf(_tokenId)), payable( msg.sender), market,payable(wallet_market), _price, _tokenId, _tokenAddress);
        address2Request[_tokenAddress][_tokenId][msg.sender] = address(_reqcontract);
        nft2Request[_tokenAddress][_tokenId].push(address(_reqcontract));
        emit RequestTx(0, Artscape721(_tokenAddress).ownerOf(_tokenId), msg.sender, address(_reqcontract), address(0), _tokenId, _tokenAddress, _price, false);
        _reqIds.increment();
        return address(_reqcontract);
    }
   function acceptRequest(address _requestAddress) external override{
        Request _reqcontract = Request(_requestAddress);
        require( msg.sender == _reqcontract.getOwner(), "!token_owner");
        VoucherV1 vouchers = new VoucherV1(payable(_reqcontract.getOwner()),payable(_reqcontract.getBuyer()),market,payable(wallet_market), _reqcontract.getTokenId(),_reqcontract.getTokenAddress(), _reqcontract.getPrice());
        tokenId2Accept[_reqcontract.getTokenAddress()][_reqcontract.getTokenId()] = address(vouchers);
        Artscape721(_reqcontract.getTokenAddress()).transferFrom(msg.sender, address(vouchers), _reqcontract.getTokenId());
        emit RequestTx(1, _reqcontract.getOwner(),_reqcontract.getBuyer(), _requestAddress,address(vouchers), _reqcontract.getTokenId(),_reqcontract.getTokenAddress(), _reqcontract.getPrice(), true);
        _reqcontract.completed();
    }
    function acceptRequest(uint _tokenId, address _tokenAddress, uint _index) external{
        Request _reqcontract = Request(nft2Request[_tokenAddress][_tokenId][_index]);
        require( msg.sender == _reqcontract.getOwner(), "!token_owner");
        VoucherV1 vouchers = new VoucherV1(payable(_reqcontract.getOwner()),payable(_reqcontract.getBuyer()),market,payable(wallet_market), _reqcontract.getTokenId(),_reqcontract.getTokenAddress(), _reqcontract.getPrice());
        tokenId2Accept[_reqcontract.getTokenAddress()][_reqcontract.getTokenId()] = address(vouchers);
        Artscape721(_reqcontract.getTokenAddress()).transferFrom(msg.sender, address(vouchers), _reqcontract.getTokenId());
        emit RequestTx(1, _reqcontract.getOwner(),_reqcontract.getBuyer(),nft2Request[_tokenAddress][_tokenId][_index],address(vouchers), _reqcontract.getTokenId(),_reqcontract.getTokenAddress(), _reqcontract.getPrice(), true);
        _reqcontract.completed();
    }
    function rejectedRequest(address _requestAddress) external override{
        Request _reqcontract = Request(_requestAddress);
        require( msg.sender == _reqcontract.getOwner(), "!token_owner");
        emit RequestTx(2, _reqcontract.getOwner(),_reqcontract.getBuyer(), _requestAddress,address(0), _reqcontract.getTokenId(),_reqcontract.getTokenAddress(), _reqcontract.getPrice(), true);
        _reqcontract.rejected();
    }

    function get_request(uint _tokenId, address _tokenAddress, uint _index) public view returns(address){
        return nft2Request[_tokenAddress][_tokenId][_index];
    }
    function voucher_detail(uint _tokenId, address _tokenAddress)public view returns(address, address, address, uint, address, uint, uint){
        VoucherV1 vouchers = VoucherV1(tokenId2Accept[_tokenAddress][_tokenId]);
        return vouchers.getDetail();
    }
}
// File: contracts/marketplace/ArtscapeMarket.sol


pragma solidity >=0.4.22 <0.15.0;









contract ArtscapeMarket is IMarketplace, Offer {
    using Counters for Counters.Counter;
    address payable owner;
    mapping(address=>mapping(uint=> bool))public activeTokens;
    mapping(address => mapping(uint=> address)) public tokenId2Auction;

    //TODO: optimizing by change modifier to private or internal function instead
    modifier OnlyTokenOwner(address _tokenAddress, uint _tokenId){
        Artscape721 tcontract = Artscape721(_tokenAddress);
        require(tcontract.ownerOf(_tokenId)==msg.sender);
        _;
    }
    // modifier TokenExist(address _tokenAddress,uint _tokenId){
    //     require(tokenIdToOffer[_tokenAddress][_tokenId].itemId+1 !=  0, "Could not find the token");
    //     _;
    // }
    modifier Is4Sale(address _tokenAddress,uint _tokenId){
        require(super.escowSellCheck(_tokenAddress,_tokenId), "Sold");
        _;
    }
    modifier IsSeller(address _tokenAddress,uint _tokenId){
        require(nft2Item[_tokenAddress][_tokenId].seller == msg.sender, "!seller");
        _;
    }
    modifier isAuction(address _tokenAddress,uint _tokenId){
        require(super.escowAuctionCheck(_tokenAddress, _tokenId), "!Auction");
        _;
    }
    modifier isHuman() {
        address _addr = msg.sender;
        uint256 _codeLength;

        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "!human");
        _;
    }
    function setup(address _owner) public onlyRole(STAFF_ROLE) {
        owner = payable(_owner);
    }

    function getOffer(uint _tokenId, address _tokenAddress) external view override 
    returns ( address seller, address owners, uint price, uint price_fee, uint index, uint tokenId, address tokenAddress, bool isSold){
        Items memory offer = nft2Item[_tokenAddress][_tokenId];
        uint fee = offer.price*getFee()/100;
        return (offer.seller, offer.owners, offer.price, fee, offer.itemId, offer.tokenId, offer.tokenAddress, offer.isSold);
    }
    /** 1. should be owner to do this 2.to reentry must new owner must setApprovalForAll to marketplace */
    function addTokentoMarket(uint _tokenId, address _tokenAddress, uint _price) nonReentrant override external {
        if(nft2Item[_tokenAddress][_tokenId].owners != address(0))
        {
            uint ItemId = reTokentoMarket(_tokenId,_tokenAddress,_price);
            emit MarketTransaction(3, msg.sender, _tokenId, ItemId, _tokenAddress, address(0), _price, false);
        }else{
        uint newItemId = createSellItems(_tokenId,_tokenAddress,_price);
        emit MarketTransaction(1, msg.sender, _tokenId, newItemId, _tokenAddress, address(0), _price, false);}
    }

    //TODO: TokenExist(_tokenAddress,_tokenId)
    function buyArtwork (uint _tokenId, address _tokenAddress, address _receiver) Is4Sale(_tokenAddress,_tokenId) isHuman() nonReentrant external payable override{
        require(msg.value == (nft2Item[_tokenAddress][_tokenId].price), "!price");
        require(msg.sender != nft2Item[_tokenAddress][_tokenId].seller, "!seller");
        require(_receiver != address(0x0), "!0x0");
        _buyArt(_tokenId,_tokenAddress,msg.value,nft2Item[_tokenAddress][_tokenId].price,nft2Item[_tokenAddress][_tokenId].seller);
        Artscape721(_tokenAddress).transferFrom(address(this), _receiver, _tokenId); 
        _itemSold.increment();
        activeTokens[_tokenAddress][_tokenId] = false;
        nft2Item[_tokenAddress][_tokenId].isSold = true;
        nft2Item[_tokenAddress][_tokenId].owners = payable(_receiver);
        emit MarketTransaction(2, _receiver,_tokenId,nft2Item[_tokenAddress][_tokenId].itemId,_tokenAddress, address(0), nft2Item[_tokenAddress][_tokenId].price, true);
    }
    function _buyArt(uint _tokenId, address _tokenAddress,  uint _value, uint price, address seller) internal {
        address _royalty;
        uint _percent = 0;
        uint royalty_price;
        uint price_send; 
        uint fee = price*getFee()/100;
        (_royalty, _percent) = _getRoyaltyData(_tokenId,_tokenAddress);               
        royalty_price = ((_value-fee)*_percent)/10000;
        price_send = _value-fee-royalty_price;
        if(price > 0){
            ArtscapeWallet(owner).deposit{value:fee}();
            emit TransactionTransfer(1,owner, fee, _tokenId,_tokenAddress); 
            if(_percent != 0){
                price_send = _value-fee-royalty_price;
                (bool sent, ) = seller.call{value: price_send}("");
                require(sent, "Failed");
                emit TransactionTransfer(2,seller, price_send, _tokenId,_tokenAddress);
                (bool sent2, ) = _royalty.call{value: royalty_price}("");
                require(sent2, "FailedRY");
                emit TransactionTransfer(3,_royalty, royalty_price, _tokenId,_tokenAddress);
            }else{
                price_send = _value-fee;
                (bool sent, ) = seller.call{value: price_send}("");
                require(sent, "FailedF");
                emit TransactionTransfer(2,seller, price_send, _tokenId,_tokenAddress);
            }
        }
    }
    function _getRoyaltyData(uint _tokenId, address _tokenAddress) internal view returns (address artist, uint percent){
        address _address;
        uint _percent;
        if(Artscape721(_tokenAddress).getRaribleV2Royalties(_tokenId).length != 0){
            _address = Artscape721(_tokenAddress).getRaribleV2Royalties(_tokenId)[0].account;
            _percent = Artscape721(_tokenAddress).getRaribleV2Royalties(_tokenId)[0].value;
        }
        return (_address, _percent);
    }
    function getprice(uint _tokenId, address _tokenAddress)public view returns(uint){
        return nft2Item[_tokenAddress][_tokenId].price + (nft2Item[_tokenAddress][_tokenId].price*getFee()/100);
    }
    //TODO: TokenExist(_tokenAddress,_tokenId)
    function getTokenURI(address _tokenAddress,uint _tokenId) public view returns(string memory){
        return Artscape721(_tokenAddress).tokenURI(_tokenId);
    }
} 
// File: contracts/marketplace/Wrapper.sol


pragma solidity ^0.8.0;



contract WrapperArtscape is ArtscapeMarket, MarketAuction{
    MarketRequest market_request;
    constructor(
        address wallet_address
    ) {
        setup(wallet_address);
        setupW(wallet_address);
        market_request = new MarketRequest(payable(wallet_address), address(this));
        market_request.initialize();
        setupWallet(wallet_address);
    }
    function get_market_request() public view returns(address){
        return address(market_request) ;
    }
}