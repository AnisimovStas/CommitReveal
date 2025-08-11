// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {WhitelistNft} from "../src/WhitelistNft.sol";
import {TestUtils} from "./TestUtils.sol";

contract WhitelistNftTest is Test {
    WhitelistNft public nft;
    address owner = makeAddr("owner");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");
    address user5 = makeAddr("user5");
    address user6 = makeAddr("user6");
    address user7 = makeAddr("user7");
    address user8 = makeAddr("user8");
    // предположим, что это хранится оффчейн
    address[] public list = [
        owner,
        user2,
        user3,
        user4,
        user5,
        user6,
        user7,
        user8
    ];
    function setUp() public {
        bytes32 merkleRoot = TestUtils.calculateMerkleTreeRoot(list);
        vm.prank(owner);
        nft = new WhitelistNft(merkleRoot);
    }

    function test_verify() public {
        assertEq(
            nft.isWhitelisted(user2, TestUtils.getMerkleProof(user2, list)),
            true
        );

        assertEq(
            nft.isWhitelisted(user5, TestUtils.getMerkleProof(user5, list)),
            true
        );
        assertEq(
            nft.isWhitelisted(user7, TestUtils.getMerkleProof(user5, list)),
            false
        );
        address maleficent = makeAddr("bad");
        assertEq(
            nft.isWhitelisted(
                maleficent,
                TestUtils.getMerkleProof(user5, list)
            ),
            false
        );
    }

    function test_update_root_emit_event() public {
        address[] memory newList = new address[](2);
        newList[0] = owner;
        newList[1] = user2;
        bytes32 newRoot = TestUtils.calculateMerkleTreeRoot(newList);

        vm.prank(owner);
        vm.expectEmit(true, false, false, true); // match topics[0] и data
        emit WhitelistNft.WhitelistUpdated(newRoot);
        nft.updateRoot(newRoot);
    }

    function test_mint_base() public {
        bytes32[] memory proof = TestUtils.getMerkleProof(user2, list);
        vm.prank(user2);
        vm.expectEmit(true, false, false, true);
        emit WhitelistNft.NFTMinted(user2, 0);
        nft.mint(proof);

        assertEq(nft.ownerOf(0), user2);
    }

    function test_one_mint_per_user() public {
        bytes32[] memory proof = TestUtils.getMerkleProof(user2, list);
        vm.startPrank(user2);
        nft.mint(proof);
        vm.expectRevert();
        nft.mint(proof);
    }
}
