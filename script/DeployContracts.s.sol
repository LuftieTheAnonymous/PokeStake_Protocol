// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "../lib/forge-std/src/Script.sol";

import {SnorlieCoin} from "../src/PokeCoin.sol";
import {PokeCardCollection} from "../src/PokeCardCollection.sol";
import {PokeCardGenerator} from "../src/PokeCardGenerator.sol";
import {PokemonStakingPool} from "../src/staking/PokemonStakingPool.sol";
import {RewardCalculator} from "../src/staking/RewardCalculator.sol";

import {VRFMockCoordinator} from "../src/VRFMockCoordinator.sol";

contract DeployContracts is Script {
    RewardCalculator rewardCalculator;
    SnorlieCoin snorlieCoin;
    PokeCardCollection pokeCardCollection;
    PokeCardGenerator pokeCardGenerator;
    PokemonStakingPool pokemonStakingPool;
    VRFMockCoordinator vrfMockCoordinator;
    bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    function run() public returns (SnorlieCoin, PokeCardCollection, PokeCardGenerator, PokemonStakingPool, RewardCalculator,
     VRFMockCoordinator) {
        vm.startBroadcast();
        
        snorlieCoin = new SnorlieCoin();
        pokeCardCollection = new PokeCardCollection();
        vrfMockCoordinator = new VRFMockCoordinator(100000000000000000, 1000000000, 4e15);
        
        // CREATE YOUR OWN SUBSCRIPTION
        uint256 subscriptionId = vrfMockCoordinator.createSubscription();
     
        pokeCardGenerator = new PokeCardGenerator(address(pokeCardCollection), address(vrfMockCoordinator), keyHash, subscriptionId);
        rewardCalculator = new RewardCalculator(address(pokemonStakingPool));
        pokemonStakingPool = new PokemonStakingPool(
            address(snorlieCoin), address(pokeCardCollection), address(pokeCardGenerator), address(rewardCalculator)
        );


        snorlieCoin.transferOwnership(address(pokemonStakingPool));

        // ADD CONSUMER TO YOUR SUBSCRIPTION
        vrfMockCoordinator.addConsumer(subscriptionId, address(pokeCardGenerator));

        pokeCardCollection.transferOwnership(address(pokeCardGenerator));

        vrfMockCoordinator.transferOwnership(address(pokeCardGenerator));

        vm.stopBroadcast();

        return (
            snorlieCoin,
            pokeCardCollection,
            pokeCardGenerator,
            pokemonStakingPool,
            rewardCalculator,
            vrfMockCoordinator
        );
    }
}
