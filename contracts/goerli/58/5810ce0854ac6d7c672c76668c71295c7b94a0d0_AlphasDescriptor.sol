// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { Strings } from '@openzeppelin/contracts/utils/Strings.sol';
import { IAlphasDescriptor } from './interfaces/IAlphasDescriptor.sol';
import { IAlphasSeeder } from './interfaces/IAlphasSeeder.sol';
import { NFTDescriptor } from './libs/NFTDescriptor.sol';
import { MultiPartRLEToSVG } from './libs/MultiPartRLEToSVG.sol';

contract AlphasDescriptor is IAlphasDescriptor, Ownable {
    using Strings for uint256;

    // Whether or not new Alpha parts can be added
    bool public override arePartsLocked;

    // Whether or not `tokenURI` should be returned as a data URI (Default: true)
    bool public override isDataURIEnabled = true;

    // Base URI
    string public override baseURI;

    // Alpha Color Palettes (Index => Hex Colors)
    mapping(uint8 => string[]) public override palettes;

    // Alpha Backgrounds (Hex Colors)
    string[] public override bgColors;

    // Alpha Backgrounds (Hex Colors)
    bytes[] public override backgrounds;

    // Alpha Bodies (Custom RLE)
    bytes[] public override bodies;

    // Alpha Accessories (Custom RLE)
    bytes[] public override accessories;

    // Alpha Heads (Custom RLE)
    bytes[] public override heads;

    // Alpha Backgrounds (Hex Colors)
    string[] public override backgroundNames;

    // Alpha Bodies (Custom RLE)
    string[] public override bodyNames;

    // Alpha Accessories (Custom RLE)
    string[] public override accessoryNames;

    // Alpha Heads (Custom RLE)
    string[] public override headNames;

    /**
     * @notice Require that the parts have not been locked.
     */
    modifier whenPartsNotLocked() {
        require(!arePartsLocked, 'Parts are locked');
        _;
    }

    /**
     * @notice Get the number of available Alpha `backgrounds`.
     */
    function backgroundCount() external view override returns (uint256) {
        return backgrounds.length;
    }

    /**
     * @notice Get the number of available Alpha `backgrounds`.
     */
    function bgColorsCount() external view override returns (uint256) {
        return bgColors.length;
    }

    /**
     * @notice Get the number of available Alpha `bodies`.
     */
    function bodyCount() external view override returns (uint256) {
        return bodies.length;
    }

    /**
     * @notice Get the number of available Alpha `accessories`.
     */
    function accessoryCount() external view override returns (uint256) {
        return accessories.length;
    }

    /**
     * @notice Get the number of available Alpha `heads`.
     */
    function headCount() external view override returns (uint256) {
        return heads.length;
    }

    /**
     * @notice Add colors to a color palette.
     * @dev This function can only be called by the owner.
     */
    function addManyColorsToPalette(uint8 paletteIndex, string[] calldata newColors) external override onlyOwner {
        require(palettes[paletteIndex].length + newColors.length <= 264, 'Palettes can only hold 265 colors');
        for (uint256 i = 0; i < newColors.length; i++) {
            _addColorToPalette(paletteIndex, newColors[i]);
        }
    }

    /**
     * @notice Batch add Alpha backgrounds.
     * @dev This function can only be called by the owner when not locked.
     */
    function addManyBgColors(string[] calldata _bgColors) external override onlyOwner whenPartsNotLocked {
        for (uint256 i = 0; i < _bgColors.length; i++) {
            _addBgColor(_bgColors[i]);
        }
    }

    /**
     * @notice Batch add Alpha backgrounds.
     * @dev This function can only be called by the owner when not locked.
     */
    function addManyBackgrounds(bytes[] calldata _backgrounds, string[] calldata _backgroundNames) external override onlyOwner whenPartsNotLocked {
        require(_backgrounds.length == _backgroundNames.length);
        for (uint256 i = 0; i < _backgrounds.length; i++) {
            _addBackground(_backgrounds[i]);
            _addBackgroundName(_backgroundNames[i]);
        }
    }

    /**
     * @notice Batch add Alpha bodies.
     * @dev This function can only be called by the owner when not locked.
     */
    function addManyBodies(bytes[] calldata _bodies, string[] calldata _bodyNames) external override onlyOwner whenPartsNotLocked {
        require(_bodies.length == _bodyNames.length);
        for (uint256 i = 0; i < _bodies.length; i++) {
            _addBody(_bodies[i]);
            _addBodyName(_bodyNames[i]);
        }
    }

    /**
     * @notice Batch add Alpha accessories.
     * @dev This function can only be called by the owner when not locked.
     */
    function addManyAccessories(bytes[] calldata _accessories, string[] calldata _accessoryNames) external override onlyOwner whenPartsNotLocked {
        require(_accessories.length == _accessoryNames.length);
        for (uint256 i = 0; i < _accessories.length; i++) {
            _addAccessory(_accessories[i]);
            _addAccessoryName(_accessoryNames[i]);
        }
    }

    /**
     * @notice Batch add Alpha heads.
     * @dev This function can only be called by the owner when not locked.
     */
    function addManyHeads(bytes[] calldata _heads, string[] calldata _headNames) external override onlyOwner whenPartsNotLocked {
        require(_heads.length == _headNames.length);
        for (uint256 i = 0; i < _heads.length; i++) {
            _addHead(_heads[i]);
            _addHeadName(_headNames[i]);
        }
    }

    /**
     * @notice Add a single color to a color palette.
     * @dev This function can only be called by the owner.
     */
    function addColorToPalette(uint8 _paletteIndex, string calldata _color) external override onlyOwner {
        require(palettes[_paletteIndex].length <= 255, 'Palettes can only hold 256 colors');
        _addColorToPalette(_paletteIndex, _color);
    }

    /**
     * @notice Add a Alpha background.
     * @dev This function can only be called by the owner when not locked.
     */
    function addBgColor(string calldata _bgColor) external override onlyOwner whenPartsNotLocked {
        _addBgColor(_bgColor);
    }

    /**
     * @notice Add a Alpha background.
     * @dev This function can only be called by the owner when not locked.
     */
    function addBackground(bytes calldata _background, string calldata _backgroundName) external override onlyOwner whenPartsNotLocked {
        _addBackground(_background);
        _addBackgroundName(_backgroundName);
    }

    /**
     * @notice Add a Alpha body.
     * @dev This function can only be called by the owner when not locked.
     */
    function addBody(bytes calldata _body, string calldata _bodyName) external override onlyOwner whenPartsNotLocked {
        _addBody(_body);
        _addBodyName(_bodyName);
    }

    /**
     * @notice Add a Alpha accessory.
     * @dev This function can only be called by the owner when not locked.
     */
    function addAccessory(bytes calldata _accessory, string calldata _accessoryName) external override onlyOwner whenPartsNotLocked {
        _addAccessory(_accessory);
        _addAccessoryName(_accessoryName);
    }

    /**
     * @notice Add a Alpha head.
     * @dev This function can only be called by the owner when not locked.
     */
    function addHead(bytes calldata _head, string calldata _headName) external override onlyOwner whenPartsNotLocked {
        _addHead(_head);
        _addHeadName(_headName);
    }

    /**
     * @notice Lock all Alpha parts.
     * @dev This cannot be reversed and can only be called by the owner when not locked.
     */
    function lockParts() external override onlyOwner whenPartsNotLocked {
        arePartsLocked = true;

        emit PartsLocked();
    }

    /**
     * @notice Toggle a boolean value which determines if `tokenURI` returns a data URI
     * or an HTTP URL.
     * @dev This can only be called by the owner.
     */
    function toggleDataURIEnabled() external override onlyOwner {
        bool enabled = !isDataURIEnabled;

        isDataURIEnabled = enabled;
        emit DataURIToggled(enabled);
    }

    /**
     * @notice Set the base URI for all token IDs. It is automatically
     * added as a prefix to the value returned in {tokenURI}, or to the
     * token ID if {tokenURI} is empty.
     * @dev This can only be called by the owner.
     */
    function setBaseURI(string calldata _baseURI) external override onlyOwner {
        baseURI = _baseURI;

        emit BaseURIUpdated(_baseURI);
    }

    /**
     * @notice Given a token ID and seed, construct a token URI for an official Alphas Treasury alpha.
     * @dev The returned value may be a base64 encoded data URI or an API URL.
     */
    function tokenURI(uint256 tokenId, IAlphasSeeder.Seed memory seed, uint256 birthday) external view override returns (string memory) {
        if (isDataURIEnabled) {
            return dataURI(tokenId, seed, birthday);
        }
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    /**
     * @notice Given a token ID and seed, construct a base64 encoded data URI for an official Alphas Treasury alpha.
     */
    function dataURI(uint256 tokenId, IAlphasSeeder.Seed memory seed, uint256 _birthday) public view override returns (string memory) {
        string memory alphaId = tokenId.toString();
        string memory name = string(abi.encodePacked('Alpha ', alphaId));
        string memory description = string(abi.encodePacked('Alpha ', alphaId, ' is a member of the Alphas Treasury'));
        string memory birthday = _birthday.toString();

        return genericDataURI(name, description, seed, birthday);
    }

    /**
     * @notice Given a name, description, and seed, construct a base64 encoded data URI.
     */
    function genericDataURI(
        string memory name,
        string memory description,
        IAlphasSeeder.Seed memory seed,
        string memory birthday
    ) public view override returns (string memory) {
        NFTDescriptor.TokenURIParams memory params = NFTDescriptor.TokenURIParams({
            name: name,
            description: description,
            parts: _getPartsForSeed(seed),
            background: bgColors[seed.background],
            names: _getAttributesForSeed(seed, birthday)
        });
        return NFTDescriptor.constructTokenURI(params, palettes);
    }

    /**
     * @notice Given a seed, construct a base64 encoded SVG image.
     */
    function generateSVGImage(IAlphasSeeder.Seed memory seed) external view override returns (string memory) {
        MultiPartRLEToSVG.SVGParams memory params = MultiPartRLEToSVG.SVGParams({
            parts: _getPartsForSeed(seed),
            background: bgColors[seed.background]
        });
        return NFTDescriptor.generateSVGImage(params, palettes);
    }

    /**
     * @notice Add a single color to a color palette.
     */
    function _addColorToPalette(uint8 _paletteIndex, string calldata _color) internal {
        palettes[_paletteIndex].push(_color);
    }

    /**
     * @notice Add a Alpha background.
     */
    function _addBgColor(string calldata _bgColor) internal {
        bgColors.push(_bgColor);
    }

    /**
     * @notice Add a Alpha background.
     */
    function _addBackground(bytes calldata _background) internal {
        backgrounds.push(_background);
    }

    /**
     * @notice Add a Alpha body.
     */
    function _addBody(bytes calldata _body) internal {
        bodies.push(_body);
    }

    /**
     * @notice Add a Alpha accessory.
     */
    function _addAccessory(bytes calldata _accessory) internal {
        accessories.push(_accessory);
    }

    /**
     * @notice Add a Alpha head.
     */
    function _addHead(bytes calldata _head) internal {
        heads.push(_head);
    }

    /**
     * @notice Add a Alpha background.
     */
    function _addBackgroundName(string calldata _backgroundName) internal {
        backgroundNames.push(_backgroundName);
    }

    /**
     * @notice Add a Alpha body.
     */
    function _addBodyName(string calldata _bodyName) internal {
        bodyNames.push(_bodyName);
    }

    /**
     * @notice Add a Alpha accessory.
     */
    function _addAccessoryName(string calldata _accessoryName) internal {
        accessoryNames.push(_accessoryName);
    }

    /**
     * @notice Add a Alpha head.
     */
    function _addHeadName(string calldata _headName) internal {
        headNames.push(_headName);
    }

    /**
     * @notice Get all Alpha parts for the passed `seed`.
     */
    function _getPartsForSeed(IAlphasSeeder.Seed memory seed) internal view returns (bytes[] memory) {
        bytes[] memory _parts = new bytes[](4);
        _parts[0] = backgrounds[seed.background];
        _parts[1] = bodies[seed.body];
        _parts[2] = heads[seed.head];
        _parts[3] = accessories[seed.accessory];
        return _parts;
    }

    /**
     * @notice Get all Alpha attributes for the passed `seed`.
     */
    function _getAttributesForSeed(IAlphasSeeder.Seed memory seed, string memory birthday) internal view returns (string[] memory) {
        string[] memory _attributes = new string[](5);
        _attributes[0] = backgroundNames[seed.background];
        _attributes[1] = bodyNames[seed.body];
        _attributes[2] = headNames[seed.head];
        _attributes[3] = accessoryNames[seed.accessory];
        _attributes[4] = birthday;
        return _attributes;
    }
}

// SPDX-License-Identifier: MIT

/// @title A library used to convert multi-part RLE compressed images to SVG



pragma solidity ^0.8.6;

library MultiPartRLEToSVG {
    struct SVGParams {
        bytes[] parts;
        string background;
    }

    struct ContentBounds {
        uint8 top;
        uint8 right;
        uint8 bottom;
        uint8 left;
    }

    struct Rect {
        uint8 length;
        uint8 colorIndex;
    }

    struct DecodedImage {
        uint8 paletteIndex;
        ContentBounds bounds;
        Rect[] rects;
    }

    /**
     * @notice Given RLE image parts and color palettes, merge to generate a single SVG image.
     */
    function generateSVG(SVGParams memory params, mapping(uint8 => string[]) storage palettes)
        internal
        view
        returns (string memory svg)
    {
        // prettier-ignore
        return string(
            abi.encodePacked(
                '<svg width="320" height="320" viewBox="0 0 320 320" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">',
                '<rect width="100%" height="100%" fill="#', params.background, '" />',
                _generateSVGRects(params, palettes),
                '</svg>'
            )
        );
    }

    /**
     * @notice Given RLE image parts and color palettes, generate SVG rects.
     */
    // prettier-ignore
    function _generateSVGRects(SVGParams memory params, mapping(uint8 => string[]) storage palettes)
        private
        view
        returns (string memory svg)
    {
        string[33] memory lookup = [
            '0', '10', '20', '30', '40', '50', '60', '70', 
            '80', '90', '100', '110', '120', '130', '140', '150', 
            '160', '170', '180', '190', '200', '210', '220', '230', 
            '240', '250', '260', '270', '280', '290', '300', '310',
            '320' 
        ];
        string memory rects;
        for (uint8 p = 0; p < params.parts.length; p++) {
            DecodedImage memory image = _decodeRLEImage(params.parts[p]);
            string[] storage palette = palettes[image.paletteIndex];
            uint256 currentX = image.bounds.left;
            uint256 currentY = image.bounds.top;
            uint256 cursor;
            string[16] memory buffer;

            string memory part;
            for (uint256 i = 0; i < image.rects.length; i++) {
                Rect memory rect = image.rects[i];
                if (rect.colorIndex != 0) {
                    buffer[cursor] = lookup[rect.length];          // width
                    buffer[cursor + 1] = lookup[currentX];         // x
                    buffer[cursor + 2] = lookup[currentY];         // y
                    buffer[cursor + 3] = palette[rect.colorIndex]; // color

                    cursor += 4;

                    if (cursor >= 16) {
                        part = string(abi.encodePacked(part, _getChunk(cursor, buffer)));
                        cursor = 0;
                    }
                }

                currentX += rect.length;
                if (currentX == image.bounds.right) {
                    currentX = image.bounds.left;
                    currentY++;
                }
            }

            if (cursor != 0) {
                part = string(abi.encodePacked(part, _getChunk(cursor, buffer)));
            }
            rects = string(abi.encodePacked(rects, part));
        }
        return rects;
    }

    /**
     * @notice Return a string that consists of all rects in the provided `buffer`.
     */
    // prettier-ignore
    function _getChunk(uint256 cursor, string[16] memory buffer) private pure returns (string memory) {
        string memory chunk;
        for (uint256 i = 0; i < cursor; i += 4) {
            chunk = string(
                abi.encodePacked(
                    chunk,
                    '<rect width="', buffer[i], '" height="10" x="', buffer[i + 1], '" y="', buffer[i + 2], '" fill="#', buffer[i + 3], '" />'
                )
            );
        }
        return chunk;
    }

    /**
     * @notice Decode a single RLE compressed image into a `DecodedImage`.
     */
    function _decodeRLEImage(bytes memory image) private pure returns (DecodedImage memory) {
        uint8 paletteIndex = uint8(image[0]);
        ContentBounds memory bounds = ContentBounds({
            top: uint8(image[1]),
            right: uint8(image[2]),
            bottom: uint8(image[3]),
            left: uint8(image[4])
        });

        uint256 cursor;
        Rect[] memory rects = new Rect[]((image.length - 5) / 2);
        for (uint256 i = 5; i < image.length; i += 2) {
            rects[cursor] = Rect({ length: uint8(image[i]), colorIndex: uint8(image[i + 1]) });
            cursor++;
        }
        return DecodedImage({ paletteIndex: paletteIndex, bounds: bounds, rects: rects });
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import { Base64 } from 'base64-sol/base64.sol';
import { MultiPartRLEToSVG } from './MultiPartRLEToSVG.sol';

library NFTDescriptor {
    struct TokenURIParams {
        string name;
        string description;
        bytes[] parts;
        string background;
        string[] names;
    }

    /**
     * @notice Construct an ERC721 token URI.
     */
    function constructTokenURI(TokenURIParams memory params, mapping(uint8 => string[]) storage palettes)
        public
        view
        returns (string memory)
    {
        string memory image = generateSVGImage(
            MultiPartRLEToSVG.SVGParams({ parts: params.parts, background: params.background }),
            palettes
        );

        string memory attributes = generateAttributes(params.names);

        // prettier-ignore
        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        abi.encodePacked('{"name":"', params.name, '", "description":"', params.description, '", "image": "', 'data:image/svg+xml;base64,', image, '", "attributes":', attributes, '}')
                    )
                )
            )
        );
    }

    /**
     * @notice Generate an SVG image for use in the ERC721 token URI.
     */
    function generateSVGImage(MultiPartRLEToSVG.SVGParams memory params, mapping(uint8 => string[]) storage palettes)
        public
        view
        returns (string memory svg)
    {
        return Base64.encode(bytes(MultiPartRLEToSVG.generateSVG(params, palettes)));
    }

    function generateAttributes(string[] memory _attributes) public view returns (string memory) {
        string memory traits;
        traits = string(abi.encodePacked(
            attributeForTypeAndValue("Background", _attributes[0]),',',
            attributeForTypeAndValue("Body", _attributes[1]),',',
            attributeForTypeAndValue("Breed", _attributes[2]),',',
            attributeForTypeAndValue("Collar", _attributes[3]),',',
            attributeForDateAndValue("Birthday", _attributes[4])
            ));

        return string(abi.encodePacked(
            '[',
            traits,
            ']'
            ));
        }

    function attributeForTypeAndValue(string memory traitType, string memory value) internal pure returns (string memory) {
        return string(abi.encodePacked(
        '{"trait_type":"',
        traitType,
        '","value":"',
        value,
        '"}'
        ));
    }

    function attributeForDateAndValue(string memory traitType, string memory value) internal pure returns (string memory) {
        return string(abi.encodePacked(
        '{"display_type":"date',
        '","trait_type":"',
        traitType,
        '","value":"',
        value,
        '"}'
        ));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import { IAlphasDescriptor } from './IAlphasDescriptor.sol';

interface IAlphasSeeder {
    struct Seed {
        uint48 background;
        uint48 body;
        uint48 accessory;
        uint48 head;
    }

    function generateSeed(uint256 alphaId, IAlphasDescriptor descriptor) external view returns (Seed memory);
}

// SPDX-License-Identifier: MIT

/// @title Interface for AlphasDescriptor



pragma solidity ^0.8.6;

import { IAlphasSeeder } from './IAlphasSeeder.sol';

interface IAlphasDescriptor {
    event PartsLocked();

    event DataURIToggled(bool enabled);

    event BaseURIUpdated(string baseURI);

    function arePartsLocked() external returns (bool);

    function isDataURIEnabled() external returns (bool);

    function baseURI() external returns (string memory);

    function palettes(uint8 paletteIndex, uint256 colorIndex) external view returns (string memory);

    function bgColors(uint256 index) external view returns (string memory);

    function backgrounds(uint256 index) external view returns (bytes memory);

    function bodies(uint256 index) external view returns (bytes memory);

    function accessories(uint256 index) external view returns (bytes memory);

    function heads(uint256 index) external view returns (bytes memory);

    function backgroundNames(uint256 index) external view returns (string memory);

    function bodyNames(uint256 index) external view returns (string memory);

    function accessoryNames(uint256 index) external view returns (string memory);

    function headNames(uint256 index) external view returns (string memory);

    function bgColorsCount() external view returns (uint256);

    function backgroundCount() external view returns (uint256);

    function bodyCount() external view returns (uint256);

    function accessoryCount() external view returns (uint256);

    function headCount() external view returns (uint256);

    function addManyColorsToPalette(uint8 paletteIndex, string[] calldata newColors) external;

    function addManyBgColors(string[] calldata bgColors) external;

    function addManyBackgrounds(bytes[] calldata backgrounds, string[] calldata backgroundNames) external;

    function addManyBodies(bytes[] calldata bodies, string[] calldata bodyNames) external;

    function addManyAccessories(bytes[] calldata accessories, string[] calldata accessoryNames) external;

    function addManyHeads(bytes[] calldata heads, string[] calldata headNames) external;

    function addColorToPalette(uint8 paletteIndex, string calldata color) external;

    function addBgColor(string calldata bgColor) external;

    function addBackground(bytes calldata background, string calldata backgroundName) external;

    function addBody(bytes calldata body, string calldata bodyName) external;

    function addAccessory(bytes calldata accessory, string calldata accessoryName) external;

    function addHead(bytes calldata head, string calldata headName) external;

    function lockParts() external;

    function toggleDataURIEnabled() external;

    function setBaseURI(string calldata baseURI) external;

    function tokenURI(uint256 tokenId, IAlphasSeeder.Seed memory seed, uint256 birthday) external view returns (string memory);

    function dataURI(uint256 tokenId, IAlphasSeeder.Seed memory seed, uint256 birthday) external view returns (string memory);

    function genericDataURI(
        string calldata name,
        string calldata description,
        IAlphasSeeder.Seed memory seed,
        string calldata birthday
    ) external view returns (string memory);

    function generateSVGImage(IAlphasSeeder.Seed memory seed) external view returns (string memory);
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

pragma solidity >=0.6.0;

/// @title Base64
/// @author Brecht Devos - <[email protected]ring.org>
/// @notice Provides functions for encoding/decoding base64
library Base64 {
    string internal constant TABLE_ENCODE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    bytes  internal constant TABLE_DECODE = hex"0000000000000000000000000000000000000000000000000000000000000000"
                                            hex"00000000000000000000003e0000003f3435363738393a3b3c3d000000000000"
                                            hex"00000102030405060708090a0b0c0d0e0f101112131415161718190000000000"
                                            hex"001a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132330000000000";

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';

        // load the table into memory
        string memory table = TABLE_ENCODE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 3 bytes at a time
            for {} lt(dataPtr, endPtr) {}
            {
                // read 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // write 4 characters
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr( 6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(        input,  0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }

        return result;
    }

    function decode(string memory _data) internal pure returns (bytes memory) {
        bytes memory data = bytes(_data);

        if (data.length == 0) return new bytes(0);
        require(data.length % 4 == 0, "invalid base64 decoder input");

        // load the table into memory
        bytes memory table = TABLE_DECODE;

        // every 4 characters represent 3 bytes
        uint256 decodedLen = (data.length / 4) * 3;

        // add some extra buffer at the end required for the writing
        bytes memory result = new bytes(decodedLen + 32);

        assembly {
            // padding with '='
            let lastBytes := mload(add(data, mload(data)))
            if eq(and(lastBytes, 0xFF), 0x3d) {
                decodedLen := sub(decodedLen, 1)
                if eq(and(lastBytes, 0xFFFF), 0x3d3d) {
                    decodedLen := sub(decodedLen, 1)
                }
            }

            // set the actual output length
            mstore(result, decodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 4 characters at a time
            for {} lt(dataPtr, endPtr) {}
            {
               // read 4 characters
               dataPtr := add(dataPtr, 4)
               let input := mload(dataPtr)

               // write 3 bytes
               let output := add(
                   add(
                       shl(18, and(mload(add(tablePtr, and(shr(24, input), 0xFF))), 0xFF)),
                       shl(12, and(mload(add(tablePtr, and(shr(16, input), 0xFF))), 0xFF))),
                   add(
                       shl( 6, and(mload(add(tablePtr, and(shr( 8, input), 0xFF))), 0xFF)),
                               and(mload(add(tablePtr, and(        input , 0xFF))), 0xFF)
                    )
                )
                mstore(resultPtr, shl(232, output))
                resultPtr := add(resultPtr, 3)
            }
        }

        return result;
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