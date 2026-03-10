// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {PokeCardCollection} from "./PokeCardCollection.sol";

import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

import {
    VRFConsumerBaseV2Plus
} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {
    VRFV2PlusClient
} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract PokeCardGenerator is ReentrancyGuard, AccessControl, VRFConsumerBaseV2Plus {

    error RandomWordsNotAvailable();
    error GenerationCooldownNotReached();
    error NotMinter();

    event PokemonCardGenerated(address indexed user, uint256 indexed nftId, uint256 pokedexId);

    enum PokemonRarityLevel {
        Common,
        Uncommon,
        Rare,
        UltraRare
    }

    struct PokemonCard {
        uint256 pokedexId;
        PokemonRarityLevel rarityLevel;
        uint256 nftId;
        string tokenURI;
    }

    uint256 private pokemonAmountToGenerate = 151;
    uint256 private constant rarityLevels = 4;
    PokeCardCollection private pokeCardCollection;
    uint256 private constant generationCooldownInBlock = 7200; // 24 hours assuming 12s block time

  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(address => PokemonCard[]) private generatedCards;
    mapping(address => mapping(uint256 => PokemonCard)) private generatedCardsByNftId;
    mapping(address => uint256) private totalCardsGenerated;
    mapping(address => uint256) private lastTimeGenerated;


    // Your subscription ID.
    uint256 immutable s_subscriptionId;
    bytes32 immutable s_keyHash;

    uint32 constant CALLBACK_GAS_LIMIT = 100_000;

    // The default is 3, but you can set this higher.
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    uint32 constant NUM_WORDS = 2;

    uint256[] public s_randomWords;
    uint256 public s_requestId;

    event ReturnedRandomness(uint256[] randomWords);
// 0x762D464F8018946Ff802D61C42d7598Cb19F2760 - Coordinator Contract
// 53608168839970588596314529647685566669783181689802649504944407757372548592266 - Subscription ID
// 0x0ec97D974075dDADBdB7eFD887E98D120FadAF3B 
// 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae - Key Hash
  
    constructor(address pokeCardCollectionAddress,address vrfCoordinator, bytes32 keyHash, uint256 subscriptionId)
        VRFConsumerBaseV2Plus(vrfCoordinator)
    {
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }


function transferAdminRole(address newAdmin) public onlyRole(ADMIN_ROLE) {
        require(newAdmin != address(0), "New admin is the zero address");
        _grantRole(ADMIN_ROLE, newAdmin);
        _revokeRole(ADMIN_ROLE, msg.sender);
    }


    /**
     * @notice Requests randomness
     * Assumes the subscription is funded sufficiently; "Words" refers to unit of data in Computer Science
     */
    function requestRandomWords() external {
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

    function getRequestId() public view returns (uint256) {
        return s_requestId;
    }

    function getSubscriptionId() public view returns (uint256) {
        return s_subscriptionId;
    }

    function getRandomWords() public view returns (uint256[] memory) {
        return s_randomWords;
    }

    function clearRandomWords() public onlyRole(ADMIN_ROLE) {
        delete s_randomWords;
    }




    modifier generationCooldown() {
        if (block.number < lastTimeGenerated[msg.sender] + generationCooldownInBlock) {
            revert GenerationCooldownNotReached();
        }
        _;
    }

    modifier onlyMinter() {
        if (!hasRole(MINTER_ROLE, msg.sender)) {
            revert NotMinter();
        }
        _;
    }


    function setPokemonAmountToGenerate(uint256 amount) external onlyMinter {
        pokemonAmountToGenerate = amount;
    }

  

    function generatePokemon(uint256 randomFirst, uint256 randomSecond, string memory tokenURI)
        external
        generationCooldown
        nonReentrant
    {
        uint256[] memory randomWords = getRandomWords();

        if (randomWords.length != 2 || randomWords[0] != randomFirst || randomWords[1] != randomSecond) {
            revert RandomWordsNotAvailable();
        }

        uint256 pokedexId = randomFirst % pokemonAmountToGenerate;
        PokemonRarityLevel rarityLevel = PokemonRarityLevel(randomSecond % rarityLevels);

        uint256 pokemonCardNftID = pokeCardCollection.safeMint(msg.sender, tokenURI);
        PokemonCard memory newCard = PokemonCard(pokedexId, rarityLevel, pokemonCardNftID, tokenURI);
        generatedCards[msg.sender].push(newCard);
        generatedCardsByNftId[msg.sender][pokemonCardNftID] = newCard;
        totalCardsGenerated[msg.sender]++;
        lastTimeGenerated[msg.sender] = block.number;

        clearRandomWords();

        emit PokemonCardGenerated(msg.sender, pokemonCardNftID, pokedexId);
    }

    function getGeneratedCards(address user) external view returns (PokemonCard[] memory) {
        return generatedCards[user];
    }

    function getTotalCardsGenerated(address user) external view returns (uint256) {
        return totalCardsGenerated[user];
    }

    function getLastTimeGenerated(address user) external view returns (uint256) {
        return lastTimeGenerated[user];
    }

    function getGeneratedCardByNftId(address user, uint256 nftId) external view returns (PokemonCard memory) {
        return generatedCardsByNftId[user][nftId];
    }
}
