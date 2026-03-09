// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {PokeCardCollection} from "./PokeCardCollection.sol";

import {VRFConsumer} from "./VRFConsumer.sol";

import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract PokeCardGenerator is ReentrancyGuard, AccessControl {
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
VRFConsumer private vrfConsumer;
uint256 private constant generationCooldownInBlock = 7200; // 24 hours assuming 12s block time

bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

mapping(address=>PokemonCard[]) private generatedCards;
mapping(address=>mapping(uint256=>PokemonCard)) private generatedCardsByNftId;
mapping(address=>uint256) private totalCardsGenerated;
mapping(address=>uint256) private lastTimeGenerated;



    constructor(uint256 subscriptionId, address vrfCoordinator, bytes32 keyHash,  address pokeCardCollectionAddress) {
        pokeCardCollection = PokeCardCollection(pokeCardCollectionAddress);
        vrfConsumer = new VRFConsumer(subscriptionId, vrfCoordinator, keyHash, address(this));
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier generationCooldown() {
        if(block.number < lastTimeGenerated[msg.sender] + generationCooldownInBlock) {
            revert GenerationCooldownNotReached();
        }
        _;
    }

    modifier onlyMinter() {
        if(!hasRole(MINTER_ROLE, msg.sender)) {
            revert NotMinter();
        }
        _;
    }

    function setPokemonAmountToGenerate(uint256 amount) external onlyMinter {
        pokemonAmountToGenerate = amount;
    }
    
    function generatePokemon(uint256 randomFirst, uint256 randomSecond, string memory tokenURI) external generationCooldown nonReentrant {
        uint256[] memory randomWords = vrfConsumer.getRandomWords();

        if(randomWords.length != 2 || randomWords[0] != randomFirst || randomWords[1] != randomSecond) {
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
        
        vrfConsumer.clearRandomWords();
        
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