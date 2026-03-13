// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {AccessControl} from "../../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

import {
    VRFConsumerBaseV2Plus
} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

import {
    VRFV2PlusClient
} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract VRFConsumer is VRFConsumerBaseV2Plus, ReentrancyGuard, AccessControl{
    error AddressZero();
    error NotRequestOwner(address caller);

    error NotExistingRequest();

    error RequestResolved();

    event ReturnedRandomness(uint256[] randomWords);

 
    struct RandomValues {
        uint256[] randomWords;
        bool isResolved;
    }

    uint256 immutable s_subscriptionId;

    bytes32 immutable s_keyHash;
    uint32 constant CALLBACK_GAS_LIMIT = 100_000;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant NUM_WORDS = 2;

    bytes32 constant private MANAGER_ROLE = keccak256("MANAGER_ROLE");
 
   mapping(uint256=>address) private requestIdToCaller;
   mapping(address=>uint256) private callerToRequestId;
   mapping(uint256=>RandomValues) private latestRequestsWithValues;

   uint256 private s_requestId;
    

  
    constructor(uint256 subscriptionId, address vrfCoordinator, bytes32 keyHash) VRFConsumerBaseV2Plus(vrfCoordinator) {
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
        _grantRole(MANAGER_ROLE, msg.sender);
    }


    modifier onlyManager(){
        if(!hasRole(MANAGER_ROLE, msg.sender)){
            revert();
        }
        _;
    }

    modifier onlyRequestOwner(uint256 requestId, address caller){
        if(requestIdToCaller[requestId] == address(0)){
            revert AddressZero();
        }

        if(requestIdToCaller[requestId] != caller){
            revert NotRequestOwner(caller);
        }

        _;
    }

    modifier isExistingRequest(uint256 requestId){
        if(latestRequestsWithValues[requestId].randomWords.length == 0){
            revert NotExistingRequest();
        }
        _;
    }

    modifier isResolved(uint256 requestId){
          if(latestRequestsWithValues[requestId].isResolved == true){
            revert RequestResolved();
        }
        _;
    }

function transferManagerRole(address newManager) public onlyManager{
    _grantRole(MANAGER_ROLE, newManager);
    _revokeRole(MANAGER_ROLE, msg.sender);
}


    function requestRandomWords() external nonReentrant returns (uint256) {

    uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        
        s_requestId = requestId;
        callerToRequestId[msg.sender]=requestId;
        requestIdToCaller[requestId]=msg.sender;

        return requestId;
    }

    function fulfillRandomWords(
        uint256 requestId, 
        uint256[] calldata randomWords
    )
        internal
        override
    {
        latestRequestsWithValues[requestId] = RandomValues(randomWords, false);
        emit ReturnedRandomness(randomWords);
    }


// TEST ONLY START
    function getSubscriptionId() public view returns(uint256){
        return s_subscriptionId;
    }

    function getRequestId(address caller) public view returns(uint256){
        return callerToRequestId[caller];
    }
    
// TEST ONLY END

    function getRequestData(address caller, uint256 modulatorPokedex, uint256 rarityModulator) public view returns (uint256 pokedexIndex, uint256 rarityLevel, bool isRequestResolved) {
         uint256 requestId = getRequestId(caller);

         pokedexIndex = latestRequestsWithValues[requestId].randomWords[0] % modulatorPokedex;
         rarityLevel = latestRequestsWithValues[requestId].randomWords[1] % rarityModulator;
        return (pokedexIndex, rarityLevel, latestRequestsWithValues[requestId].isResolved);
    }
    
    function updateRequest(uint256 requestId, address caller) public onlyManager isExistingRequest(requestId) isResolved(requestId) onlyRequestOwner(requestId, caller){
        latestRequestsWithValues[requestId].isResolved = true;
    }
}

    