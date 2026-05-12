// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC721, IERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721URIStorage} from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {VRFConsumer} from "./vrf/VRFConsumer.sol";

contract PokeCardCollection is ERC721, ERC721URIStorage, ERC721Burnable, ReentrancyGuard, AccessControl {
    // ERRORS
    error GenerationCooldownNotReached();
    error NotMinter();
    error NotOwner();
    error ResolvedRequest(uint256 requestId);
    error NoResolvedRequestOrNoRequestSent(address caller);

    // EVENTS

    event PokemonCardGenerated(address indexed user, uint256 indexed nftId, uint256 pokedexId, uint256 requestId, string pinataId);

    event PokemonCardDestroyed(address indexed user, uint256 indexed nftId);

    // ENUM
    enum PokemonRarityLevel {
        Common,
        Uncommon,
        Rare,
        UltraRare
    }

    // STRUCT
    struct PokemonCard {
        uint256 pokedexId;
        PokemonRarityLevel rarityLevel;
        uint256 nftId;
        string tokenURI;
        string pinataId;
    }

    // Variables
    uint256 private pokemonAmountToGenerate = 151;
    uint256 private constant rarityLevels = 4;
    uint256 private constant generationCooldownInBlock = 7200;
    bytes32 private constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    VRFConsumer private vrfConsumer;
    uint256 private _nextTokenId;

    // Mappings 
    mapping(uint256 => PokemonCard) private generatedCardsByNftId; // assignment owner => tokenId => PokeCard
    mapping(address => uint256) private lastTimeGenerated; // last time someone drew a pokecard

    constructor(address vrfConsumerAddress) ERC721("PokeCard", "PICA") {
        vrfConsumer = VRFConsumer(vrfConsumerAddress);
        _grantRole(CONTROLLER_ROLE, msg.sender);
    }

    // Modifiers

    modifier generationCooldown() {
        // if block number is lesser than recent call + cooldown time in blocks, revert
        if (block.number < lastTimeGenerated[msg.sender] + generationCooldownInBlock) {
            revert GenerationCooldownNotReached();
        }
        _;
    }

    modifier onlyController() {
        // Revert if not controller
        if (!hasRole(CONTROLLER_ROLE, msg.sender)) {
            revert NotMinter();
        }
        _;
    }

    modifier onlyCardOwner(uint256 nftId) {
        // revert if not owner of card
        if (ownerOf(nftId) != msg.sender) {
            revert NotOwner();
        }
        _;
    }

    modifier hasSentRequestOrRequestPassed() {
        // revert if no values assigned to recent request of user or no request sent.
        if (vrfConsumer.getRequestDataArray(msg.sender).length == 0 || vrfConsumer.getRequestId(msg.sender) == 0) {
            revert NoResolvedRequestOrNoRequestSent(msg.sender);
        }
        _;
    }

    // Pokecard

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

    // Updates values in mappings and transfers to new owner.
    function safeTransferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function burn(uint256 tokenId) public override onlyCardOwner(tokenId) {
        super.burn(tokenId);
        emit PokemonCardDestroyed(msg.sender, tokenId);
    }

    // Generates a PokeCard based on the random value retrieved from VRFConsumer
    function generatePokemon(string memory token_uri, string memory pinataId)
        external
        hasSentRequestOrRequestPassed
        generationCooldown
        nonReentrant
    {
        // Retrieves the user's requestId
        uint256 requestId = vrfConsumer.getRequestId(msg.sender);
        // Retrieves data from the successfully fulfilled request for numbers
        (uint256 pokedexId, uint256 rarityLevel, bool isRequestResolved) =
            vrfConsumer.getRequestData(msg.sender, pokemonAmountToGenerate, rarityLevels);

        // check if the request is resolved, if yes, revert
        if (isRequestResolved == true) {
            revert ResolvedRequest(requestId);
        }
        // Get newly minted nft id
        uint256 pokemonCardNftID = mint(msg.sender, token_uri);
        // Generate a pokemon-card
        PokemonCard memory newCard = PokemonCard({
            pokedexId: pokedexId,
            rarityLevel: PokemonRarityLevel(rarityLevel),
            nftId: pokemonCardNftID,
            tokenURI: token_uri,
            pinataId: pinataId
        });
        // Assign the values to mappings with entry of called
        generatedCardsByNftId[pokemonCardNftID] = newCard;
        lastTimeGenerated[msg.sender] = block.number;

        // Set request to resolved.
        vrfConsumer.updateRequest(requestId, msg.sender);

        emit PokemonCardGenerated(msg.sender, pokemonCardNftID, pokedexId, requestId, pinataId);
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

    function getLastTimeGenerated(address user) external view returns (uint256) {
        return lastTimeGenerated[user];
    }

    function getGeneratedCardByNftId(uint256 nftId) external view returns (PokemonCard memory) {
        return generatedCardsByNftId[nftId];
    }

    function totalSupply() public view returns (uint256) {
        return _nextTokenId;
    }
}
