// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IMetaUnit} from "../../MetaUnit/interfaces/IMetaUnit.sol";
import {IMultipleToken} from "../token/IMultipleToken.sol";
import {Pausable} from "../../../Pausable.sol";

/**
 * @author MetaPlayerOne
 * @title MultipleTokenAuction
 * @notice Manages ERC1155 token auctions on MetaPlayerOne.
 */
contract MultipleTokenAuction is Pausable {
    struct Item { uint256 uid; address token_address; uint256 token_id; uint256 amount; address owner_of; address curator_address; uint256 curator_fee; uint256 start_price; bool approved; uint256 highest_bid; address highest_bidder; uint256 end_time; uint256 duration; }
    Item[] private _items;
    mapping(uint256 => bool) private _finished;
    address private _meta_unit_address;
    mapping(address => bool) private _royalty_receivers;

    /**
     * @dev setup metaunit address and owner of contract.
     */
    constructor(address owner_of_, address meta_unit_address_, address[] memory platform_token_addresses_) Pausable(owner_of_) {
        _meta_unit_address = meta_unit_address_;
        for (uint256 i = 0; i < platform_token_addresses_.length; i++) {
            _royalty_receivers[platform_token_addresses_[i]] = true;
        }
    }

    /**
     * @dev emitted when an NFT is auctioned.
     */
    event itemAdded(uint256 uid, address token_address, uint256 token_id, uint256 amount, address owner_of, address curator_address, uint256 curator_fee, uint256 start_price, bool approved, uint256 highest_bid, address highest_bidder);

    /**
     * @dev emitted when an auction approved by curator.
     */
    event auctionApproved(uint256 uid, uint256 end_time);

    /**
     * @dev emitted when bid creates.
     */
    event bidCreated(uint256 uid, uint256 highest_bid, address highest_bidder);

    /**
     * @dev emitted when an auction resolved.
     */
    event itemSold(uint256 uid);

    /**
     * @dev allows us to sell for sale.
     * @param token_address address of the token to be auctioned.
     * @param token_id address of the token to be auctioned.
     * @param amount amount of ERC1155 token for sale.
     * @param curator_address address of user which should curate auction.
     * @param curator_fee percentage of auction highest bid value, which curator will receive after successfull curation.
     * @param start_price threshold of auction.
     * @param duration auction duration in seconds.
     */
    function sale(address token_address, uint256 token_id, uint256 amount, address curator_address, uint256 curator_fee, uint256 start_price, uint256 duration) public notPaused {
        IERC1155 token = IERC1155(token_address);
        require(token.isApprovedForAll(msg.sender, address(this)), "Token is not approved to contract");
        require(token.balanceOf(msg.sender, token_id) >= amount, "You are not an owner");
        uint256 newItemId = _items.length;
        _items.push(Item(newItemId, token_address, token_id, amount, msg.sender, curator_address, curator_fee, start_price, false, 0, address(0), 0, duration));
        emit itemAdded(newItemId, token_address, token_id, amount, msg.sender, curator_address, curator_fee, start_price, false, 0, address(0));
        if (curator_address == msg.sender) {
            setCuratorApproval(newItemId);
        }
    }

    /**
     * @dev allows the curator of the auction to put approval on the auction.
     * @param uid unique id of auction order.
     */
    function setCuratorApproval(uint256 uid) public notPaused {
        require(uid < _items.length && _items[uid].uid == uid, "Token does not exists");
        Item memory item = _items[uid];
        require(!item.approved, "Auction is already approved");
        require(item.curator_address == msg.sender, "You are not curator");
        _items[uid].approved = true;
        _items[uid].end_time = block.timestamp + item.duration;
        emit auctionApproved(uid, _items[uid].end_time);
    }

    /**
     * @dev allows you to make bid on the auction.
     * @param uid unique id of auction order.
     */
    function bid(uint256 uid) public payable notPaused {
        require(uid < _items.length && _items[uid].uid == uid, "Token does not exists");
        Item memory item = _items[uid];
        IERC1155 token = IERC1155(item.token_address);
        require(block.timestamp <= item.end_time, "Auction has been finished");
        require(token.balanceOf(item.owner_of, item.token_id) > item.amount, "Token is already sold");
        require(token.isApprovedForAll(item.owner_of, address(this)), "Token is not approved");
        require(msg.value >= item.start_price, "Bid is lower than start price");
        require(msg.value >= item.highest_bid, "Bid is lower than previous one");
        require(item.approved, "Auction is not approved with curator");
        require(item.owner_of != msg.sender, "You are an owner");
        require(item.curator_address != msg.sender, "You are curator");
        if (item.highest_bidder != address(0)) {
            payable(item.highest_bidder).transfer(item.highest_bid);
        }
        _items[uid].highest_bid = msg.value;
        _items[uid].highest_bidder = msg.sender;
        emit bidCreated(uid, _items[uid].highest_bid, _items[uid].highest_bidder);
    }

    /**
     * @dev allows curator to resolve auction.
     * @param uid unique id of auction order.
     */
    function resolve(uint256 uid) public notPaused {
        require(uid < _items.length && _items[uid].uid == uid, "Order does not exists");
        Item memory item = _items[uid];
        IERC1155 token = IERC1155(item.token_address);
        require(block.timestamp > item.end_time, "Auction is not finished");
        require(item.curator_address == msg.sender, "You are not curator");
        require(item.approved, "Is not curator approved");
        require(token.isApprovedForAll(item.owner_of, address(this)), "Token is not approved");
        require(!_finished[uid], "Is resolved");
        uint256 summ = 0;
        if (_royalty_receivers[item.token_address]) {
            IMultipleToken multiple_token = IMultipleToken(item.token_address);
            uint256 royalty = multiple_token.getRoyalty(item.token_id);
            address creator = multiple_token.getCreator(item.token_id);
            payable(creator).transfer((item.highest_bid * royalty) / 1000);
            summ += royalty;
        }
        payable(_owner_of).transfer((item.highest_bid * 25) / 1000);
        summ += 25;
        payable(item.curator_address).transfer((item.highest_bid * item.curator_fee) / 1000);
        summ += item.curator_fee;
        payable(item.owner_of).transfer((item.highest_bid - ((item.highest_bid * summ) / 1000)));
        IMetaUnit(_meta_unit_address).increaseLimit(msg.sender, item.highest_bid);
        token.safeTransferFrom(item.owner_of, item.highest_bidder, item.token_id, item.amount, "");
        _finished[uid] = true;
        emit itemSold(uid);
    }

    function update(address[] memory addresses) public {
        require(msg.sender == _owner_of, "Permission denied");
        for (uint256 i = 0; i < addresses.length; i++) {
            _royalty_receivers[addresses[i]] = true;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMetaUnit {
    function increaseLimit(address userAddress, uint256 value) external;
    function burnFrom(address account, uint256 amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMultipleToken {
    function getRoyalty(uint256 tokenId) external returns (uint256);

    function getCreator(uint256 tokenId) external returns (address);

    function mint(string memory token_uri, uint256 amount, uint256 royalty) external;

    function burn(uint256 token_id, uint256 amount) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @author MetaPlayerOne
 * @title Pausable
 * @notice Contract which manages allocations in MetaPlayerOne.
 */
contract Pausable {
    address internal _owner_of;
    bool internal _paused = false;

    /**
    * @dev setup owner of this contract with paused off state.
    */
    constructor(address owner_of_) {
        _owner_of = owner_of_;
        _paused = false;
    }

    /**
    * @dev modifier which can be used on child contract for checking if contract services are paused.
    */
    modifier notPaused() {
        require(!_paused, "Contract is paused");
        _;
    }

    /**
    * @dev function which setup paused variable.
    * @param paused_ new boolean value of paused condition.
    */
    function setPaused(bool paused_) external {
        require(_paused == paused_, "Param has been asigned already");
        require(_owner_of == msg.sender, "Permission address");
        _paused = paused_;
    }

    /**
    * @dev function which setup owner variable.
    * @param owner_of_ new owner of contract.
    */
    function setOwner(address owner_of_) external {
        require(_owner_of == msg.sender, "Permission address");
        _owner_of = owner_of_;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/introspection/IERC165.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

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
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

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
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

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
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}