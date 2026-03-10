// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.27;

import {Test} from "../lib/forge-std/src/Test.sol";

import {SnorlieCoin} from "../src/PokeCoin.sol";
import {PokeCardCollection} from "../src/PokeCardCollection.sol";
import {PokeCardGenerator} from "../src/PokeCardGenerator.sol";
import {PokemonStakingPool} from "../src/staking/PokemonStakingPool.sol";
import {RewardCalculator} from "../src/staking/RewardCalculator.sol";
import {DeployContracts} from "../script/DeployContracts.s.sol";
import {VRFMockCoordinator} from "../src/VRFMockCoordinator.sol";
contract PokeStakeTest is Test {
    DeployContracts deployer;
    SnorlieCoin snorlieCoin;
    PokeCardCollection pokeCardCollection;
    PokeCardGenerator pokeCardGenerator;
    PokemonStakingPool pokemonStakingPool;
    RewardCalculator rewardCalculator;
    VRFMockCoordinator vrfMockCoordinator;

    address actor = makeAddr("actor");

function setUp() public {

uint256 forkId = vm.createFork("https://ethereum-sepolia-rpc.publicnode.com");

    vm.selectFork(forkId);
        deployer = new DeployContracts();
        (snorlieCoin, pokeCardCollection, pokeCardGenerator, pokemonStakingPool, rewardCalculator, vrfMockCoordinator) = deployer.run();
         



        vm.deal(actor, 100 ether);
        vm.deal(address(vrfMockCoordinator), 1000000 ether);
        
        vrfMockCoordinator.fundSubscription(pokeCardGenerator.getSubscriptionId(), 1000000 ether);



}

function testPokemonRandomGeneration() public {
    vm.startPrank(actor);
    
    // Fund BEFORE requesting
    vrfMockCoordinator.fundSubscription(pokeCardGenerator.getSubscriptionId(), 10 ether);
    
    pokeCardGenerator.requestRandomWords();
    
    vrfMockCoordinator.fulfillRandomWords(pokeCardGenerator.getRequestId(), address(pokeCardGenerator));

    uint256[] memory randomWords = pokeCardGenerator.getRandomWords();

vm.expectRevert();
pokeCardGenerator.generatePokemon(13, 24, "https://");

    pokeCardGenerator.generatePokemon(randomWords[0], randomWords[1], "https://");

    assert(randomWords.length != 0);
    
    pokeCardGenerator.requestRandomWords();
    
    vrfMockCoordinator.fulfillRandomWords(pokeCardGenerator.getRequestId(), address(pokeCardGenerator));

    uint256[] memory randomWords2 = pokeCardGenerator.getRandomWords();

    vm.expectRevert();
    pokeCardGenerator.generatePokemon(randomWords2[0], randomWords2[1], "https://");
    
    vm.stopPrank();
}





}
