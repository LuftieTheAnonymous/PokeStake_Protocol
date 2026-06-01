// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

abstract contract IncrementableMerkleTree {
    error LeafAlreadyExists(uint256 index);
    error InvalidLeafIndex(uint256 index);
    error InvalidProofLength(uint256 received, uint256 expected);

    event LeafAdded(bytes32 indexed _leaf, uint256 indexed index);

    bytes32[] public leaves;
    mapping(bytes32 => bool) public leafExists;
    bytes32[] public zeros;
    
    uint256 public constant TREE_DEPTH = 20;

    constructor() {
        _initializeZeros();
    }

    function _initializeZeros() internal {
        zeros.push(_poseidon2(bytes32(0), bytes32(0)));
        for (uint256 i = 1; i < TREE_DEPTH; i++) {
            zeros.push(_poseidon2(zeros[i - 1], zeros[i - 1]));
        }
    }

    function _poseidon2(bytes32 _a, bytes32 _b) internal pure returns (bytes32) {
        // Your poseidon2 implementation
        return keccak256(abi.encodePacked(_a, _b));
    }

    function _addLeaf(bytes32 _leaf) internal {
        if (leafExists[_leaf]) {
            revert LeafAlreadyExists(leaves.length - 1);
        }
        leafExists[_leaf] = true;
        leaves.push(_leaf);
        emit LeafAdded(_leaf, leaves.length - 1);
    }

    function getCurrentRoot() public view returns (bytes32) {
        if (leaves.length == 0) return zeros[TREE_DEPTH - 1];
        return _calculateRoot(leaves.length - 1);
    }

    function _calculateRoot(uint256 _leafIndex) internal view returns (bytes32) {
        if (_leafIndex >= leaves.length) {
            revert InvalidLeafIndex(_leafIndex);
        }

        bytes32 node = leaves[_leafIndex];
        uint256 index = _leafIndex;

        for (uint256 i = 0; i < TREE_DEPTH; i++) {
            if (index % 2 == 0) {
                if (index + 1 < leaves.length) {
                    node = _poseidon2(node, leaves[index + 1]);
                } else {
                    node = _poseidon2(node, zeros[i]);
                }
            } else {
                node = _poseidon2(leaves[index - 1], node);
            }
            index /= 2;
        }

        return node;
    }

    function getMerkleProof(uint256 _leafIndex) external view returns (bytes32[] memory) {
        if (_leafIndex >= leaves.length) {
            revert InvalidLeafIndex(_leafIndex);
        }

        bytes32[] memory proof = new bytes32[](TREE_DEPTH);
        uint256 index = _leafIndex;

        for (uint256 i = 0; i < TREE_DEPTH; i++) {
            if (index % 2 == 0) {
                if (index + 1 < leaves.length) {
                    proof[i] = leaves[index + 1];
                } else {
                    proof[i] = zeros[i];
                }
            } else {
                proof[i] = leaves[index - 1];
            }
            index /= 2;
        }

        return proof;
    }

    function _verifyMerkleProof(
        bytes32 _leaf,
        uint256 _leafIndex,
        bytes32[] memory _proof
    ) internal view returns (bool) {
        if (_proof.length != TREE_DEPTH) {
            revert InvalidProofLength(_proof.length, TREE_DEPTH);
        }

        bytes32 node = _leaf;
        uint256 index = _leafIndex;

        for (uint256 i = 0; i < TREE_DEPTH; i++) {
            if (index % 2 == 0) {
                node = _poseidon2(node, _proof[i]);
            } else {
                node = _poseidon2(_proof[i], node);
            }
            index /= 2;
        }

        return node == getCurrentRoot();
    }

    function getLeafCount() external view returns (uint256) {
        return leaves.length;
    }

    function getRootAtIndex(uint256 _leafIndex) external view returns (bytes32) {
        return _calculateRoot(_leafIndex);
    }
}
