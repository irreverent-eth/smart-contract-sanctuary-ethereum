// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
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

pragma solidity ^0.8.15;

/**
 * @title Contract ownership standard interface (event only)
 * @dev see https://eips.ethereum.org/EIPS/eip-173
 */
interface IERC173Events {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Context.sol";

import "./OwnableStorage.sol";
import "./IERC173Events.sol";

abstract contract OwnableInternal is IERC173Events, Context {
    using OwnableStorage for OwnableStorage.Layout;

    modifier onlyOwner() {
        require(_msgSender() == _owner(), "Ownable: sender must be owner");
        _;
    }

    function _owner() internal view virtual returns (address) {
        return OwnableStorage.layout().owner;
    }

    function _transferOwnership(address account) internal virtual {
        OwnableStorage.layout().setOwner(account);
        emit OwnershipTransferred(_msgSender(), account);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

library OwnableStorage {
    struct Layout {
        address owner;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("openzeppelin.contracts.storage.Ownable");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function setOwner(Layout storage l, address owner) internal {
        l.owner = owner;
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.15;

import "./IWithdrawableInternal.sol";

interface IWithdrawable is IWithdrawableInternal {
    function withdraw(address[] calldata claimTokens, uint256[] calldata amounts) external;

    function withdrawRecipient() external view returns (address);

    function withdrawRecipientLocked() external view returns (bool);

    function withdrawPowerRevoked() external view returns (bool);

    function withdrawMode() external view returns (Mode);

    function withdrawModeLocked() external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./IWithdrawable.sol";

interface IWithdrawableAdmin {
    function setWithdrawRecipient(address _recipient) external;

    function lockWithdrawRecipient() external;

    function revokeWithdrawPower() external;

    function setWithdrawMode(IWithdrawable.Mode _mode) external;

    function lockWithdrawMode() external;
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.15;

interface IWithdrawableInternal {
    enum Mode {
        OWNER,
        RECIPIENT,
        ANYONE,
        NOBODY
    }

    error ErrWithdrawOnlyRecipient();
    error ErrWithdrawOnlyOwner();
    error ErrWithdrawImpossible();
    error ErrWithdrawRecipientLocked();
    error ErrWithdrawModeLocked();

    event WithdrawRecipientChanged(address indexed recipient);
    event WithdrawRecipientLocked();
    event WithdrawModeChanged(Mode _mode);
    event WithdrawModeLocked();
    event Withdrawn(address[] claimTokens, uint256[] amounts);
    event WithdrawPowerRevoked();
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../access/ownable/OwnableInternal.sol";

import "./WithdrawableStorage.sol";
import "./IWithdrawableInternal.sol";

/**
 * @title Functionality to withdraw ERC20 or natives tokens from the contract via various modes
 */
abstract contract WithdrawableInternal is IWithdrawableInternal, OwnableInternal {
    using WithdrawableStorage for WithdrawableStorage.Layout;

    using Address for address payable;

    function _withdrawRecipient() internal view virtual returns (address) {
        return WithdrawableStorage.layout().recipient;
    }

    function _withdrawRecipientLocked() internal view virtual returns (bool) {
        return WithdrawableStorage.layout().recipientLocked;
    }

    function _withdrawPowerRevoked() internal view virtual returns (bool) {
        return WithdrawableStorage.layout().powerRevoked;
    }

    function _withdrawMode() internal view virtual returns (Mode) {
        return WithdrawableStorage.layout().mode;
    }

    function _withdrawModeLocked() internal view virtual returns (bool) {
        return WithdrawableStorage.layout().modeLocked;
    }

    function _setWithdrawRecipient(address recipient) internal virtual {
        WithdrawableStorage.Layout storage l = WithdrawableStorage.layout();

        if (l.recipientLocked) {
            revert ErrWithdrawRecipientLocked();
        }

        l.recipient = recipient;

        emit WithdrawRecipientChanged(recipient);
    }

    function _lockWithdrawRecipient() internal virtual {
        WithdrawableStorage.layout().recipientLocked = true;

        emit WithdrawRecipientLocked();
    }

    function _revokeWithdrawPower() internal virtual {
        WithdrawableStorage.layout().powerRevoked = true;

        emit WithdrawPowerRevoked();
    }

    function _setWithdrawMode(Mode _mode) internal virtual {
        WithdrawableStorage.Layout storage l = WithdrawableStorage.layout();

        if (l.modeLocked) {
            revert ErrWithdrawModeLocked();
        }

        l.mode = _mode;

        emit WithdrawModeChanged(_mode);
    }

    function _lockWithdrawMode() internal virtual {
        WithdrawableStorage.layout().modeLocked = true;

        emit WithdrawModeLocked();
    }

    function _withdraw(address[] calldata claimTokens, uint256[] calldata amounts) internal virtual {
        WithdrawableStorage.Layout storage l = WithdrawableStorage.layout();

        /**
         * We are using msg.sender for smaller attack surface when evaluating
         * the sender of the function call. If in future we want to handle "withdraw"
         * functionality via meta transactions, we should consider using `_msgSender`
         */

        if (l.mode == Mode.NOBODY) {
            revert ErrWithdrawImpossible();
        } else if (l.mode == Mode.RECIPIENT) {
            if (l.recipient != msg.sender) {
                revert ErrWithdrawOnlyRecipient();
            }
        } else if (l.mode == Mode.OWNER) {
            if (_owner() != msg.sender) {
                revert ErrWithdrawOnlyOwner();
            }
        }

        if (l.powerRevoked) {
            revert ErrWithdrawImpossible();
        }

        for (uint256 i = 0; i < claimTokens.length; i++) {
            if (claimTokens[i] == address(0)) {
                payable(l.recipient).sendValue(amounts[i]);
            } else {
                IERC20(claimTokens[i]).transfer(address(l.recipient), amounts[i]);
            }
        }

        emit Withdrawn(claimTokens, amounts);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../../access/ownable/OwnableInternal.sol";

import "./WithdrawableInternal.sol";
import "./IWithdrawableAdmin.sol";

/**
 * @title Withdrawable - Admin - Ownable
 * @notice Allow contract owner to manage who can withdraw funds and how.
 *
 * @custom:type eip-2535-facet
 * @custom:category Finance
 * @custom:peer-dependencies IWithdrawable
 * @custom:provides-interfaces IWithdrawableAdmin
 */
contract WithdrawableOwnable is IWithdrawableAdmin, OwnableInternal, WithdrawableInternal {
    function setWithdrawRecipient(address recipient) external onlyOwner {
        _setWithdrawRecipient(recipient);
    }

    function lockWithdrawRecipient() external onlyOwner {
        _lockWithdrawRecipient();
    }

    function revokeWithdrawPower() external onlyOwner {
        _revokeWithdrawPower();
    }

    function setWithdrawMode(Mode mode) external onlyOwner {
        _setWithdrawMode(mode);
    }

    function lockWithdrawMode() external onlyOwner {
        _lockWithdrawMode();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./IWithdrawableInternal.sol";

library WithdrawableStorage {
    struct Layout {
        address recipient;
        IWithdrawableInternal.Mode mode;
        bool powerRevoked;
        bool recipientLocked;
        bool modeLocked;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("v2.flair.contracts.storage.Withdrawable");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}