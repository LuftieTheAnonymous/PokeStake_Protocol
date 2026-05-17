// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {IVerifier} from "./Verifier.sol"; // (TO BE IMPLEMENTED)

import {SnorlieCoin} from "../PokeCoin.sol";

import {AccessControl} from "../../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract BattleClaimReward is AccessControl {

error InvalidProof();
error Invalid_MerkleRoot(bytes32 _root);
error NullifierHash_AlreadyUsed(bytes32 _nullifierHash);

event RewardClaim(bytes _proof, bytes32 _nullifierHash, uint256 blockNumber);

IVerifier verifier;
SnorlieCoin snorlieCoin;

bytes32 ADMIN_ROLE = bytes32("ADMIN_ROLE");

mapping(bytes32 _root => bool isValid) private validMerkleRoots;
mapping(bytes32 nullifierHash => bool isUsed) private nullifierHashUsed;
uint256 constant private REWARD_BASE = 2e18;

constructor(IVerifier _verifier, SnorlieCoin _snorlieCoin){
    verifier = _verifier;
    snorlieCoin = _snorlieCoin;
    _grantRole(ADMIN_ROLE, msg.sender);
}




function rewardClaim(bytes memory _proof, bytes32 _nullifierHash, bytes32 _hashSecret, bytes32 _merkleRoot) external {
    
    if(!validMerkleRoots[_merkleRoot]){
        revert Invalid_MerkleRoot(_merkleRoot);
    }

    if(nullifierHashUsed[nullifierHashUsed]){
        revert NullifierHash_AlreadyUsed(_nullifierHash);
    }

    bytes32[] memory _publicInputs = new bytes32[](3);
    _publicInputs[0] = _nullifierHash;
    _publicInputs[1] = _hashSecret;
    _publicInputs[2] = bytes32(uint256(keccak256(abi.encode(msg.sender))) % FIELD_SIZE);
    _publicInputs[3] = merkleRoot; 

    bool proofValidity = verifier.verify(_proof, _publicInputs);

    if(!proofValidity){
        revert InvalidProof();
    }

    // Disables from double usage
    validMerkleRoots[_merkleRoot] = false;

    nullifierHashUsed[_nullifierHash]=true;

    snorlieCoin.mint(msg.sender, REWARD_BASE);

    emit RewardClaim(_proof, _nullifierHash, block.number);
}

function addValidMerkleRoot(bytes32 _merkleRoot) external onlyRole(ADMIN_ROLE) {
    validMerkleRoots[_merkleRoot] = true;
}


}