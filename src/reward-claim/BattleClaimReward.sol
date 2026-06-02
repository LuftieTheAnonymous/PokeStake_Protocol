pragma solidity ^0.8.27;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {SnorlieCoin} from "../PokeCoin.sol";

contract BattleClaimReward {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    error InvalidSignature();
    error NotBattleWinner();
    error BattleAlreadyClaimed();

    error RewardClaimPaused();

    event RewardClaimed(uint256 battleId, address winner, uint256 amount);

    address public backendSigner;
    SnorlieCoin public snorlieCoin;
    mapping(bytes32 => bool) public claimedBattles;

    bool public paused=false;

    modifier onlyBackend() {
        if (msg.sender != backendSigner) {
            revert InvalidSignature();
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) {
            revert RewardClaimPaused();
        }
        _;
    }

    constructor(address _backendSigner, SnorlieCoin _snorlieCoin) {
        backendSigner = _backendSigner;
        snorlieCoin = _snorlieCoin;
    }

    function setBackendSigner(address newSigner) external onlyBackend {
        backendSigner = newSigner;
    }

    function setPaused(bool _paused) external onlyBackend {
        paused = _paused;
    }

    function claimBattleReward(
        uint256 battleId,
        address winner,
        uint256 rewardAmount,
        bytes calldata signature
    ) external whenNotPaused {
        bytes32 battleHash = keccak256(
            abi.encodePacked(battleId, winner, rewardAmount)
        );

        if (claimedBattles[battleHash]) {
            revert BattleAlreadyClaimed();
        }

        address signer = battleHash.toEthSignedMessageHash().recover(signature);

        if (signer != backendSigner) {
            revert InvalidSignature();
        }

        if (winner != msg.sender) {
            revert NotBattleWinner();
        }

        claimedBattles[battleHash] = true;
        // Transfer reward to winner
        snorlieCoin.mint(winner, rewardAmount);

        emit RewardClaimed(battleId, winner, rewardAmount);
    }
}
