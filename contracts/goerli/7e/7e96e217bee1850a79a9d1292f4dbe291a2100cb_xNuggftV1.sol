// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import {IERC1155, IERC165, IERC1155Metadata_URI} from "./interfaces/IERC721.sol";

import {IxNuggftV1} from "./interfaces/nuggftv1/IxNuggftV1.sol";
import {DotnuggV1Lib} from "dotnugg-v1-core/DotnuggV1Lib.sol";
import {IDotnuggV1} from "dotnugg-v1-core/IDotnuggV1.sol";

import {INuggftV1} from "./interfaces/nuggftv1/INuggftV1.sol";

/// @author nugg.xyz - danny7even and dub6ix - 2022
contract xNuggftV1 is IERC1155, IERC1155Metadata_URI, IxNuggftV1 {
    using DotnuggV1Lib for IDotnuggV1;

    INuggftV1 immutable nuggftv1;

    constructor() {
        nuggftv1 = INuggftV1(msg.sender);
    }

    /// @inheritdoc IxNuggftV1
    function imageURI(uint256 tokenId) public view override returns (string memory res) {
        (uint8 feature, uint8 position) = DotnuggV1Lib.parseItemId(tokenId);
        res = nuggftv1.dotnuggv1().exec(feature, position, true);
    }

    /// @inheritdoc IxNuggftV1
    function imageSVG(uint256 tokenId) public view override returns (string memory res) {
        (uint8 feature, uint8 position) = DotnuggV1Lib.parseItemId(tokenId);
        res = nuggftv1.dotnuggv1().exec(feature, position, false);
    }

    function transferBatch(
        uint256 proof,
        address from,
        address to
    ) external payable {
        require(msg.sender == address(nuggftv1));

        unchecked {
            uint256 tmp = proof;

            uint256 length = 1;

            while (tmp != 0) if ((tmp >>= 16) & 0xffff != 0) length++;

            uint256[] memory ids = new uint256[](length);
            uint256[] memory values = new uint256[](length);

            ids[0] = proof & 0xffff;
            values[0] = 1;

            while (proof != 0)
                if ((tmp = ((proof >>= 16) & 0xffff)) != 0) {
                    ids[--length] = tmp;
                    values[length] = 1;
                }

            emit TransferBatch(address(0), from, to, ids, values);
        }
    }

    function transferSingle(
        uint256 itemId,
        address from,
        address to
    ) external payable {
        require(msg.sender == address(nuggftv1));
        emit TransferSingle(address(0), from, to, itemId, 1);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == 0xd9b67a26 || //
            interfaceId == 0x0e89341c ||
            interfaceId == type(IERC165).interfaceId;
    }

    function name() public pure returns (string memory) {
        return "Nugg Fungible Items V1";
    }

    function symbol() public pure returns (string memory) {
        return "xNUGGFT";
    }

    function uri(uint256 tokenId) public view virtual override returns (string memory res) {
        // prettier-ignore
        res = string(
            nuggftv1.dotnuggv1().encodeJson(
                abi.encodePacked(
                     '{"name":"',         name(),
                    '","description":"',  DotnuggV1Lib.itemIdToString(uint16(tokenId),
                            ["base", "eyes", "mouth", "hair", "hat", "background", "scarf", "hold"]),
                    '","image":"',        imageURI(tokenId),
                    '}'
                ), true
            )
        );
    }

    function totalSupply() public view returns (uint256 res) {
        for (uint8 i = 0; i < 8; i++) res += featureSupply(i);
    }

    function featureSupply(uint8 feature) public view override returns (uint256 res) {
        res = nuggftv1.dotnuggv1().lengthOf(feature);
    }

    function rarity(uint256 tokenId) public view returns (uint16 res) {
        (uint8 feature, uint8 position) = DotnuggV1Lib.parseItemId(tokenId);
        res = nuggftv1.dotnuggv1().rarity(feature, position);
    }

    function balanceOf(address _owner, uint256 _id) public view returns (uint256 res) {
        uint256 bal = 0;

        while (bal != 0) {
            uint256 proof = nuggftv1.proof(uint24(bal <<= 24));
            while (proof != 0) if ((proof <<= 16) == _id) res++;
        }
    }

    function balanceOfBatch(address[] calldata _owners, uint256[] memory _ids) external view returns (uint256[] memory) {
        for (uint256 i = 0; i < _owners.length; i++) {
            _ids[i] = balanceOf(_owners[i], _ids[i]);
        }

        return _ids;
    }

    function isApprovedForAll(address, address) external pure override returns (bool) {
        return false;
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) public {}

    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external {}

    function setApprovalForAll(address, bool) external pure {
        revert("whut");
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceID The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

/**
    Note: The ERC-165 identifier for this interface is 0x0e89341c.
*/
interface IERC1155Metadata_URI {
    /**
        @notice A distinct Uniform Resource Identifier (URI) for a given token.
        @dev URIs are defined in RFC 3986.
        The URI MUST point to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".
        @return URI string
    */
    function uri(uint256 _id) external view returns (string memory);
}

/**
    @title ERC-1155 Multi Token Standard
    @dev See https://eips.ethereum.org/EIPS/eip-1155
    Note: The ERC-165 identifier for this interface is 0xd9b67a26.
 */
interface IERC1155 is IERC165 {
    /**
        @dev Either `TransferSingle` or `TransferBatch` MUST emit when tokens are transferred, including zero value transfers as well as minting or burning (see "Safe Transfer Rules" section of the standard).
        The `_operator` argument MUST be the address of an account/contract that is approved to make the transfer (SHOULD be msg.sender).
        The `_from` argument MUST be the address of the holder whose balance is decreased.
        The `_to` argument MUST be the address of the recipient whose balance is increased.
        The `_id` argument MUST be the token type being transferred.
        The `_value` argument MUST be the number of tokens the holder balance is decreased by and match what the recipient balance is increased by.
        When minting/creating tokens, the `_from` argument MUST be set to `0x0` (i.e. zero address).
        When burning/destroying tokens, the `_to` argument MUST be set to `0x0` (i.e. zero address).
    */
    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value);

    /**
        @dev Either `TransferSingle` or `TransferBatch` MUST emit when tokens are transferred, including zero value transfers as well as minting or burning (see "Safe Transfer Rules" section of the standard).
        The `_operator` argument MUST be the address of an account/contract that is approved to make the transfer (SHOULD be msg.sender).
        The `_from` argument MUST be the address of the holder whose balance is decreased.
        The `_to` argument MUST be the address of the recipient whose balance is increased.
        The `_ids` argument MUST be the list of tokens being transferred.
        The `_values` argument MUST be the list of number of tokens (matching the list and order of tokens specified in _ids) the holder balance is decreased by and match what the recipient balance is increased by.
        When minting/creating tokens, the `_from` argument MUST be set to `0x0` (i.e. zero address).
        When burning/destroying tokens, the `_to` argument MUST be set to `0x0` (i.e. zero address).
    */
    event TransferBatch(address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values);

    /**
        @dev MUST emit when approval for a second party/operator address to manage all tokens for an owner address is enabled or disabled (absence of an event assumes disabled).
    */
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /**
        @dev MUST emit when the URI is updated for a token ID.
        URIs are defined in RFC 3986.
        The URI MUST point to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".
    */
    event URI(string _value, uint256 indexed _id);

    /**
        @notice Transfers `_value` amount of an `_id` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if balance of holder for token `_id` is lower than the `_value` sent.
        MUST revert on any other error.
        MUST emit the `TransferSingle` event to reflect the balance change (see "Safe Transfer Rules" section of the standard).
        After the above conditions are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call `onERC1155Received` on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).
        @param _from    Source address
        @param _to      Target address
        @param _id      ID of the token type
        @param _value   Transfer amount
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to `onERC1155Received` on `_to`
    */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external;

    /**
        @notice Transfers `_values` amount(s) of `_ids` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if length of `_ids` is not the same as length of `_values`.
        MUST revert if any of the balance(s) of the holder(s) for token(s) in `_ids` is lower than the respective amount(s) in `_values` sent to the recipient.
        MUST revert on any other error.
        MUST emit `TransferSingle` or `TransferBatch` event(s) such that all the balance changes are reflected (see "Safe Transfer Rules" section of the standard).
        Balance changes and events MUST follow the ordering of the arrays (_ids[0]/_values[0] before _ids[1]/_values[1], etc).
        After the above conditions for the transfer(s) in the batch are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call the relevant `ERC1155TokenReceiver` hook(s) on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).
        @param _from    Source address
        @param _to      Target address
        @param _ids     IDs of each token type (order and length must match _values array)
        @param _values  Transfer amounts per token type (order and length must match _ids array)
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to the `ERC1155TokenReceiver` hook(s) on `_to`
    */
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external;

    /**
        @notice Get the balance of an account's tokens.
        @param _owner  The address of the token holder
        @param _id     ID of the token
        @return        The _owner's balance of the token type requested
     */
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);

    /**
        @notice Get the balance of multiple account/token pairs
        @param _owners The addresses of the token holders
        @param _ids    ID of the tokens
        @return        The _owner's balance of the token types requested (i.e. balance for each (owner, id) pair)
     */
    function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view returns (uint256[] memory);

    /**
        @notice Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.
        @dev MUST emit the ApprovalForAll event on success.
        @param _operator  Address to add to the set of authorized operators
        @param _approved  True if the operator is approved, false to revoke approval
    */
    function setApprovalForAll(address _operator, bool _approved) external;

    /**
        @notice Queries the approval status of an operator for a given owner.
        @param _owner     The owner of the tokens
        @param _operator  Address of authorized operator
        @return           True if the operator is approved, false if not
    */
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

/// @title ERC-721 Non-Fungible Token Standard
/// @dev See https://eips.ethereum.org/EIPS/eip-721
///  Note: the ERC-165 identifier for this interface is 0x80ac58cd.
interface IERC721 is IERC165 {
    /// @dev This emits when ownership of any NFT changes by any mechanism.
    ///  This event emits when NFTs are created (`from` == 0) and destroyed
    ///  (`to` == 0). Exception: during contract creation, any number of NFTs
    ///  may be created and assigned without emitting Transfer. At the time of
    ///  any transfer, the approved address for that NFT (if any) is reset to none.
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /// @dev This emits when the approved address for an NFT is changed or
    ///  reaffirmed. The zero address indicates there is no approved address.
    ///  When a Transfer event emits, this also indicates that the approved
    ///  address for that NFT (if any) is reset to none.
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    /// @dev This emits when an operator is enabled or disabled for an owner.
    ///  The operator can manage all NFTs of the owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this
    ///  function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address _owner) external view returns (uint256);

    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) external view returns (address);

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory data
    ) external payable;

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable;

    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable;

    /// @notice Change or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    ///  Throws unless `msg.sender` is the current NFT owner, or an authorized
    ///  operator of the current owner.
    /// @param _approved The new approved NFT controller
    /// @param _tokenId The NFT to approve
    function approve(address _approved, uint256 _tokenId) external payable;

    /// @notice Enable or disable approval for a third party ("operator") to manage
    ///  all of `msg.sender`'s assets
    /// @dev Emits the ApprovalForAll event. The contract MUST allow
    ///  multiple operators per owner.
    /// @param _operator Address to add to the set of authorized operators
    /// @param _approved True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external;

    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT.
    /// @param _tokenId The NFT to find the approved address for
    /// @return The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 _tokenId) external view returns (address);

    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

/// @title ERC-721 Non-Fungible Token Standard, optional metadata extension
/// @dev See https://eips.ethereum.org/EIPS/eip-721
///  Note: the ERC-165 identifier for this interface is 0x5b5e139f.
interface IERC721Metadata is IERC721 {
    /// @notice A descriptive name for a collection of NFTs in this contract
    function name() external view returns (string memory _name);

    /// @notice An abbreviated name for NFTs in this contract
    function symbol() external view returns (string memory _symbol);

    /// @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    /// @dev Throws if `_tokenId` is not a valid NFT. URIs are defined in RFC
    ///  3986. The URI may point to a JSON file that conforms to the "ERC721
    ///  Metadata JSON Schema".
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface IxNuggftV1 {
    function imageURI(uint256 tokenId) external view returns (string memory);

    function imageSVG(uint256 tokenId) external view returns (string memory);

    function featureSupply(uint8 itemId) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function rarity(uint256 tokenId) external view returns (uint16 res);

    function transferBatch(
        uint256 proof,
        address from,
        address to
    ) external payable;

    function transferSingle(
        uint256 itemId,
        address from,
        address to
    ) external payable;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import {IDotnuggV1, IDotnuggV1File} from "./IDotnuggV1.sol";

/// @title DotnuggV1Lib
/// @author nugg.xyz - danny7even and dub6ix - 2022
/// @notice helper functions for working with dotnuggv1 files on chain
library DotnuggV1Lib {
    uint8 constant DOTNUGG_HEADER_BYTE_LEN = 25;

    uint8 constant DOTNUGG_RUNTIME_BYTE_LEN = 1;

    bytes18 internal constant PROXY_INIT_CODE = 0x69_36_3d_3d_36_3d_3d_37_f0_33_FF_3d_52_60_0a_60_16_f3;

    bytes32 internal constant PROXY_INIT_CODE_HASH = keccak256(abi.encodePacked(PROXY_INIT_CODE));

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        return toFixedPointString(value, 0);
    }

    /// @notice parses the external itemId into a feautre and position
    /// @dev this follows dotnugg v1 specification
    /// @param itemId -> the external itemId
    /// @return feat -> the feautre of the item
    /// @return pos -> the file storage position of the item
    function parseItemId(uint256 itemId) internal pure returns (uint8 feat, uint8 pos) {
        feat = uint8(itemId / 1000);
        pos = uint8(itemId % 1000);
    }

    function itemIdToString(uint16 itemId, string[8] memory labels) internal pure returns (string memory) {
        (uint8 feat, uint8 pos) = parseItemId(itemId);
        return string.concat(labels[feat], " ", toString(pos));
    }

    function searchToId(
        IDotnuggV1 safe,
        uint8 feature,
        uint256 seed
    ) internal view returns (uint16 res) {
        return (uint16(feature) * 1000) + search(safe, feature, seed);
    }

    function props(uint8[8] memory ids, string[8] memory labels) internal pure returns (string memory) {
        bytes memory res;

        for (uint8 i = 0; i < 8; i++) {
            if (ids[i] == 0) continue;
            res = abi.encodePacked(res, i != 0 ? "," : "", '"', labels[i], '":"', toString(uint8(ids[i])), '"');
        }
        return string(abi.encodePacked("{", res, "}"));
    }

    function lengthOf(IDotnuggV1 safe, uint8 feature) internal view returns (uint8) {
        return size(location(safe, feature));
    }

    function locationOf(IDotnuggV1 safe, uint8 feature) internal pure returns (address res) {
        return address(location(safe, feature));
    }

    function size(IDotnuggV1File pointer) private view returns (uint8 res) {
        assembly {
            // memory:
            // [0x00] 0x//////////////////////////////////////////////////////////////

            let scratch := mload(0x00)

            // the amount of items inside a dotnugg file are stored at byte #1 (0 based index)
            // here we copy that single byte from the file and store it in byte #31 of memory
            // this way, we can mload(0x00) to get the properly alignede integer from memory

            extcodecopy(pointer, 31, DOTNUGG_RUNTIME_BYTE_LEN, 0x01)

            // memory:                                           length of file  =  XX
            // [0x00] 0x////////////////////////////////////////////////////////////XX

            res := and(mload(0x00), 0xff)

            // clean the scratch space we dirtied
            mstore(0x00, scratch)

            // memory:
            // [0x00] 0x//////////////////////////////////////////////////////////////
        }
    }

    function location(IDotnuggV1 safe, uint8 feature) private pure returns (IDotnuggV1File res) {
        bytes32 h = PROXY_INIT_CODE_HASH;

        assembly {
            // [======================================================================
            let mptr := mload(0x40)

            // [0x00] 0x00000000000000000000000000000000000000000000000000000000000000
            // [0x20] 0x00000000000000000000000000000000000000000000000000000000000000
            // [0x40] 0x________________________FREE_MEMORY_PTR_______________________
            // =======================================================================]

            // [======================================================================
            mstore8(0x00, 0xff)
            mstore(0x01, shl(96, safe))
            mstore(0x15, feature)
            mstore(0x35, h)

            // [0x00] 0xff>_________________safe__________________>___________________
            // [0x20] 0x________________feature___________________>___________________
            // [0x40] 0x________________PROXY_INIT_CODE_HASH______////////////////////
            // =======================================================================]

            // 1 proxy #1 - dotnugg for nuggft (or a clone of dotnugg)
            // to calculate proxy #2 - address proxy #1 + feature(0-7) + PROXY#2_INIT_CODE
            // 8 proxy #2 - things that get self dest

            // 8 proxy #3 - nuggs
            // to calc proxy #3 = address proxy #2 + [feature(1-8)] = nonce
            // nonces for contracts start at 1

            // bytecode -> proxy #2 -> contract with items (dotnugg file) -> kills itelf

            // [======================================================================
            mstore(0x02, shl(96, keccak256(0x00, 0x55)))
            mstore8(0x00, 0xD6)
            mstore8(0x01, 0x94)
            mstore8(0x16, 0x01)

            // [0x00] 0xD694_________ADDRESS_OF_FILE_CREATOR________01////////////////
            // [0x20] ////////////////////////////////////////////////////////////////
            // [0x40] ////////////////////////////////////////////////////////////////
            // =======================================================================]

            res := shr(96, shl(96, keccak256(0x00, 0x17)))

            // [======================================================================
            mstore(0x00, 0x00)
            mstore(0x20, 0x00)
            mstore(0x40, mptr)

            // [0x00] 0x00000000000000000000000000000000000000000000000000000000000000
            // [0x20] 0x00000000000000000000000000000000000000000000000000000000000000
            // [0x40] 0x________________________FREE_MEMORY_PTR_______________________
            // =======================================================================]
        }
    }

    /// binary search usage inspired by implementation from fiveoutofnine
    /// [ OnMintGeneration.sol : MIT ] - https://github.com/fiveoutofnine/on-mint-generation/blob/719f19a10d19956c8414e421517d902ab3591111/src/OnMintGeneration.sol
    function search(
        IDotnuggV1 safe,
        uint8 feature,
        uint256 seed
    ) internal view returns (uint8 res) {
        IDotnuggV1File loc = location(safe, feature);

        uint256 high = size(loc);

        // prettier-ignore
        assembly {

            // we adjust the seed to be unique per feature and safe, yet still deterministic

            mstore(0x00, seed)
            mstore(0x20, or(shl(160, feature), safe))

            seed := keccak256( //-----------------------------------------
                0x00, /* [ seed                                  ]    0x20
                0x20     [ uint8(feature) | address(safe)        ] */ 0x40
            ) // ---------------------------------------------------------

            // normalize seed to be <= type(uint16).max
            // if we did not want to use weights, we could just mod by "len" and have our final value
            // without any calcualtion
            seed := mod(seed, 0xffff)

            //////////////////////////////////////////////////////////////////////////

            // Get a pointer to some free memory.
            // no need update pointer becasue after this function, the loaded data is no longer needed
            //    and solidity does not assume the free memory pointer points to "clean" data
            let A := mload(0x40)

            // Copy the code into memory right after the 32 bytes we used to store the len.
            extcodecopy(loc, add(0x20, A), add(DOTNUGG_RUNTIME_BYTE_LEN, 1), mul(high, 2))

            // adjust data pointer to make mload return our uint16[] index easily using below funciton
            A := add(A, 0x2)

            function index(arr, m) -> val {
                val := and(mload(add(arr, shl(1, m))), 0xffff)
            }

            //////////////////////////////////////////////////////////////////////////

            // each dotnuggv1 file includes a sorted weight list that we can use to convert "random" seeds into item numbers:

            // lets say we have an file containing 4 itmes with these as their respective weights:
            // [ 0.10  0.10  0.15  0.15 ]

            // then on chain, an array like this is stored: (represented in decimal for the example)
            // [ 2000  4000  7000  10000 ]

            // assuming we can only pass a seed between 0 and 10000, we know that:
            // - we have an 20% chance, of picking a number less than weight 1      -  0    < x < 2000
            // - we have an 20% chance, of picking a number between weights 1 and 2 -  2000 < x < 4000
            // - we have an 30% chance, of picking a number between weights 2 and 3 -  4000 < x < 7000
            // - we have an 30% chance, of picking a number between weights 3 and 4 -  7000 < x < 10000

            // now, all we need to do is pick a seed, say "6942", and search for which number it is between

            // the higher of which will be the value we are looking for

            // in our example, "6942" is between weights 2 and 3, so [res = 3]

            //////////////////////////////////////////////////////////////////////////

            // right most "successor" binary search
            // https://en.wikipedia.org/wiki/Binary_search_algorithm#Procedure_for_finding_the_rightmost_element

            let L := 0
            let R := high

            for { } lt(L, R) { } {
                let m := shr(1, add(L, R)) // == (L + R) / 2
                switch gt(index(A, m), seed)
                case 1  { R := m         }
                default { L := add(m, 1) }
            }

            // we add one because items are 1 base indexed, not 0
            res := add(R, 1)
        }
    }

    function rarity(
        IDotnuggV1 safe,
        uint8 feature,
        uint8 position
    ) internal view returns (uint16 res) {
        IDotnuggV1File loc = location(safe, uint8(feature));

        assembly {
            switch eq(position, 1)
            case 1 {
                extcodecopy(loc, 30, add(DOTNUGG_RUNTIME_BYTE_LEN, 1), 2)

                res := and(mload(0x00), 0xffff)
            }
            default {
                extcodecopy(loc, 28, add(add(DOTNUGG_RUNTIME_BYTE_LEN, 1), mul(sub(position, 2), 2)), 4)

                res := and(mload(0x00), 0xffffffff)

                let low := shr(16, res)

                res := sub(and(res, 0xffff), low)
            }
        }
    }

    function read(
        IDotnuggV1 safe,
        uint8 feature,
        uint8 position
    ) internal view returns (uint256[] memory res) {
        IDotnuggV1File loc = location(safe, feature);

        uint256 length = size(loc);

        require(position <= length && position != 0, "F:1");

        position = position - 1;

        uint32 startAndEnd = uint32(
            bytes4(readBytecode(loc, DOTNUGG_RUNTIME_BYTE_LEN + length * 2 + 1 + position * 2, 4))
        );

        uint32 begin = startAndEnd >> 16;

        return readBytecodeAsArray(loc, begin, (startAndEnd & 0xffff) - begin);
    }

    // adapted from rari-capital/solmate's SSTORE2.sol
    function readBytecodeAsArray(
        IDotnuggV1File file,
        uint256 start,
        uint256 len
    ) private view returns (uint256[] memory data) {
        assembly {
            let offset := sub(0x20, mod(len, 0x20))

            let arrlen := add(0x01, div(len, 0x20))

            // Get a pointer to some free memory.
            data := mload(0x40)

            // Update the free memory pointer to prevent overriding our data.
            // We use and(x, not(31)) as a cheaper equivalent to sub(x, mod(x, 32)).
            // Adding 31 to size and running the result through the logic above ensures
            // the memory pointer remains word-aligned, following the Solidity convention.
            mstore(0x40, add(data, and(add(add(add(len, 32), offset), 31), not(31))))

            // Store the len of the data in the first 32 byte chunk of free memory.
            mstore(data, arrlen)

            // Copy the code into memory right after the 32 bytes we used to store the len.
            extcodecopy(file, add(add(data, 32), offset), start, len)
        }
    }

    // adapted from rari-capital/solmate's SSTORE2.sol
    function readBytecode(
        IDotnuggV1File file,
        uint256 start,
        uint256 len
    ) private view returns (bytes memory data) {
        assembly {
            // Get a pointer to some free memory.
            data := mload(0x40)

            // Update the free memory pointer to prevent overriding our data.
            // We use and(x, not(31)) as a cheaper equivalent to sub(x, mod(x, 32)).
            // Adding 31 to len and running the result through the logic above ensures
            // the memory pointer remains word-aligned, following the Solidity convention.
            mstore(0x40, add(data, and(add(add(len, 32), 31), not(31))))

            // Store the len of the data in the first 32 byte chunk of free memory.
            mstore(data, len)

            // Copy the code into memory right after the 32 bytes we used to store the len.
            extcodecopy(file, add(data, 32), start, len)
        }
    }

    bytes16 private constant ALPHABET = "0123456789abcdef";

    function toHex(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length);
        for (uint256 i = buffer.length; i > 0; i--) {
            buffer[i - 1] = ALPHABET[value & 0xf];
            value >>= 4;
        }
        return string(buffer);
    }

    ///
    /// inspired by OraclizeAPI's implementation
    /// [ oraclizeAPI_0.4.25.sol : MIT ] - https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol
    function toFixedPointString(uint256 value, uint256 places) internal pure returns (string memory) {
        unchecked {
            if (value == 0) return "0";

            uint256 temp = value;
            uint256 digits;
            while (temp != 0) {
                digits++;
                temp /= 10;
            }

            digits = places == 0 ? digits : (digits > places ? digits : places) + 1;

            bytes memory buffer = new bytes(digits);

            if (places != 0) buffer[digits - places - 1] = ".";

            while (digits != 0) {
                digits -= 1;
                if (buffer[digits] == ".") {
                    if (digits == 0) break;
                    digits -= 1;
                }

                buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
                value /= 10;
            }
            return string(buffer);
        }
    }

    function chunk(
        string memory input,
        uint8 chunks,
        uint8 index
    ) internal pure returns (string memory res) {
        res = input;

        if (chunks == 0) return res;

        assembly {
            let strlen := div(mload(res), chunks)

            let start := mul(strlen, index)

            if gt(strlen, sub(mload(res), start)) {
                strlen := sub(mload(res), start)
            }

            res := add(res, start)

            mstore(res, strlen)
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

// prettier-ignore
interface IDotnuggV1 {
    event Write(uint8 feature, uint8 amount, address sender);

    function register(bytes[] calldata data) external returns (IDotnuggV1 proxy);

    function protectedInit(bytes[] memory input) external;

    function read(uint8[8] memory ids) external view returns (uint256[][] memory data);

    function read(uint8 feature, uint8 pos) external view returns (uint256[] memory data);

    function exec(uint8[8] memory ids, bool base64) external view returns (string memory);

    function exec(uint8 feature, uint8 pos, bool base64) external view returns (string memory);

    function calc(uint256[][] memory reads) external view returns (uint256[] memory calculated, uint256 dat);

    function combo(uint256[][] memory reads, bool base64) external view returns (string memory data);

    function svg(uint256[] memory calculated, uint256 dat, bool base64) external pure returns (string memory res);

    function encodeJson(bytes memory input, bool base64) external pure returns (bytes memory data);

    function encodeSvg(bytes memory input, bool base64) external pure returns (bytes memory data);


}

interface IDotnuggV1File {}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import {INuggftV1Stake} from "./INuggftV1Stake.sol";
import {INuggftV1Proof} from "./INuggftV1Proof.sol";
import {INuggftV1Swap} from "./INuggftV1Swap.sol";
import {INuggftV1Loan} from "./INuggftV1Loan.sol";
import {INuggftV1Epoch} from "./INuggftV1Epoch.sol";
import {INuggftV1Trust} from "./INuggftV1Trust.sol";
import {INuggftV1ItemSwap} from "./INuggftV1ItemSwap.sol";
import {INuggftV1Globals} from "./INuggftV1Globals.sol";

import {IERC721Metadata, IERC721} from "../IERC721.sol";

// prettier-ignore
interface INuggftV1 is
    IERC721,
    IERC721Metadata,
    INuggftV1Stake,
    INuggftV1Proof,
    INuggftV1Swap,
    INuggftV1Loan,
    INuggftV1Epoch,
    INuggftV1Trust,
    INuggftV1ItemSwap,
    INuggftV1Globals
{


}

interface INuggftV1Events {
    event Genesis(uint256 blocknum, uint32 interval, uint24 offset, uint8 intervalOffset, uint24 early, address dotnugg, address xnuggftv1, bytes32 stake);
    event OfferItem(uint24 indexed sellingTokenId, uint16 indexed itemId, bytes32 agency, bytes32 stake);
    event ClaimItem(uint24 indexed sellingTokenId, uint16 indexed itemId, uint24 indexed buyerTokenId, bytes32 proof);
    event SellItem(uint24 indexed sellingTokenId, uint16 indexed itemId, bytes32 agency, bytes32 proof);
    event Loan(uint24 indexed tokenId, bytes32 agency);
    event Rebalance(uint24 indexed tokenId, bytes32 agency);
    event Liquidate(uint24 indexed tokenId, bytes32 agency);
    event MigrateV1Accepted(address v1, uint24 tokenId, bytes32 proof, address owner, uint96 eth);
    event Extract(uint96 eth);
    event MigratorV1Updated(address migrator);
    event MigrateV1Sent(address v2, uint24 tokenId, bytes32 proof, address owner, uint96 eth);
    event Burn(uint24 tokenId, address owner, uint96 ethOwed);
    event Stake(bytes32 stake);
    event Rotate(uint24 indexed tokenId, bytes32 proof);
    event Mint(uint24 indexed tokenId, uint96 value, bytes32 proof, bytes32 stake, bytes32 agency);
    event Offer(uint24 indexed tokenId, bytes32 agency, bytes32 stake);
    event OfferMint(uint24 indexed tokenId, bytes32 agency, bytes32 proof, bytes32 stake);
    event Claim(uint24 indexed tokenId, address indexed account);
    event Sell(uint24 indexed tokenId, bytes32 agency);
    event TrustUpdated(address indexed user, bool trust);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface INuggftV1Stake {
    event Extract(uint96 eth);

    event MigratorV1Updated(address migrator);

    event MigrateV1Sent(address v2, uint24 tokenId, bytes32 proof, address owner, uint96 eth);

    event Stake(bytes32 stake);

    function migrate(uint24 tokenId) external;

    // /// @notice burns a nugg from existance, dealing the eth worth of that share to the user
    // /// @dev should only be called directly
    // /// @param tokenId the id of the nugg being burned
    // function burn(uint24 tokenId) external;

    /// @notice returns the total "eps" held by the contract
    /// @dev this value not always equivilent to the "floor" price which can consist of perceived value.
    /// can be looked at as an "intrinsic floor"
    /// @dev this is the value that users will receive when their either burn or loan out nuggs
    /// @return res -> [current staked eth] / [current staked shares]
    function eps() external view returns (uint96);

    /// @notice returns the minimum eth that must be added to create a new share
    /// @dev premium here is used to push against dillution of supply through ensuring the price always increases
    /// @dev used by the front end
    /// @return res -> premium + protcolFee + ethPerShare
    function msp() external view returns (uint96);

    /// @notice returns the amount of eth extractable by protocol
    /// @dev this will be
    /// @return res -> (PROTOCOL_FEE_FRAC * [all eth staked] / 10000) - [all previously extracted eth]
    function proto() external view returns (uint96);

    /// @notice returns the total number of staked shares held by the contract
    /// @dev this is equivilent to the amount of nuggs in existance
    function shares() external view returns (uint64);

    /// @notice same as shares
    /// @dev for external entities like etherscan
    function totalSupply() external view returns (uint256);

    /// @notice returns the total amount of staked eth held by the contract
    /// @dev can be used as the market-cap or tvl of all nuggft v1
    /// @dev not equivilent to the balance of eth the contract holds, which also has protocolEth ...
    /// + unclaimed eth from unsuccessful swaps + eth from current waps
    function staked() external view returns (uint96);

    /* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                TRUSTED
       ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */

    /// @notice sends the current protocolEth to the user and resets the value to zero
    /// @dev caller must be a trusted user
    function extract() external;

    /// @notice sets the migrator contract
    /// @dev caller must be a trusted user
    /// @param migrator the address to set as the migrator contract
    function setMigrator(address migrator) external;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface INuggftV1Proof {
    event Rotate(uint24 indexed tokenId, bytes32 proof);

    function proofOf(uint24 tokenId) external view returns (uint256 res);

    // prettier-ignore
    function rotate(uint24 tokenId, uint8[] calldata from, uint8[] calldata to) external;

    function imageURI(uint256 tokenId) external view returns (string memory);

    function imageSVG(uint256 tokenId) external view returns (string memory);

    function image123(
        uint256 tokenId,
        bool base64,
        uint8 chunk,
        bytes memory prev
    ) external view returns (bytes memory res);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

// prettier-ignore

interface INuggftV1Swap {
    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param tokenId (uint24)
    /// @param agency  (bytes32) a parameter just like in doxygen (must be followed by parameter name)
    event Offer(uint24 indexed tokenId, bytes32 agency, bytes32 stake);

    event OfferMint(uint24 indexed tokenId, bytes32 agency, bytes32 proof, bytes32 stake);

    event PreMint(uint24 indexed tokenId, bytes32 proof, bytes32 nuggAgency, uint16 indexed itemId, bytes32 itemAgency);

    event Claim(uint24 indexed tokenId, address indexed account);

    event Sell(uint24 indexed tokenId, bytes32 agency);


    /* ///////////////////////////////////////////////////////////////////
                            STATE CHANGING
    /////////////////////////////////////////////////////////////////// */

    function offer(uint24 tokenId) external payable;

    function offer(
        uint24 tokenIdToClaim,
        uint24 nuggToBidOn,
        uint16 itemId,
        uint96 value1,
        uint96 value2
    ) external payable;

    function claim(
        uint24[] calldata tokenIds,
        address[] calldata accounts,
        uint24[] calldata buyingTokenIds,
        uint16[] calldata itemIds
    ) external;

    function sell(uint24 tokenId, uint96 floor) external;

    /*━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                            VIEW FUNCTIONS
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━*/

    /// @notice calculates the minimum eth that must be sent with a offer call
    /// @dev returns 0 if no offer can be made for this oken
    /// @param tokenId -> the token to be offerd to
    /// @param sender -> the address of the user who will be delegating
    /// @return canOffer -> instead of reverting this function will return false
    /// @return nextMinUserOffer -> the minimum value that must be sent with a offer call
    /// @return currentUserOffer ->
    function check(address sender, uint24 tokenId) external view
        returns (
            bool canOffer,
            uint96 nextMinUserOffer,
            uint96 currentUserOffer,
            uint96 currentLeaderOffer,
            uint96 incrementBps
        );

    function vfo(address sender, uint24 tokenId) external view returns (uint96 res);

    function loop() external view returns (bytes memory);

}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface INuggftV1Loan {
    /*━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                EVENTS
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━*/

    event Loan(uint24 indexed tokenId, bytes32 agency);

    event Rebalance(uint24 indexed tokenId, bytes32 agency);

    event Liquidate(uint24 indexed tokenId, bytes32 agency);

    /*━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                            STATE CHANGING
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━*/

    function rebalance(uint24[] calldata tokenIds) external payable;

    function loan(uint24[] calldata tokenIds) external;

    function liquidate(uint24 tokenId) external payable;

    /*━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                            VIEW FUNCTIONS
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━*/

    /// @notice for a nugg's active loan: calculates the current min eth a user must send to liquidate or rebalance
    /// @dev contract     ->
    /// @param tokenId    -> the token who's current loan to check
    /// @return isLoaned  -> indicating if the token is loaned
    /// @return account   -> indicating if the token is loaned
    /// @return prin      -> the current amount loaned out, plus the final rebalance fee
    /// @return fee       -> the fee a user must pay to rebalance (and extend) the loan on their nugg
    /// @return earn      -> the amount of eth the minSharePrice has increased since loan was last rebalanced
    /// @return expire    -> the epoch the loan becomes insolvent
    function debt(uint24 tokenId)
        external
        view
        returns (
            bool isLoaned,
            address account,
            uint96 prin,
            uint96 fee,
            uint96 earn,
            uint24 expire
        );

    /// @notice "Values For Liquadation"
    /// @dev used to tell user how much eth to send for liquidate
    function vfl(uint24[] calldata tokenIds) external view returns (uint96[] memory res);

    /// @notice "Values For Rebalance"
    /// @dev used to tell user how much eth to send for rebalance
    function vfr(uint24[] calldata tokenIds) external view returns (uint96[] memory res);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface INuggftV1Epoch {
    function epoch() external view returns (uint24 res);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface INuggftV1Trust {
    event TrustUpdated(address indexed user, bool trust);

    function setIsTrusted(address user, bool trust) external;

    function isTrusted(address user) external view returns (bool);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface INuggftV1ItemSwap {
    event OfferItem(uint24 indexed sellingTokenId, uint16 indexed itemId, bytes32 agency, bytes32 stake);

    event ClaimItem(uint24 indexed sellingTokenId, uint16 indexed itemId, uint24 indexed buyerTokenId, bytes32 proof);

    event SellItem(uint24 indexed sellingTokenId, uint16 indexed itemId, bytes32 agency, bytes32 proof);

    function offer(
        uint24 buyerTokenId,
        uint24 sellerTokenId,
        uint16 itemId
    ) external payable;

    function sell(
        uint24 sellerTokenId,
        uint16 itemid,
        uint96 floor
    ) external;

    /// @notice calculates the minimum eth that must be sent with a offer call
    /// @dev returns 0 if no offer can be made for this oken
    /// @param buyer -> the token to be offerd to
    /// @param seller -> the address of the user who will be delegating
    /// @param itemId -> the address of the user who will be delegating
    /// @return canOffer -> instead of reverting this function will return false
    /// @return nextMinUserOffer -> the minimum value that must be sent with a offer call
    /// @return currentUserOffer ->
    function check(
        uint24 buyer,
        uint24 seller,
        uint16 itemId
    )
        external
        view
        returns (
            bool canOffer,
            uint96 nextMinUserOffer,
            uint96 currentUserOffer,
            uint96 currentLeaderOffer,
            uint96 incrementBps,
            bool mustClaimBuyer,
            bool mustOfferOnSeller
        );

    function vfo(
        uint24 buyer,
        uint24 seller,
        uint16 itemId
    ) external view returns (uint96 res);
}
//  SellItem(uint24,uint16,bytes32,bytes32);
//     OfferItem(uint24,uint16, bytes32,bytes32);
//  ClaimItem(uint24,uint16,uint24,bytes32);

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import {IDotnuggV1} from "dotnugg-v1-core/IDotnuggV1.sol";

interface INuggftV1Globals {
    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    event Genesis(uint256 blocknum, uint32 interval, uint24 offset, uint8 intervalOffset, uint24 early, address dotnugg, address xnuggftv1, bytes32 stake);

    function genesis() external view returns (uint256 res);

    function stake() external view returns (uint256 res);

    function agency(uint24 tokenId) external view returns (uint256 res);

    function proof(uint24 tokenId) external view returns (uint256 res);

    function migrator() external view returns (address res);

    function early() external view returns (uint24 res);

    function dotnuggv1() external view returns (IDotnuggV1);
}