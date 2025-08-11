// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library TestUtils {
    function calculateMerkleTree(
        address[] memory _list
    ) public pure returns (bytes32[] memory) {
        require(isPowerOfTwo(_list.length), "list size must be 2**n");
        uint256 treeSize = 2 * _list.length - 1;
        bytes32[] memory merkleTree = new bytes32[](treeSize);

        // Leaves
        for (uint256 i = 0; i < _list.length; i++) {
            merkleTree[i] = keccak256(abi.encodePacked(_list[i]));
        }

        uint256 count = _list.length;
        uint256 offset = 0;
        uint256 currentPos = _list.length;

        while (count > 1) {
            for (uint256 i = 0; i < count; i += 2) {
                bytes32 left = merkleTree[offset + i];
                bytes32 right = merkleTree[offset + i + 1];

                // Sort children to match OpenZeppelin-style ordering
                if (left <= right) {
                    merkleTree[currentPos] = keccak256(
                        abi.encodePacked(left, right)
                    );
                } else {
                    merkleTree[currentPos] = keccak256(
                        abi.encodePacked(right, left)
                    );
                }

                currentPos++;
            }
            offset += count;
            count = count / 2;
        }

        return merkleTree;
    }

    function calculateMerkleTreeRoot(
        address[] memory _list
    ) public pure returns (bytes32) {
        bytes32[] memory tree = calculateMerkleTree(_list);
        return tree[tree.length - 1];
    }

    function merkleTreeLengthPreview(uint256 n) public pure returns (uint256) {
        return 2 * n - 1;
    }

    function isPowerOfTwo(uint256 x) public pure returns (bool) {
        return x != 0 && (x & (x - 1)) == 0;
    }

    function getMerkleProof(
        address _address,
        address[] memory _list
    ) public pure returns (bytes32[] memory proof) {
        bytes32[] memory merkleTree = calculateMerkleTree(_list);
        bytes32 leaf = keccak256(abi.encodePacked(_address));

        uint256 index = findLeafIndex(leaf, _list);
        require(index != type(uint256).max, "Address not in list");

        proof = new bytes32[](log2(_list.length));
        uint256 proofIndex = 0;
        uint256 levelSize = _list.length;
        uint256 offset = 0;

        while (levelSize > 1) {
            uint256 siblingIndex = index ^ 1; // sibling
            proof[proofIndex++] = merkleTree[offset + siblingIndex];

            index = index / 2;
            offset += levelSize;
            levelSize = levelSize / 2;
        }

        return proof;
    }

    function findLeafIndex(
        bytes32 _leaf,
        address[] memory _list
    ) private pure returns (uint256) {
        for (uint256 i = 0; i < _list.length; i++) {
            if (keccak256(abi.encodePacked(_list[i])) == _leaf) {
                return i;
            }
        }
        return type(uint256).max;
    }

    function log2(uint256 x) private pure returns (uint256) {
        uint256 result = 0;
        while (x > 1) {
            x >>= 1;
            result++;
        }
        return result;
    }
}
