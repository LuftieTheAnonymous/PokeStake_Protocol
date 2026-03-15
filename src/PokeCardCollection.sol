// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC721, IERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721URIStorage} from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {VRFConsumer} from "./vrf/VRFConsumer.sol";

contract PokeCardCollection is ERC721, ERC721URIStorage, ERC721Burnable, ReentrancyGuard, AccessControl {
    error GenerationCooldownNotReached();
    error NotMinter();
    error NotOwner();

    error ResolvedRequest(uint256 requestId);
    error NoResolvedRequestOrNoRequestSent(address caller);

    event PokemonCardGenerated(address indexed user, uint256 indexed nftId, uint256 pokedexId, uint256 requestId);

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
        string pinataId;
    }

    uint256 private pokemonAmountToGenerate = 151;
    uint256 private constant rarityLevels = 4;
    uint256 private constant generationCooldownInBlock = 7200;
    bytes32 private constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    mapping(address => PokemonCard[]) private generatedCards;
    mapping(address => mapping(uint256 => PokemonCard)) private generatedCardsByNftId;
    mapping(address => uint256) private totalCardsGenerated;
    mapping(address => uint256) private lastTimeGenerated;
    VRFConsumer private vrfConsumer;
    uint256 private _nextTokenId;

    constructor(address vrfConsumerAddress) ERC721("PokeCard", "PICA") {
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

    modifier hasSentRequestOrRequestPassed() {
        if (vrfConsumer.getRequestDataArray(msg.sender).length == 0 || vrfConsumer.getRequestId(msg.sender) == 0) {
            revert NoResolvedRequestOrNoRequestSent(msg.sender);
        }
        _;
    }
    
    // Amount to manage the pokemon amount to be drawn
    function setPokemonAmountToGenerate(uint256 amount) external onlyController {
        pokemonAmountToGenerate = amount;
    }

    function mint(address to, string memory uri) internal returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        super._mint(to, tokenId);
        super._setTokenURI(tokenId, uri);
        return tokenId;
    }

    function approve(address to, uint256 tokenId) public override(ERC721, IERC721) {
        super.approve(to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) {
        super.safeTransferFrom(from, to, tokenId);

        for (uint256 i = 0; i < generatedCards[from].length; i++) {
            PokemonCard memory lastPokeCard = generatedCards[from][generatedCards[from].length - 1];
            PokemonCard memory currentPokeCard = generatedCards[from][i];

            if (currentPokeCard.nftId == tokenId) {
                delete generatedCardsByNftId[from][tokenId];
                generatedCardsByNftId[to][tokenId] = currentPokeCard;
                generatedCards[from][i] = lastPokeCard;
                generatedCards[from][generatedCards[from].length - 1] = currentPokeCard;
                generatedCards[from].pop();
            }
        }
    }

    function burn(uint256 tokenId) public override onlyCardOwner(tokenId) {
        super.burn(tokenId);
        delete generatedCardsByNftId[msg.sender][tokenId];
    }

    function generatePokemon(string memory token_uri, string memory pinataId)
        external
        hasSentRequestOrRequestPassed
        generationCooldown
        nonReentrant
    {
        uint256 requestId = vrfConsumer.getRequestId(msg.sender);
        (uint256 pokedexId, uint256 rarityLevel, bool isRequestResolved) =
            vrfConsumer.getRequestData(msg.sender, pokemonAmountToGenerate, rarityLevels);

        if (isRequestResolved == true) {
            revert ResolvedRequest(requestId);
        }
        uint256 pokemonCardNftID = mint(msg.sender, token_uri);
        PokemonCard memory newCard = PokemonCard({
            pokedexId: pokedexId,
            rarityLevel: PokemonRarityLevel(rarityLevel),
            nftId: pokemonCardNftID,
            tokenURI: token_uri,
            pinataId: pinataId
        });
        generatedCards[msg.sender].push(newCard);
        generatedCardsByNftId[msg.sender][pokemonCardNftID] = newCard;
        totalCardsGenerated[msg.sender]++;
        lastTimeGenerated[msg.sender] = block.number;

        vrfConsumer.updateRequest(requestId, msg.sender);

        emit PokemonCardGenerated(msg.sender, pokemonCardNftID, pokedexId, requestId);
    }

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
}
