// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WhitelistNft is ERC721URIStorage, Ownable {
    bytes32 public merkleRoot;
    uint256 counter;

    event WhitelistUpdated(bytes32 root);
    event NFTMinted(address indexed user, uint256 tokenId);
    constructor(
        bytes32 initialRoot
    ) ERC721("Whitelist", "WLT") Ownable(msg.sender) {
        merkleRoot = initialRoot;
    }

    modifier onlyWhitelisted(bytes32[] memory _proof) {
        require(isWhitelisted(msg.sender, _proof), "Address not whitelisted");
        _;
    }

    function updateRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit WhitelistUpdated(_merkleRoot);
    }

    function mint(bytes32[] memory _proof) external onlyWhitelisted(_proof) {
        require(ERC721.balanceOf(msg.sender) == 0, "only one nft in one hand");
        ERC721._safeMint(msg.sender, counter);
        emit NFTMinted(msg.sender, counter);
        counter++;
    }

    function isWhitelisted(
        address _address,
        bytes32[] memory _proof
    ) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_address));
        return verifyMerkleProof(leaf, _proof);
    }

    // Проверка в стиле OpenZeppelin: на каждом шаге сравниваем computedHash и proofElement
    function verifyMerkleProof(
        bytes32 _leaf,
        bytes32[] memory _proof
    ) internal view returns (bool) {
        bytes32 computedHash = _leaf;

        for (uint256 i = 0; i < _proof.length; i++) {
            bytes32 proofElement = _proof[i];

            if (computedHash <= proofElement) {
                // current hash goes on the left
                computedHash = keccak256(
                    abi.encodePacked(computedHash, proofElement)
                );
            } else {
                // current hash goes on the right
                computedHash = keccak256(
                    abi.encodePacked(proofElement, computedHash)
                );
            }
        }

        return computedHash == merkleRoot;
    }
}
