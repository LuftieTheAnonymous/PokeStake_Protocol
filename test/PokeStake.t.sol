// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.27;

import {Test} from "../lib/forge-std/src/Test.sol";

import {SnorlieCoin} from "../src/PokeCoin.sol";
import {PokeCardCollection} from "../src/PokeCardCollection.sol";
import {PokemonStakingPool} from "../src/staking/PokemonStakingPool.sol";
import {DeployContracts} from "../script/DeployTestContracts.s.sol";
import {VRFMockCoordinator} from "../src/vrf/VRFMockCoordinator.sol";
import {VRFConsumer} from "../src/vrf/VRFConsumer.sol";

contract PokeStakeTest is Test {
    DeployContracts deployer;
    SnorlieCoin snorlieCoin;
    PokeCardCollection pokeCardCollection;
    PokemonStakingPool pokemonStakingPool;
    VRFMockCoordinator vrfMockCoordinator;
    VRFConsumer randomnessConsumer;

    address actor = makeAddr("actor");

    function setUp() public {
        uint256 forkId = vm.createFork("https://ethereum-sepolia-rpc.publicnode.com");

        vm.selectFork(forkId);
        deployer = new DeployContracts();
        (snorlieCoin, pokeCardCollection, pokemonStakingPool, vrfMockCoordinator, randomnessConsumer) = deployer.run();

        vm.deal(actor, 100 ether);
        vm.deal(address(vrfMockCoordinator), 1000000 ether);

        vrfMockCoordinator.fundSubscription(randomnessConsumer.getSubscriptionId(), 1000000 ether);
    }

    function randomnessRequestAndFulfillment() public {
        vm.startPrank(actor);
        // Fund BEFORE requesting
        vrfMockCoordinator.fundSubscription(randomnessConsumer.getSubscriptionId(), 10 ether);

        randomnessConsumer.requestRandomWords();

        uint256 first_random_request_id = randomnessConsumer.getRequestId(actor);

        vrfMockCoordinator.fulfillRandomWords(first_random_request_id, address(randomnessConsumer));

        assert(randomnessConsumer.getRequestId(actor) == first_random_request_id);

        vm.expectRevert();
        pokeCardCollection.generatePokemon("https://", "");

        pokeCardCollection.generatePokemon("https://", "");

        // First token generation

        randomnessConsumer.requestRandomWords();

        assert(randomnessConsumer.getRequestId(msg.sender) == 2);

        vrfMockCoordinator.fulfillRandomWords(randomnessConsumer.getRequestId(msg.sender), address(randomnessConsumer));

        vm.expectRevert();
        pokeCardCollection.generatePokemon("https://", "");

        vm.roll(block.number + 10000);
        vm.expectRevert();
        pokeCardCollection.generatePokemon("https://", "");
        vm.stopPrank();
    }

    function testPokemonRandomGeneration() public {
        randomnessRequestAndFulfillment();
    }

    function testStaking() public {
        vm.startPrank(actor);

        vrfMockCoordinator.fundSubscription(randomnessConsumer.getSubscriptionId(), 10 ether);

        randomnessConsumer.requestRandomWords();

        vrfMockCoordinator.fulfillRandomWords(randomnessConsumer.getRequestId(msg.sender), address(randomnessConsumer));

        pokeCardCollection.generatePokemon("https://", "32sdgsdgsdhd");

        assert(pokeCardCollection.totalSupply() > 0);
        assert(pokeCardCollection.getGeneratedCards(actor).length > 0);
        assert(pokeCardCollection.ownerOf(0) == actor);

        pokeCardCollection.getLastTimeGenerated(actor);
        pokeCardCollection.getTotalCardsGenerated(actor);
        pokeCardCollection.getGeneratedCards(actor);

        pokeCardCollection.supportsInterface(bytes4("How"));

        pokeCardCollection.approve(address(pokemonStakingPool), 0);
        pokemonStakingPool.stake(0);

        vm.expectRevert();
        pokemonStakingPool.stake(0);

        vm.expectRevert();
        pokemonStakingPool.unstake(0);

        vm.roll(block.number + 72000); // Simulate time passing (assuming 12s block time, this is roughly 1 day)
        for (uint256 i = 0; i > 2; i++) {
            vm.expectRevert();
            pokemonStakingPool.claimRewards();
        }

        pokemonStakingPool.claimRewards();

        for (uint256 i = 0; i > 2; i++) {
            vm.expectRevert();
            pokemonStakingPool.unstake(0);
        }

        pokemonStakingPool.unstake(0);

        assert(snorlieCoin.balanceOf(actor) > 0);
        snorlieCoin.burn(snorlieCoin.balanceOf(actor));

        vm.expectRevert();
        pokeCardCollection.setPokemonAmountToGenerate(156);
        vm.stopPrank();

        vm.expectRevert();
        pokeCardCollection.burn(0);
    }

    function testDumbCases() public {
        vm.startPrank(actor);
        vm.expectRevert();
        snorlieCoin.mint(msg.sender, 12e18);
        vm.expectRevert();
        snorlieCoin.burn(100e18);

        vm.stopPrank();
    }
}
