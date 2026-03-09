// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {
    VRFConsumerBaseV2Plus
} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {
    VRFV2PlusClient
} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract VRFConsumer is VRFConsumerBaseV2Plus, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Your subscription ID.
    uint256 immutable s_subscriptionId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 immutable s_keyHash;

    uint32 constant CALLBACK_GAS_LIMIT = 100_000;

    // The default is 3, but you can set this higher.
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    uint32 constant NUM_WORDS = 2;

    uint256[] public s_randomWords;
    uint256 public s_requestId;

    event ReturnedRandomness(uint256[] randomWords);

    /**
     * @notice Constructor inherits VRFConsumerBaseV2Plus
     *
     * @param subscriptionId - the subscription ID that this contract uses for funding requests
     * @param vrfCoordinator - coordinator, check https://docs.chain.link/vrf/v2-5/supported-networks
     * @param keyHash - the gas lane to use, which specifies the maximum gas price to bump to
     */
    constructor(uint256 subscriptionId, address vrfCoordinator, bytes32 keyHash, address admin)
        VRFConsumerBaseV2Plus(vrfCoordinator)
    {
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
        _grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Requests randomness
     * Assumes the subscription is funded sufficiently; "Words" refers to unit of data in Computer Science
     */
    function requestRandomWords() external onlyOwner {
        // Will revert if subscription is not set and funded.
        s_requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
    }

    /**
     * @notice Callback function used by VRF Coordinator
     *
     * @param  - id of the request
     * @param randomWords - array of random results from VRF Coordinator
     */
    function fulfillRandomWords(
        uint256,
        /* requestId */
        uint256[] calldata randomWords
    )
        internal
        override
    {
        s_randomWords = randomWords;
        emit ReturnedRandomness(randomWords);
    }

    function getRandomWords() external view returns (uint256[] memory) {
        return s_randomWords;
    }

    function clearRandomWords() external onlyRole(ADMIN_ROLE) {
        delete s_randomWords;
    }
}

