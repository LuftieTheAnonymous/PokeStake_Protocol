// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "../lib/forge-std/src/Script.sol";
import {MarketPlace} from "../src/marketplace/MarketPlace.sol";
import {SnorlieCoin} from "../src/PokeCoin.sol";
import {PokeCardCollection} from "../src/PokeCardCollection.sol";
import {PokemonStakingPool} from "../src/staking/PokemonStakingPool.sol";
import {VRFConsumer} from "../src/vrf/VRFConsumer.sol";

contract DeployContracts is Script {
    SnorlieCoin snorlieCoin;
    PokeCardCollection pokeCardCollection;
    PokemonStakingPool pokemonStakingPool;
    VRFConsumer randomnessConsumer;
    MarketPlace marketplace;

    function run() public returns (SnorlieCoin, PokeCardCollection, PokemonStakingPool, VRFConsumer, MarketPlace) {
        vm.startBroadcast();
        randomnessConsumer = new VRFConsumer(
            vm.envUint("SUBSCRIPTION_ID_SEPOLIA"),
            vm.envAddress("COORDINATOR_SEPOLIA"),
            vm.envBytes32("KEYHASH_SEPOLIA")
        );

        snorlieCoin = new SnorlieCoin();
        pokeCardCollection = new PokeCardCollection(address(randomnessConsumer));

        pokemonStakingPool = new PokemonStakingPool(address(snorlieCoin), address(pokeCardCollection));

        snorlieCoin.transferOwnership(address(pokemonStakingPool));

        randomnessConsumer.transferManagerRole(address(pokeCardCollection));

        marketplace = new MarketPlace(
            address(snorlieCoin), address(pokeCardCollection), vm.envAddress("PRICE_FEED_ADDRESS_ETH_USD"), msg.sender
        );

        vm.stopBroadcast();

        return (snorlieCoin, pokeCardCollection, pokemonStakingPool, randomnessConsumer, marketplace);
    }
}
