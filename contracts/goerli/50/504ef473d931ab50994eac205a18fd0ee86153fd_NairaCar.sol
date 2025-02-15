// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ERC721A.sol";
import "./MerkleProof.sol";
import "./Ownable.sol";
import "./Address.sol";
import "./ReentrancyGuard.sol";

contract NairaCar is ERC721A, ReentrancyGuard, Ownable {
  
  uint256 public mintPrice = 0.002 ether;
  uint256 public presalePrice = 0.001 ether;

  uint256 private reserveAtATime = 100;
  uint256 private reservedCount = 0;
  uint256 private maxReserveCount = 100;

  bytes32 public merkleRoot;
  string _baseTokenURI;

  bool public isActive = false;
  bool public isPresaleActive = false;

  uint256 public MAX_SUPPLY = 5555;
  uint256 public maximumAllowedTokensPerPurchase = 3;
  uint256 public maximumAllowedTokensPerWallet = 9;

  constructor(string memory baseURI) ERC721A("NairaCar", "NC") {
    setBaseURI(baseURI);
  }

  modifier saleIsOpen(uint256 _mintAmount) {
    uint256 currentSupply = totalSupply();

    require(currentSupply <= MAX_SUPPLY, "Sale has ended.");
    require(currentSupply + _mintAmount <= MAX_SUPPLY, "All CNR minted.");
    _;
  }

  modifier isValidMerkleProof(bytes32[] calldata merkleProof) {
        require(
            MerkleProof.verify(
                merkleProof,
                merkleRoot,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "Address does not exist in list"
        );
      _;
  }

  modifier mintCompliance(uint256 _mintAmount) {
    require(tx.origin == msg.sender, "Calling from other contract is not allowed.");
    require(
      _mintAmount > 0 && numberMinted(msg.sender) + _mintAmount <= maximumAllowedTokensPerWallet,
       "Invalid mint amount or minted max amount already."
    );
    _;
  }

  function numberMinted(address owner) public view returns (uint256) {
    return _numberMinted(owner);
  }

  function setMerkleRootHash(bytes32 _rootHash) public onlyOwner {
    merkleRoot = _rootHash;
  }

  function setMaxReserve(uint256 val) public onlyOwner {
    maxReserveCount = val;
  }

  function setReserveAtATime(uint256 val) public onlyOwner {
    reserveAtATime = val;
  }

  function getReserveAtATime() external view returns (uint256) {
    return reserveAtATime;
  }


  function setMaximumAllowedTokens(uint256 _count) public onlyOwner {
    maximumAllowedTokensPerPurchase = _count;
  }

  function setMaximumAllowedTokensPerWallet(uint256 _count) public onlyOwner {
    maximumAllowedTokensPerWallet = _count;
  }

  function setMaxMintSupply(uint256 maxMintSupply) external  onlyOwner {
    MAX_SUPPLY = maxMintSupply;
  }

  function setPrice(uint256 _price) public onlyOwner {
    mintPrice = _price;
  }

  function setPresalePrice(uint256 _preslaePrice) public onlyOwner {
    presalePrice = _preslaePrice;
  }

  function toggleSaleStatus() public onlyOwner {
    isActive = !isActive;
  }

  function togglePresaleStatus() external onlyOwner {
    isPresaleActive = !isPresaleActive;
  }

  function setBaseURI(string memory baseURI) public onlyOwner {
    _baseTokenURI = baseURI;
  }


  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function airdrop(uint256 _count, address _address) external onlyOwner {
    uint256 supply = totalSupply();

    require(supply + _count <= MAX_SUPPLY, "Total supply exceeded.");
    require(supply <= MAX_SUPPLY, "Total supply spent.");

    _safeMint(_address, _count);
  }

  function batchAirdrop(uint256 _count, address[] calldata addresses) external onlyOwner {
    uint256 supply = totalSupply();

    require(supply + _count <= MAX_SUPPLY, "Total supply exceeded.");
    require(supply <= MAX_SUPPLY, "Total supply spent.");

    for (uint256 i = 0; i < addresses.length; i++) {
      require(addresses[i] != address(0), "Can't add a null address");
      _safeMint(addresses[i], _count);
    }
  }

  function mint(uint256 _count) public payable mintCompliance(_count) saleIsOpen(_count) nonReentrant {
     if (msg.sender != owner()) {
      require(isActive, "Sale is not active currently.");
    }

    require( _count <= maximumAllowedTokensPerPurchase, "Exceeds maximum allowed tokens");
    require(msg.value >= (mintPrice * _count), "Insufficient ETH amount sent.");

    _safeMint(msg.sender, _count);
    
  }

  function preSaleMint(bytes32[] calldata _merkleProof, uint256 _count) public payable isValidMerkleProof(_merkleProof) mintCompliance(_count) saleIsOpen(_count) nonReentrant{
    require(isPresaleActive, "Presale is not active");
    require(msg.value >= (presalePrice * _count), "Insufficient ETH amount sent.");

    _safeMint(msg.sender, _count);

  }

  function burnToken(uint256 tokenId) external onlyOwner {
      _burn(tokenId);
  }

  function batchBurn(uint256[] memory tokenIds) external onlyOwner {
        uint256 len = tokenIds.length;
        for (uint256 i; i < len; i++) {
            uint256 tokenid = tokenIds[i];
            _burn(tokenid);
        }
  }

  function withdraw() external onlyOwner nonReentrant{
    uint balance = address(this).balance;
     Address.sendValue(payable(owner()), balance);  
  }
}