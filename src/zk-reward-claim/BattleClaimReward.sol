// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IVerifier} from "./Verifier.sol";
import {SnorlieCoin} from "../PokeCoin.sol";
import {IncrementableMerkleTree} from "./IMTree.sol";

contract BattleClaimReward is IncrementableMerkleTree {
    error InvalidProof();
    error Invalid_MerkleProof();
    error NullifierHash_AlreadyUsed(bytes32 _nullifierHash);
    error LeafAlreadyUsed(bytes32 _leaf);

    event RewardClaimed(
        address indexed claimer,
        bytes32 indexed nullifierHash,
        bytes32 indexed leaf,
        uint256 blockNumber
    );

    IVerifier verifier;
    SnorlieCoin snorlieCoin;

    mapping(bytes32 nullifierHash => bool isUsed) private nullifierHashUsed;
    mapping(bytes32 leaf => bool isUsed) private leafUsed;
    
    uint256 private constant REWARD_BASE = 2e18;
    uint256 public constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    constructor(IVerifier _verifier, SnorlieCoin _snorlieCoin) 
        IncrementableMerkleTree() 
    {
        verifier = _verifier;
        snorlieCoin = _snorlieCoin;
    }

    /**
     * User submits proof to claim reward
     * 
     * @param _proof - ZK proof from barretenberg (encodes game state validity)
     * @param _nullifierHash - hash(nullifier) to prevent double claims
     * @param _hashSecret - hash of secret value
     * @param _gameStateHash - leaf data representing game outcome (winner, loser, etc)
     * @param _merkleProof - merkle path to prove leaf is in tree
     */
    function rewardClaim(
        bytes memory _proof,
        bytes32 _nullifierHash,
        bytes32 _hashSecret,
        bytes32 _gameStateHash,
        bytes32[] memory _merkleProof
    ) external {
        // Prevent double claims via nullifier
        if (nullifierHashUsed[_nullifierHash]) {
            revert NullifierHash_AlreadyUsed(_nullifierHash);
        }

        // Prevent same leaf from being claimed twice
        if (leafUsed[_gameStateHash]) {
            revert LeafAlreadyUsed(_gameStateHash);
        }

        // Add leaf to tree (first time it's seen)
        _addLeaf(_gameStateHash);

        // Verify merkle proof (leaf is in tree)
        if (!_verifyMerkleProof(_gameStateHash, leaves.length - 1, _merkleProof)) {
            revert Invalid_MerkleProof();
        }

        // Prepare public inputs for ZK proof
        bytes32[] memory _publicInputs = new bytes32[](4);
        _publicInputs[0] = _nullifierHash;
        _publicInputs[1] = _hashSecret;
        _publicInputs[2] = bytes32(uint256(uint160(msg.sender)) % FIELD_SIZE);
        _publicInputs[3] = getCurrentRoot();

        // Verify zero-knowledge proof
        bool proofValidity = verifier.verify(_proof, _publicInputs);
        if (!proofValidity) {
            revert InvalidProof();
        }

        // Mark as claimed
        nullifierHashUsed[_nullifierHash] = true;
        leafUsed[_gameStateHash] = true;

        // Mint reward
        snorlieCoin.mint(msg.sender, REWARD_BASE);

        emit RewardClaimed(msg.sender, _nullifierHash, _gameStateHash, block.number);
    }

    function isNullifierUsed(bytes32 _nullifierHash) external view returns (bool) {
        return nullifierHashUsed[_nullifierHash];
    }

    function isLeafUsed(bytes32 _leaf) external view returns (bool) {
        return leafUsed[_leaf];
    }
}
