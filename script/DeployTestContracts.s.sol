// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "../lib/forge-std/src/Script.sol";

import {SnorlieCoin} from "../src/PokeCoin.sol";
import {PokeCardCollection} from "../src/PokeCardCollection.sol";
import {PokemonStakingPool} from "../src/staking/PokemonStakingPool.sol";
import {VRFMockCoordinator} from "../src/vrf/VRFMockCoordinator.sol";
import {VRFConsumer} from "../src/vrf/VRFConsumer.sol";

contract DeployContracts is Script {
    SnorlieCoin snorlieCoin;
    PokeCardCollection pokeCardCollection;
    PokemonStakingPool pokemonStakingPool;
    VRFMockCoordinator vrfMockCoordinator;
    VRFConsumer randomnessConsumer;
    bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    function run()
        public
        returns (SnorlieCoin, PokeCardCollection, PokemonStakingPool, VRFMockCoordinator, VRFConsumer)
    {
        vm.startBroadcast();
        vrfMockCoordinator = new VRFMockCoordinator(100000000000000000, 1000000000, 4e15);

        // // CREATE YOUR OWN SUBSCRIPTION
        uint256 subscriptionId = vrfMockCoordinator.createSubscription();

        // vm.envAddress("COORDINATOR_SEPOLIA")
        randomnessConsumer = new VRFConsumer(subscriptionId, address(vrfMockCoordinator), keyHash);

        snorlieCoin = new SnorlieCoin();
        pokeCardCollection = new PokeCardCollection(address(randomnessConsumer));

        pokemonStakingPool = new PokemonStakingPool(address(snorlieCoin), address(pokeCardCollection));

        vrfMockCoordinator.addConsumer(subscriptionId, address(randomnessConsumer));

        snorlieCoin.transferOwnership(address(pokemonStakingPool));

        randomnessConsumer.transferManagerRole(address(pokeCardCollection));

        vm.stopBroadcast();

        return (snorlieCoin, pokeCardCollection, pokemonStakingPool, vrfMockCoordinator, randomnessConsumer);
    }
}
