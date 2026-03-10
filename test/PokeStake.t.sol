// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.27;

import {Test} from "../lib/forge-std/src/Test.sol";

import {SnorlieCoin} from "../src/PokeCoin.sol";
import {PokeCardCollection} from "../src/PokeCardCollection.sol";
import {PokemonStakingPool} from "../src/staking/PokemonStakingPool.sol";
import {RewardCalculator} from "../src/staking/RewardCalculator.sol";
import {DeployContracts} from "../script/DeployContracts.s.sol";
import {VRFMockCoordinator} from "../src/vrf/VRFMockCoordinator.sol";
import {VRFConsumer} from "../src/vrf/VRFConsumer.sol";
contract PokeStakeTest is Test {
    DeployContracts deployer;
    SnorlieCoin snorlieCoin;
    PokeCardCollection pokeCardCollection;
    PokemonStakingPool pokemonStakingPool;
    RewardCalculator rewardCalculator;
    VRFMockCoordinator vrfMockCoordinator;
    VRFConsumer randomnessConsumer;

    address actor = makeAddr("actor");

function setUp() public {

uint256 forkId = vm.createFork("https://ethereum-sepolia-rpc.publicnode.com");

    vm.selectFork(forkId);
        deployer = new DeployContracts();
        (snorlieCoin, pokeCardCollection, pokemonStakingPool, rewardCalculator,
         vrfMockCoordinator, randomnessConsumer) = deployer.run();

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

    uint256[] memory randomWords = randomnessConsumer.getRandomWords();

vm.expectRevert();
pokeCardCollection.generatePokemon(133, 23, "https://");

    pokeCardCollection.generatePokemon(randomWords[0], randomWords[1], "https://");

    assert(randomWords.length != 0);

    vm.expectRevert();
    pokeCardCollection.generatePokemon(randomWords[0], randomWords[1], "https://");

     randomnessConsumer.requestRandomWords();
    
    vrfMockCoordinator.fulfillRandomWords(randomnessConsumer.getRequestId(), address(randomnessConsumer));

    uint256[] memory randomWords2 = randomnessConsumer.getRandomWords();

    vm.expectRevert();
    pokeCardCollection.generatePokemon(randomWords2[0], randomWords2[1], "https://");
    vm.stopPrank();
}

function testPokemonRandomGeneration() public {
    randomnessRequestAndFulfillment();
}


function testSnorlieCoin() public {
    snorlieCoin.totalSupply();
}

function testStaking() public {
randomnessRequestAndFulfillment();

assert(pokeCardCollection.totalSupply() > 0);
assert(pokeCardCollection.getGeneratedCards(actor).length > 0);
assert(pokeCardCollection.ownerOf(0) == actor);

    vm.startPrank(actor);
    pokeCardCollection.approve(address(pokemonStakingPool), 0);
    pokemonStakingPool.stake(0);
    vm.roll(block.number + 7200);
    pokemonStakingPool.unstake(0);
    pokemonStakingPool.claimRewards();
    vm.stopPrank();

    assert(snorlieCoin.balanceOf(actor) > 0);
    }





}
