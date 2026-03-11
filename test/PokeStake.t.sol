// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.27;

import {Test} from "../lib/forge-std/src/Test.sol";

import {SnorlieCoin} from "../src/PokeCoin.sol";
import {PokeCardCollection} from "../src/PokeCardCollection.sol";
import {PokemonStakingPool} from "../src/staking/PokemonStakingPool.sol";
import {DeployContracts} from "../script/DeployContracts.s.sol";
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

        vrfMockCoordinator.fulfillRandomWords(randomnessConsumer.getRequestId(), address(randomnessConsumer));

        vm.expectRevert();
        pokeCardCollection.generatePokemon(4, "https://");

        pokeCardCollection.generatePokemon(randomnessConsumer.getRequestId(), "https://");

        randomnessConsumer.requestRandomWords();

        vrfMockCoordinator.fulfillRandomWords(randomnessConsumer.getRequestId(), address(randomnessConsumer));

uint256 requestId = randomnessConsumer.getRequestId();
        vm.expectRevert();
        pokeCardCollection.generatePokemon(requestId - 1, "https://");

        vm.roll(block.number + 10000);
        vm.expectRevert();
        pokeCardCollection.generatePokemon(requestId - 1, "https://");
        vm.stopPrank();
    }

    function testPokemonRandomGeneration() public {
        randomnessRequestAndFulfillment();
    }

    function testStaking() public {
        vm.startPrank(actor);

        vrfMockCoordinator.fundSubscription(randomnessConsumer.getSubscriptionId(), 10 ether);

        randomnessConsumer.requestRandomWords();

        vrfMockCoordinator.fulfillRandomWords(randomnessConsumer.getRequestId(), address(randomnessConsumer));


uint256 firstRequestId = randomnessConsumer.getRequestId();

        pokeCardCollection.generatePokemon(firstRequestId, "https://");
        vm.expectRevert();
        pokeCardCollection.generatePokemon(firstRequestId - 1, "https://");
        
        vm.expectRevert();
        randomnessConsumer.getRequestData(firstRequestId + 1, actor);
        
        vm.expectRevert();
        randomnessConsumer.getRequestData(firstRequestId, actor);

        vm.expectRevert();
        randomnessConsumer.updateRequest(firstRequestId, actor);
       
        vm.expectRevert();
        randomnessConsumer.updateRequest(firstRequestId + 1, actor);

        vm.expectRevert();
        pokeCardCollection.getRandomValuesConverted(firstRequestId - 1);

        vm.expectRevert();
        pokeCardCollection.getRandomValuesConverted(firstRequestId);

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
