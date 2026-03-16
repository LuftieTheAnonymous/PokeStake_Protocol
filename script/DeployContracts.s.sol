// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "../lib/forge-std/src/Script.sol";

import {SnorlieCoin} from "../src/PokeCoin.sol";
import {PokeCardCollection} from "../src/PokeCardCollection.sol";
import {PokemonStakingPool} from "../src/staking/PokemonStakingPool.sol";
import {VRFConsumer} from "../src/vrf/VRFConsumer.sol";

contract DeployContracts is Script {
    SnorlieCoin snorlieCoin;
    PokeCardCollection pokeCardCollection;
    PokemonStakingPool pokemonStakingPool;
    // VRFMockCoordinator vrfMockCoordinator;
    VRFConsumer randomnessConsumer;
    MarketPlace marketplace;
    // bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    function run() public returns (SnorlieCoin, PokeCardCollection, PokemonStakingPool, VRFConsumer) {
        vm.startBroadcast();
        // vrfMockCoordinator = new VRFMockCoordinator(100000000000000000, 1000000000, 4e15);

        // // CREATE YOUR OWN SUBSCRIPTION
        // uint256 subscriptionId = vrfMockCoordinator.createSubscription();

        // vm.envAddress("COORDINATOR_SEPOLIA")
        randomnessConsumer = new VRFConsumer(
            vm.envUint("SUBSCRIPTION_ID_SEPOLIA"),
            vm.envAddress("COORDINATOR_SEPOLIA"),
            vm.envBytes32("KEYHASH_SEPOLIA")
        );

        snorlieCoin = new SnorlieCoin();
        pokeCardCollection = new PokeCardCollection(address(randomnessConsumer));

        pokemonStakingPool = new PokemonStakingPool(address(snorlieCoin), address(pokeCardCollection));

        // ADD CONSUMER TO YOUR SUBSCRIPTION IN PROD vm.envUint("SUBSCRIPTION_ID_SEPOLIA")
        // vrfMockCoordinator.addConsumer(subscriptionId, address(randomnessConsumer));

        snorlieCoin.transferOwnership(address(pokemonStakingPool));

        randomnessConsumer.transferManagerRole(address(pokeCardCollection));

        marketplace = new MarketPlace(
            address(snorlieCoin), address(pokeCardCollection), vm.envAddress("PRICE_FEED_ADDRESS_ETH_USD"), msg.sender
        );

        // vrfMockCoordinator.transferOwnership(address(pokeCardCollection));

        vm.stopBroadcast();

        return (snorlieCoin, pokeCardCollection, pokemonStakingPool, randomnessConsumer, marketplace);
    }
}
