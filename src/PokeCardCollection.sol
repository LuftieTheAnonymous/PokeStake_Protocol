// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721URIStorage} from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {VRFConsumer} from "./vrf/VRFConsumer.sol";

contract PokeCardCollection is ERC721, ERC721URIStorage, ERC721Burnable, ReentrancyGuard, AccessControl {
    
    error RandomWordsNotAvailable();
    error GenerationCooldownNotReached();
    error NotMinter();
    error NotOwner();

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
    uint256 private constant generationCooldownInBlock = 7200; // 24 hours assuming 12s block time
    bytes32 private constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    mapping(address => PokemonCard[]) private generatedCards;
    mapping(address => mapping(uint256 => PokemonCard)) private generatedCardsByNftId;
    mapping(address => uint256) private totalCardsGenerated;
    mapping(address => uint256) private lastTimeGenerated;

    VRFConsumer private vrfConsumer;

    uint256 private _nextTokenId;

    constructor(address vrfConsumerAddress) ERC721("PokeCard", "PIKA") {
        vrfConsumer = VRFConsumer(vrfConsumerAddress);
        _grantRole(CONTROLLER_ROLE, msg.sender);
    }

    modifier generationCooldown() {
        if (block.number < lastTimeGenerated[msg.sender] + generationCooldownInBlock) {
            revert GenerationCooldownNotReached();
        }
        _;
    }

    modifier onlyController() {
        if (!hasRole(CONTROLLER_ROLE, msg.sender)) {
            revert NotMinter();
        }
        _;
    }

    modifier onlyCardOwner(uint256 nftId) {
        if (ownerOf(nftId) != msg.sender) {
            revert NotOwner();
        }
        _;
    }


    modifier areProvidedNumbersValid(uint256 firstNumber, uint256 secondNumber) {
        uint256[] memory randomWords = vrfConsumer.getRandomWords();
        if (randomWords.length == 0) {
            revert RandomWordsNotAvailable();
        }
        if (firstNumber != randomWords[0] || secondNumber != randomWords[1]) {
            revert("Provided numbers do not match the random words");
        }
        _;
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

    function totalSupply() public view returns (uint256) {
        return _nextTokenId;
    }

    function getRandomWords() public view returns (uint256[] memory) {
        uint256[] memory randomWords = vrfConsumer.getRandomWords();
        if (randomWords.length == 0) {
            revert RandomWordsNotAvailable();
        }
        return randomWords;
    }

function setPokemonAmountToGenerate(uint256 amount) external onlyController {
        pokemonAmountToGenerate = amount;
    }


    function mint(address to, string memory uri) internal returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        super._mint(to, tokenId);
        super._setTokenURI(tokenId, uri);
        return tokenId;
    }

    function burn(uint256 tokenId) public override onlyCardOwner(tokenId) {
        super.burn(tokenId);
        delete generatedCardsByNftId[msg.sender][tokenId];
    }

    function generatePokemon(uint256 firstNumber, uint256 secondNumber, string memory token_uri) external
        generationCooldown
        nonReentrant
        areProvidedNumbersValid(firstNumber, secondNumber)
    {
        uint256 pokedexId = firstNumber % pokemonAmountToGenerate;
        PokemonRarityLevel rarityLevel = PokemonRarityLevel(secondNumber % rarityLevels);

        uint256 pokemonCardNftID = mint(msg.sender, token_uri);
        PokemonCard memory newCard = PokemonCard(pokedexId, rarityLevel, pokemonCardNftID, token_uri);
        generatedCards[msg.sender].push(newCard);
        generatedCardsByNftId[msg.sender][pokemonCardNftID] = newCard;
        totalCardsGenerated[msg.sender]++;
        lastTimeGenerated[msg.sender] = block.number;

        emit PokemonCardGenerated(msg.sender, pokemonCardNftID, pokedexId);
    }


    // The following functions are overrides required by Solidity.

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }



}
