/**
 *Submitted for verification at Etherscan.io on 2022-09-27
*/

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

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;


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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


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

// File: contracts/Marketplace.sol


pragma solidity ^0.8.15;




contract Marketplace is Ownable {
    struct ListingInfo {
        uint256 price;
        address owner;
    }

    event ListedToken(address tokenAddress, uint256 tokenId, uint256 price);
    event CanceledListing(address tokenAddress, uint256 tokenId);
    event PurchasedListing(address tokenAddress, uint256 tokenId, address buyer);
    event UpdatePrice(address tokenAddress, uint256 tokenId, uint256 newPrice);

    IERC20 internal BVC;

    // Token address -> Token ID -> Listing info
    mapping(address => mapping(uint256 => ListingInfo)) public listings;

    address public beneficiary;
    uint256 public fee;
    bool public paused;

    constructor(IERC20 _BVC, address _beneficiary, uint256 _fee) {
        require(_beneficiary != address(0), "beneficiary can't be zero address");
        require(_fee <= 10000, "fee is bigger than 100%");
        BVC = _BVC;
        beneficiary = _beneficiary;
        fee = _fee;
    }

    // List NFT for sale
    function listToken(IERC721 token, uint256 tokenId, uint256 price) external {
        require(!paused, "marketplace is paused");
        require(price > 0, "price cannot be zero");

        // Transfer user's NFT to this contract
        token.transferFrom(msg.sender, address(this), tokenId); // reverts if not successful

        // Store listing info in a mapping
        listings[address(token)][tokenId] = ListingInfo(price, msg.sender);

        // Emit an event for indexing
        emit ListedToken(address(token), tokenId, price);
    }

    // Cancel listing
    function cancelListing(IERC721 token, uint256 tokenId) external {
        require(!paused, "marketplace is paused");

        // Get listing info
        ListingInfo memory listing = listings[address(token)][tokenId];

        // Some checks
        require(listing.owner != address(0), "listing doesn't exist");
        require(msg.sender == listing.owner, "you are not the listing owner");
        
        // Delete listing info from storage
        delete listings[address(token)][tokenId];
        
        // Transfer the NFT back to the owner
        token.transferFrom(address(this), msg.sender, tokenId);

        // Emit an event for indexing
        emit CanceledListing(address(token), tokenId);
    }

    // Buy listed NFT
    function buyListing(IERC721 token, uint256 tokenId) external {
        require(!paused, "marketplace is paused");

        // Get listing info
        ListingInfo memory listing = listings[address(token)][tokenId];

        // Check if the listing exists
        require(listing.owner != address(0), "listing doesn't exist");

        // Checking if the user has enough BVC
        require(BVC.balanceOf(msg.sender) >= listing.price, "you don't have enough BVC");

        // Delist NFT
        delete listings[address(token)][tokenId];

        // Calculate fees
        uint256 beneficiaryFee = listing.price * fee / 10000;
        uint256 totalAfterFee = listing.price - beneficiaryFee;

        // Transfer BVC from buyer to beneficiary and listing owner
        BVC.transferFrom(msg.sender, listing.owner, totalAfterFee);
        BVC.transferFrom(msg.sender, beneficiary, beneficiaryFee);

        // Transfer NFT from marketplace to buyer
        token.transferFrom(address(this), msg.sender, tokenId);

        // Emit event for indexing
        emit PurchasedListing(address(token), tokenId, msg.sender);

    }

    // Update listed NFT price
    function updateListing(IERC721 token, uint256 tokenId, uint256 newPrice) external {
        require(!paused, "marketplace is paused");

        // Get listing info
        ListingInfo memory listing = listings[address(token)][tokenId];

        // Check if the listing exists
        require(listing.owner != address(0), "listing doesn't exist");
        require(msg.sender == listing.owner, "you are not the listing owner");
        require(newPrice > 0, "price cannot be zero");
        
        // Update listing info
        listings[address(token)][tokenId].price = newPrice;

        // Emit event for indexing
        emit UpdatePrice(address(token), tokenId, newPrice);
    }

    // Set beneficiary
    function setBeneficiary(address _beneficiary) onlyOwner external {
        require(_beneficiary != address(0), "beneficiary can't be zero address");
        beneficiary = _beneficiary;
    }

    // Set beneficiary fee
    function setFee(uint256 _fee) onlyOwner external {
        require(_fee <= 10000, "fee can't be bigger than 100%");
        fee = _fee;
    }

    // Recover stuck ERC721 tokens
    function sweepERC721(IERC721 token, uint256 tokenId) onlyOwner external {
        require(listings[address(token)][tokenId].owner == address(0), "can only sweep unlisted NFTs");
        token.transferFrom(address(this), msg.sender, tokenId);
    }

    // Recover stuck ether
    function sweepEther() onlyOwner external {
        payable(msg.sender).transfer(address(this).balance);
    }

    // Recover stuck ERC20 tokens
    function sweepERC20(IERC20 token) onlyOwner external {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    // Pause marketplace
    function pause() onlyOwner external {
        paused = !paused;
    }
}