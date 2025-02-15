// SPDX-License-Identifier: MIT
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

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

// SPDX-License-Identifier: MIT
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

///////////////////////////
////////  Errors  /////////
///////////////////////////
error NftMarketplace__PriceMustBeAboveZero();
error NftMarketplace__NotApprovedForMarketplace();
error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotTheNftOwner();
error NftMarketplace__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NftMarketplace__NoProceedsForThisAddress(address seller);
error NftMarketplace__TransferFailed(address seller, uint256 amount);

contract NftMarketplace is ReentrancyGuard {
    ///////////////////////////
    ////////  Events  /////////
    ///////////////////////////
    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ListingCancelled(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed spender
    );
    //ListingUpdated(_nftAddress, _tokenId, _price, oldListing.price)
    event ListingUpdated(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed spender,
        uint256 oldPrice,
        uint256 updatedPrice
    );

    //Listing struct
    struct Listing {
        uint256 price;
        address seller;
    }
    //Mapping between NFT address => NFT token Id => Listing (price, seller)
    mapping(address => mapping(uint256 => Listing)) private s_Listing;

    //Mapping between seller and proceed (NFT value sold)
    mapping(address => uint256) private s_proceeds;

    ///////////////////////////
    ///////  Modifiers ////////
    ///////////////////////////

    modifier notListed(
        address _nftAddress,
        uint256 _tokenId,
        address _seller
    ) {
        Listing memory listing = s_Listing[_nftAddress][_tokenId];
        if (listing.price > 0) {
            revert NftMarketplace__AlreadyListed(_nftAddress, _tokenId);
        }
        _;
    }

    modifier isListed(address _nftAddress, uint256 _tokenId) {
        Listing memory listing = s_Listing[_nftAddress][_tokenId];
        if (listing.price <= 0) {
            revert NftMarketplace__NotListed(_nftAddress, _tokenId);
        }
        _;
    }

    modifier isOwner(
        address _nftAddress,
        uint256 _tokenId,
        address _spender
    ) {
        IERC721 nft = IERC721(_nftAddress);
        address owner = nft.ownerOf(_tokenId);
        if (_spender != owner) {
            revert NftMarketplace__NotTheNftOwner();
        }
        _;
    }

    modifier hasProceed(address seller) {
        if (s_proceeds[seller] <= 0) {
            revert NftMarketplace__NoProceedsForThisAddress(seller);
        }
        _;
    }

    ///////////////////////////
    ///// Main Functions //////
    ///////////////////////////

    /**
     * @notice Method for listing your NFT to the marketplace
     * @param _nftAddress: address of the NFT contract
     * @param _tokenId: the token ID of the NFT
     * @param _price: the price of  the NFT
     * @dev Technically we could have made the contract to be an escrow, but we made it this way so that
     * people can still keep their NFT in their wallet while listing it in the marketplace by just approving the
     * marketplace as a spender on the NFT
     */
    function listItem(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price
    )
        external
        notListed(_nftAddress, _tokenId, msg.sender)
        isOwner(_nftAddress, _tokenId, msg.sender)
    {
        if (_price <= 0) {
            revert NftMarketplace__PriceMustBeAboveZero();
        }
        // 1. Send the NFT to the NftMarketplace contract, Transfer => Contract hold the NFT
        // 2. Owner can still hold their NFT, and give the marketplace approval to sell the NFT for them
        IERC721 nft = IERC721(_nftAddress);
        if (nft.getApproved(_tokenId) != address(this)) {
            revert NftMarketplace__NotApprovedForMarketplace();
        }
        s_Listing[_nftAddress][_tokenId] = Listing(_price, msg.sender);

        emit ItemListed(msg.sender, _nftAddress, _tokenId, _price);
    }

    function buyItem(
        address _nftAddress,
        uint256 _tokenId
    ) external payable nonReentrant isListed(_nftAddress, _tokenId) {
        Listing memory listing = s_Listing[_nftAddress][_tokenId];
        if (msg.value < listing.price) {
            revert NftMarketplace__PriceNotMet(_nftAddress, _tokenId, msg.value);
        }
        s_proceeds[listing.seller] += listing.price;
        delete (s_Listing[_nftAddress][_tokenId]);

        IERC721(_nftAddress).safeTransferFrom(listing.seller, msg.sender, _tokenId);

        emit ItemBought(msg.sender, _nftAddress, _tokenId, listing.price);
    }

    function cancelListing(
        address _nftAddress,
        uint256 _tokenId
    ) external isListed(_nftAddress, _tokenId) isOwner(_nftAddress, _tokenId, msg.sender) {
        delete (s_Listing[_nftAddress][_tokenId]);
        emit ListingCancelled(_nftAddress, _tokenId, msg.sender);
    }

    function updateListing(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price
    ) external isListed(_nftAddress, _tokenId) isOwner(_nftAddress, _tokenId, msg.sender) {
        Listing memory oldListing = s_Listing[_nftAddress][_tokenId];
        s_Listing[_nftAddress][_tokenId].price = _price;

        emit ListingUpdated(_nftAddress, _tokenId, msg.sender, oldListing.price, _price);
    }

    function withdrawProceed() external payable hasProceed(msg.sender) {
        uint256 proceeds = s_proceeds[msg.sender];
        s_proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        if (!success) {
            revert NftMarketplace__TransferFailed(msg.sender, proceeds);
        }
    }

    ///////////////////////////
    //// Getter Functions /////
    ///////////////////////////

    function getListing(
        address _nftAddress,
        uint256 _tokenId
    ) external view returns (Listing memory) {
        return s_Listing[_nftAddress][_tokenId];
    }

    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }
}