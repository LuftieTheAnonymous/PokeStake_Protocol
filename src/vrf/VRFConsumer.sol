// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {
    VRFConsumerBaseV2Plus
} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

import {
    VRFV2PlusClient
} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract VRFConsumer is VRFConsumerBaseV2Plus, ReentrancyGuard {
  // Your subscription ID.

  // user address -> block number of last call to requestRandomWords
  mapping(address => uint256) private callsToRandomness;

  uint256 private constant REQUEST_INTERVAL_IN_BLOCKS = 7200; // 24 hours assuming 12s block time

  uint256 immutable s_subscriptionId;

  // The gas lane to use, which specifies the maximum gas price to bump to.
  // For a list of available gas lanes on each network,
  // see https://docs.chain.link/docs/vrf-contracts/#configurations
  bytes32 immutable s_keyHash;

  // Depends on the number of requested values that you want sent to the
  // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
  // so 100,000 is a safe default for this example contract. Test and adjust
  // this limit based on the network that you select, the size of the request,
  // and the processing of the callback request in the fulfillRandomWords()
  // function.
  uint32 constant CALLBACK_GAS_LIMIT = 100_000;

  // The default is 3, but you can set this higher.
  uint16 constant REQUEST_CONFIRMATIONS = 3;

  // For this example, retrieve 2 random values in one request.
  // Cannot exceed VRFCoordinatorV2_5.MAX_NUM_WORDS.
  uint32 constant NUM_WORDS = 2;

  uint256[] public s_randomWords;
  uint256 public s_requestId;

  modifier requestInterval() {
    if (block.number < callsToRandomness[msg.sender] + REQUEST_INTERVAL_IN_BLOCKS) {
      revert("Request interval not met");
    }
    _;
    callsToRandomness[msg.sender] = block.number;
  }

  event ReturnedRandomness(uint256[] randomWords);

  /**
   * @notice Constructor inherits VRFConsumerBaseV2Plus
   *
   * @param subscriptionId - the subscription ID that this contract uses for funding requests
   * @param vrfCoordinator - coordinator, check https://docs.chain.link/vrf/v2-5/supported-networks
   * @param keyHash - the gas lane to use, which specifies the maximum gas price to bump to
   */
  constructor(
    uint256 subscriptionId,
    address vrfCoordinator,
    bytes32 keyHash
  ) VRFConsumerBaseV2Plus(vrfCoordinator) {
    s_keyHash = keyHash;
    s_subscriptionId = subscriptionId;
  }

  function requestRandomWords() external nonReentrant requestInterval {
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

    callsToRandomness[msg.sender] = block.number;
    
  }


  function fulfillRandomWords(
    uint256,
    /* requestId */
    uint256[] calldata randomWords
  ) internal override {
    s_randomWords = randomWords;
    emit ReturnedRandomness(randomWords);
  }

  function getRequestId() public view returns (uint256) {
        return s_requestId;
    }

    function getSubscriptionId() public view returns (uint256) {
        return s_subscriptionId;
    }

    function getRandomWords() public view returns (uint256[] memory) {
        return s_randomWords;
    }

}


