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

    address actor = address(0x123);

function setUp() public {

uint256 forkId = vm.createFork("https://ethereum-sepolia-rpc.publicnode.com");

    vm.selectFork(forkId);
        deployer = new DeployContracts();
        (snorlieCoin, pokeCardCollection, pokeCardGenerator, pokemonStakingPool, rewardCalculator, vrfMockCoordinator) = deployer.run();
         
        vm.deal(actor, 100 ether);
        
        vm.prank(actor);
        vrfMockCoordinator.fundSubscription(pokeCardGenerator.getSubscriptionId(), 10 ether);
}

function test_SnorlieCoinDeployment() public {
    vm.startPrank(actor);
    
    // Fund BEFORE requesting
    vrfMockCoordinator.fundSubscription(pokeCardGenerator.getSubscriptionId(), 10 ether);
    
    pokeCardGenerator.requestRandomWords();
    
    vrfMockCoordinator.fulfillRandomWords(pokeCardGenerator.getRequestId(), address(pokeCardGenerator));

    uint256[] memory randomWords = pokeCardGenerator.getRandomWords();

    assert(randomWords.length != 0);
    vm.stopPrank();
}



}
