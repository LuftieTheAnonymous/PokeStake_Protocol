// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.27;

import {Test} from "../lib/forge-std/src/Test.sol";

import {console} from "../lib/forge-std/src/console.sol";

import {SnorlieCoin} from "../src/PokeCoin.sol";
import {MarketPlace} from "../src/marketplace/MarketPlace.sol";
import {PokeCardCollection} from "../src/PokeCardCollection.sol";
import {PokemonStakingPool} from "../src/staking/PokemonStakingPool.sol";
import {DeployContracts} from "../script/DeployTestContracts.s.sol";
import {VRFMockCoordinator} from "../src/vrf/VRFMockCoordinator.sol";
import {VRFConsumer} from "../src/vrf/VRFConsumer.sol";

contract PokeStakeTest is Test {
    using console for uint256;
    using console for string;

    DeployContracts deployer;
    SnorlieCoin snorlieCoin;
    PokeCardCollection pokeCardCollection;
    PokemonStakingPool pokemonStakingPool;
    VRFMockCoordinator vrfMockCoordinator;
    VRFConsumer randomnessConsumer;
    MarketPlace marketplace;

    address actor = makeAddr("actor");
    address actor2 = makeAddr("actor2");

    function setUp() public {
        uint256 forkId = vm.createFork("https://ethereum-sepolia-rpc.publicnode.com");

        vm.selectFork(forkId);
        deployer = new DeployContracts();
        (snorlieCoin, pokeCardCollection, pokemonStakingPool, vrfMockCoordinator, 
        randomnessConsumer, marketplace) = deployer.run();

        vm.deal(actor, 100 ether);
        vm.deal(address(vrfMockCoordinator), 1000000 ether);

        vrfMockCoordinator.fundSubscription(randomnessConsumer.getSubscriptionId(), 1000000 ether);
    }

    function simulatePokemonGeneration() public {
        vm.startPrank(actor);

        // NO VALID REQUEST ID
        vm.expectRevert();
        pokeCardCollection.generatePokemon("https://", "");

        (uint256 requestId) = randomnessConsumer.requestRandomWords();
        
        // NOT ABLE TO RE-REQUEST THE WITHOUT COOLDOWN
        vm.expectRevert();
        randomnessConsumer.requestRandomWords();

        // NOT FULFILLED GENERATION
        vm.expectRevert();
        pokeCardCollection.generatePokemon("https://", "");
        
        vrfMockCoordinator.fulfillRandomWords(requestId, address(randomnessConsumer));

        pokeCardCollection.generatePokemon("https://", "");

        // COOLDOWN REVERT
        vm.expectRevert();
        pokeCardCollection.generatePokemon("https://", "");

        // REQUEST RESOLVED REVERT
        vm.roll(block.number + 7200);
        vm.expectRevert();
        pokeCardCollection.generatePokemon("https://", "");

        assert(pokeCardCollection.totalSupply() > 0);
        assert(pokeCardCollection.ownerOf(0) == actor);

        vm.stopPrank();
    }

    function testGeneratePokemonAndRevertCasesAndReadValues() public {
        simulatePokemonGeneration();

        vm.startPrank(actor);
        pokeCardCollection.approve(actor2, 0);
        pokeCardCollection.safeTransferFrom(actor, actor2, 0);
        vm.stopPrank();



        randomnessConsumer.getSubscriptionId();


        vm.startPrank(actor);
        randomnessConsumer.getRequestDataArray(msg.sender);

        vm.expectRevert();
        randomnessConsumer.getRequestData(msg.sender, 150, 4);

        randomnessConsumer.getRequestId(msg.sender);

        vm.expectRevert();
        randomnessConsumer.transferManagerRole(msg.sender);

        vm.expectRevert();
        randomnessConsumer.updateRequest(1, msg.sender);

        vm.expectRevert();
        randomnessConsumer.updateRequest(2, msg.sender);


        vm.stopPrank();
    }

    function testStakingProcesses() public {
        simulatePokemonGeneration();

        vm.expectRevert();
        pokemonStakingPool.stake(0);

        vm.startPrank(actor);

        // Approve to transfer token 
        pokeCardCollection.approve(address(pokemonStakingPool), 0);

        pokemonStakingPool.stake(0);

        vm.expectRevert();
        pokemonStakingPool.unstake(0);

        assert(pokemonStakingPool.getStakedPositions(actor).length != 0);

        vm.roll(block.number + 21600);

        (uint256 calculatedRewards) = pokemonStakingPool.calculateRewards(actor);

        assert(calculatedRewards == pokemonStakingPool.getRewardAmount(actor));

        assert(calculatedRewards >= 3e18);

        (uint256 calculatedAPY) = pokemonStakingPool.calculateAPY(actor);

        assert(calculatedAPY >= 365e18);

        vm.expectRevert();
        pokemonStakingPool.unstake(0);

     
        pokemonStakingPool.claimRewards();
        vm.expectRevert();
        pokemonStakingPool.claimRewards();
        

        pokemonStakingPool.unstake(0);


        assert(pokeCardCollection.ownerOf(0) == actor);

        vm.stopPrank();
    }

    function simulateListingToken() public {
            simulatePokemonGeneration();

        vm.startPrank(actor);
        vm.expectRevert();
        marketplace.listPokeCard(0, 1e16, true);

        pokeCardCollection.approve(address(marketplace), 0);
        marketplace.listPokeCard(0, 1e16, true);

        assert(pokeCardCollection.ownerOf(0) == address(marketplace));
        assert(marketplace.getListing(1).listingOwner == actor);
        vm.stopPrank();
    }


    function testMarketPlaceListingMechanics() public {
        simulateListingToken();
    }

    function testMarketPlaceDelistingMechanics() public {
        simulateListingToken();

        vm.startPrank(actor2);
        vm.expectRevert();
        marketplace.delistPokemonCard(1);
        vm.stopPrank();

        vm.roll(block.number + 600);
        marketplace.updateEthUsdPrice();

        vm.prank(actor);
        marketplace.delistPokemonCard(1);
        assert(pokeCardCollection.ownerOf(0) == actor);
    }


    function testMarketPlacePrelongingMechanics() public {
        simulateListingToken();

        vm.deal(actor2, 10000000 ether);
        vm.deal(actor, 1000 ether);

        console.log("Get listings", marketplace.getListingsAmount());
        (MarketPlace.SaleListing memory listing) = marketplace.getListing(1);

        vm.roll(listing.expiryBlock + 1000);
        
       vm.startPrank(actor2);
        vm.expectRevert();
        marketplace.purchasePokeCard{value:listing.listingPrice}(1, 0);

        vm.stopPrank();
        
        console.log(listing.listingOwner, "Listing owner");

        vm.prank(actor);
        marketplace.preLongListingTime{value:(5e18 * marketplace.getLatestEthUsdPrice() / 1e18)}(1, 0, true);

    }

    function testMarketPlaceManagerRoleMechanics() public {
        vm.startPrank(actor2);
        vm.expectRevert();
        marketplace.grantManagerRole(actor2);
        vm.stopPrank();
    }

    function testSnorlieCoinRevertCases() public {
        vm.startPrank(actor);
        vm.expectRevert();
        snorlieCoin.mint(msg.sender, 12e18);
        vm.expectRevert();
        snorlieCoin.burn(100e18);
        vm.expectRevert();
        snorlieCoin.transferOwnership(actor);
        vm.stopPrank();
    }

    function testPokeCardRevertTestCases() public {
        simulatePokemonGeneration();

        vm.expectRevert();
        pokeCardCollection.burn(0);

        vm.expectRevert();
        pokeCardCollection.burn(1);

        vm.prank(actor);
        pokeCardCollection.burn(0);
    }

}
