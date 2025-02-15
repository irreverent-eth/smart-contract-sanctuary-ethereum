// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Base64.sol';
import "@openzeppelin/contracts/utils/Strings.sol";
import './IMetadataRenderer.sol';

/**
 * A Metadata Renderer with on-chain metadata interpolation and off-chain SVG rendering
 */
contract HybridMetadataRenderer is Ownable, IMetadataRenderer {
  string public svgRenderingURI;

  constructor(string memory _svgRenderingURI) Ownable() {
    svgRenderingURI = _svgRenderingURI;
  }

  function setSvgRenderingURI(string memory _svgRenderingURI) public onlyOwner {
    svgRenderingURI = _svgRenderingURI;
  }

  function renderName(Metadata memory metadata) internal pure returns (string memory nameStr) {
    if(metadata.bannerType == BannerType.FOUNDER) {
      nameStr = string(abi.encodePacked('#', Strings.toString(metadata.tokenId), ': Founders Ticket'));
    } else if(metadata.bannerType == BannerType.EXCLUSIVE) {
      nameStr = string(abi.encodePacked('#', Strings.toString(metadata.tokenId), ': Exclusive Pods'));
    } else if(metadata.bannerType == BannerType.PRIME) {
      nameStr = string(abi.encodePacked('#', Strings.toString(metadata.tokenId), ': Prime Teleporter'));
    } else if(metadata.bannerType == BannerType.REPLICANT) {
      nameStr = string(abi.encodePacked('#', Strings.toString(metadata.tokenId), ': Replicant Trait Withdrawal Pods'));
    } else if(metadata.bannerType == BannerType.SECRET) {
      nameStr = string(abi.encodePacked('#', Strings.toString(metadata.tokenId), ': Secret OBR Rare'));
    } else {
      revert();
    }
  }

  function renderDescription(Metadata memory metadata) internal pure returns (string memory descriptionString) {
    if(metadata.bannerType == BannerType.FOUNDER) {
      descriptionString = string(abi.encodePacked('Avastar Memory Banner, Founder, #', Strings.toString(metadata.avastarId), ', Founders Ticket, Original Art by [Marmota vs Milky](https://www.twine.fm/marmotavsmilky)'));
    } else if(metadata.bannerType == BannerType.EXCLUSIVE) {
      descriptionString = string(abi.encodePacked('Avastar Memory Banner, Exclusive, #', Strings.toString(metadata.avastarId), ', Exclusive Pods, Portrait ', renderAvastarImageValue(metadata) ,', Original Art by [Marmota vs Milky](https://www.twine.fm/marmotavsmilky)'));
    } else if(metadata.bannerType == BannerType.PRIME) {
      descriptionString = string(abi.encodePacked('Avastar Memory Banner, Prime, #', Strings.toString(metadata.avastarId), ', Prime Teleporter, Background ', renderBGValue(metadata),', Original Art by [Marmota vs Milky](https://www.twine.fm/marmotavsmilky)'));
    } else if(metadata.bannerType == BannerType.REPLICANT) {
      descriptionString = string(abi.encodePacked('Avastar Memory Banner, Replicant, #', Strings.toString(metadata.avastarId), ', Replicant Trait Withdrawal Pods, Background ', renderBGValue(metadata),', Original Art by [Marmota vs Milky](https://www.twine.fm/marmotavsmilky)'));
    } else if(metadata.bannerType == BannerType.SECRET) {
      descriptionString = string(abi.encodePacked('Avastar Memory Banner, Secret OBR Rare, Original Art by [Marmota vs Milky](https://www.twine.fm/marmotavsmilky)'));
    } else {
      revert();
    }
  }

  function renderImage(Metadata memory metadata) internal view returns (string memory imageStr) {
    imageStr = string(abi.encodePacked(svgRenderingURI, '/type/', Strings.toString(uint256(metadata.bannerType)), '/bg/', Strings.toString(uint256(metadata.backgroundType)), '/avastar/', Strings.toString(metadata.avastarId), '/', Strings.toString(uint256(metadata.avastarImageType)) ));
  }

  function renderBGValue(Metadata memory metadata) internal pure returns (string memory bgValueStr) {
    require(metadata.backgroundType != BackgroundType.INVALID);
    if(metadata.bannerType == BannerType.PRIME) {
      require(uint(metadata.backgroundType) < uint(BackgroundType.R1));
      bgValueStr = string(abi.encodePacked('P', Strings.toString(uint(metadata.backgroundType) - uint(BackgroundType.P1) + 1)));
    } else if(metadata.bannerType == BannerType.REPLICANT) {
      require(uint(metadata.backgroundType) >= uint(BackgroundType.R1));
      bgValueStr = string(abi.encodePacked('R', Strings.toString(uint(metadata.backgroundType) - uint(BackgroundType.R1) + 1)));
    } else {
      revert();
    }
  }

  function renderAvastarImageValue(Metadata memory metadata) internal pure returns (string memory avastarImageValueStr) {
    require(metadata.avastarImageType != AvastarImageType.INVALID);
    if (metadata.avastarImageType == AvastarImageType.PRISTINE) {
      avastarImageValueStr = 'Pristine';
    } else if (metadata.avastarImageType == AvastarImageType.STYLED) {
      avastarImageValueStr = 'Styled';
    }

  }

  function renderAttributes(Metadata memory metadata) internal pure returns (string memory attributeStr) {
    if(metadata.bannerType == BannerType.FOUNDER) {
      attributeStr = string(abi.encodePacked('{"trait_type":"Type","value":"Founders Ticket"}'));
    } else if(metadata.bannerType == BannerType.EXCLUSIVE) {
      attributeStr = string(abi.encodePacked('{"trait_type":"Type","value":"Exclusive Pods"},{"trait_type":"Avastar Image","value":"',renderAvastarImageValue(metadata),'"}'));
    } else if(metadata.bannerType == BannerType.PRIME) {
      attributeStr = string(abi.encodePacked('{"trait_type":"Type","value":"Prime Teleporter"},{"trait_type":"Wave","value":"Prime"},{"trait_type":"BG Color","value":"',renderBGValue(metadata),'"}'));
    } else if(metadata.bannerType == BannerType.REPLICANT) {
      attributeStr = string(abi.encodePacked('{"trait_type":"Type","value":"Replicant Trait Withdrawal Pods"},{"trait_type":"Wave","value":"Replicant"},{"trait_type":"BG Color","value":"',renderBGValue(metadata),'"}'));
    } else if(metadata.bannerType == BannerType.SECRET) {
      attributeStr = string(abi.encodePacked('{"trait_type":"Type","value":"Secret OBR Rare"}'));
    } else {
      revert();
    }
  }

  function renderMetadataString(Metadata memory metadata) internal view returns (string memory metadataStr) {
    metadataStr = string(abi.encodePacked(
      '{"name":"', renderName(metadata) ,'","description":"',renderDescription(metadata),'","image":"',renderImage(metadata),'","attributes":[',renderAttributes(metadata),']}'
    ));
  }

  function renderMetadata(Metadata memory metadata) external view returns (string memory metadataStr) {
    return renderMetadataString(metadata);
  }

  function renderTokenURI(Metadata memory metadata) external view returns (string memory tokenURI) {
    return string(abi.encodePacked(
      'data:application/json;base64,',
      Base64.encode(bytes(renderMetadataString(metadata)))
    ));
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IMetadataRenderer {

  enum BannerType {
    INVALID,
    FOUNDER,
    EXCLUSIVE,
    PRIME,
    REPLICANT,
    SECRET
  }

  enum BackgroundType {
    INVALID,
    P1, P2, P3, P4,
    R1, R2, R3, R4
  }

  enum AvastarImageType {
    INVALID,
    PRISTINE,
    STYLED
  }

  struct Metadata {
    BannerType       bannerType;
    BackgroundType   backgroundType;
    AvastarImageType avastarImageType;
    uint16           tokenId;
    uint16           avastarId;
  }

  function renderMetadata(Metadata memory ) external view returns (string memory);
  function renderTokenURI(Metadata memory ) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Base64.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides a set of functions to operate with Base64 strings.
 *
 * _Available since v4.5._
 */
library Base64 {
    /**
     * @dev Base64 Encoding/Decoding Table
     */
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /**
     * @dev Converts a `bytes` to its Bytes64 `string` representation.
     */
    function encode(bytes memory data) internal pure returns (string memory) {
        /**
         * Inspired by Brecht Devos (Brechtpd) implementation - MIT licence
         * https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
         */
        if (data.length == 0) return "";

        // Loads the table into memory
        string memory table = _TABLE;

        // Encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // The final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> Round up
        // - `/ 3`              -> Number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        string memory result = new string(4 * ((data.length + 2) / 3));

        /// @solidity memory-safe-assembly
        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 32)

            // Run over the input, 3 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {

            } {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // To write each character, shift the 3 bytes (18 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F which is the number of
                // the previous character in the ASCII table prior to the Base64 Table
                // The result is then added to the table to get the character to write,
                // and finally write it in the result pointer but with a left shift
                // of 256 (1 byte) - 8 (1 ASCII char) = 248 bits

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }

            // When data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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

// SPDX-License-Identifier: MIT
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