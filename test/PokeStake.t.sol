// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.27;

import {Test} from "../lib/forge-std/src/Test.sol";

import {SnorlieCoin} from "../src/PokeCoin.sol";
import {PokeCardCollection} from "../src/PokeCardCollection.sol";
import {PokeCardGenerator} from "../src/PokeCardGenerator.sol";
import {PokemonStakingPool} from "../src/staking/PokemonStakingPool.sol";
import {RewardCalculator} from "../src/staking/RewardCalculator.sol";


contract PokeStakeTest is Test {

SnorlieCoin snorlieCoin;
PokeCardCollection pokeCardCollection;
PokeCardGenerator pokeCardGenerator;
PokemonStakingPool pokemonStakingPool;
RewardCalculator rewardCalculator;




}