// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";

import {SnorlieCoin} from "../src/PokeCoin.sol";
import {PokeCardCollection} from "../src/PokeCardCollection.sol";
import {PokeCardGenerator} from "../src/PokeCardGenerator.sol";
import {PokemonStakingPool} from "../src/protocol/PokemonStakingPool.sol";
import {RewardCalculator} from "../src/protocol/RewardCalculator.sol";
import {VRFConsumer} from "../src/VRFConsumer.sol";


contract DeployContracts is Script {
        RewardCalculator rewardCalculator;
        SnorlieCoin snorlieCoin;
        PokeCardCollection pokeCardCollection;
        PokeCardGenerator pokeCardGenerator;
        PokemonStakingPool pokemonStakingPool;
        VRFConsumer vrfConsumer;

    function run() public returns (address, address, address, address, address) {
        vm.startBroadcast();
        snorlieCoin = new SnorlieCoin(msg.sender, msg.sender);
        pokeCardCollection = new PokeCardCollection();
        vrfConsumer = new VRFConsumer();
        pokeCardGenerator = new PokeCardGenerator(address(pokeCardCollection), address(vrfConsumer));
        rewardCalculator = new RewardCalculator(address(pokemonStakingPool));
        pokemonStakingPool = new PokemonStakingPool(address(snorlieCoin), address(pokeCardCollection), address(pokeCardGenerator), address(rewardCalculator));
        vm.stopBroadcast();
        return (address(snorlieCoin), address(pokeCardCollection), address(pokeCardGenerator), address(pokemonStakingPool), address(rewardCalculator));
    }
}