// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {IVerifier} from "./zk-proof/Verifier.sol";

import {SnorlieCoin} from "./PokeCoin.sol";

contract BattleClaimReward {

error InvalidProof();


IVerifier verifier;
SnorlieCoin snorlieCoin;

bytes32 merkleRoot;
uint256 constant private FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
uint256 constant private REWARD_BASE = 5e18;

constructor(IVerifier _verifier, SnorlieCoin _snorlieCoin){
    verifier = _verifier;
    snorlieCoin = _snorlieCoin;
}

function rewardClaim(bytes memory _proof, bytes32 _nullifierHash, bytes32 _hashSecret) external {
    bytes32[] memory _publicInputs = new bytes32[](3);
    _publicInputs[0] = _nullifierHash;
    _publicInputs[1] = _hashSecret;
    _publicInputs[2] = bytes32(uint256(keccak256(abi.encode(msg.sender))) % FIELD_SIZE);

    bool proofValidity = verifier.verify(_proof, _publicInputs);

    if(!proofValidity){
        revert InvalidProof();
    }

    snorlieCoin.mint(msg.sender, REWARD_BASE);
}


}