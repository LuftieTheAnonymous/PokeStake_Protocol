// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {PokeCard} from "./PokeCard.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract PokeCardRandomGenerator is VRFCoordinatorV2_5Mock {

error IsNotManager(address caller);
PokeCard pokeCardNFT;
bytes32 constant private POKE_MANAGER_ROLE = bytes32("POKE_MANAGER_ROLE");
uint256 private pokemonAmountAllowed;

enum PokemonRarity {
        COMMON,
        UNCOMMON,
        RARE,
        LEGENDARY
    }

 struct PokemonMetadata {
        string name;
        uint256 pokedexId;
        PokemonRarity rarity;
        uint256 rewardMultiplier;  // e.g., LEGENDARY = 3x rewards
        string imageURI;           // IPFS hash or data URI
    }

constructor(address pokeCardNftAddress)VRFCoordinatorV2_5Mock(18e18, 13e17, 13e13){
    pokeCardNFT = PokeCard(pokeCardNftAddress);
    pokemonAmountAllowed = 151;
}








}


