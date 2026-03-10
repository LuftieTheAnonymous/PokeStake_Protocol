// SPDX-License-Identifier: MIT
import {PokemonStakingPool} from "./PokemonStakingPool.sol";

import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

pragma solidity ^0.8.27;

contract RewardCalculator {
    using Math for uint256;

    error OperationNotSuccessful();

    uint256 private constant rewardPerOneDayOfStake = 1 ether;
    PokemonStakingPool pokemonStakingPool;

    constructor(address payable pokemonStakingPoolAddress) {
        pokemonStakingPool = PokemonStakingPool(pokemonStakingPoolAddress);
    }

    function calculateRewards(address user) external view returns (uint256) {
        PokemonStakingPool.PokeStakePosition[] memory stakedPositions = pokemonStakingPool.getStakedPositions(user);
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < stakedPositions.length; i++) {
            (bool mulSuccess, uint256 stakedDurationInSeconds) =
                Math.tryMul(block.number - stakedPositions[i].stakedAtBlock, 12); // Assuming 12s block time

            if (!mulSuccess) {
                revert OperationNotSuccessful();
            }

            (bool divSuccess, uint256 stakedDurationInDays) = Math.tryDiv(stakedDurationInSeconds, 86400); // Convert seconds to days

            if (!divSuccess) {
                revert OperationNotSuccessful();
            }

            uint256 rarityMultiplier = stakedPositions[i].pokemonRarityLevel;
            totalRewards += (stakedDurationInDays * rewardPerOneDayOfStake) * rarityMultiplier;
        }
        return totalRewards;
    }

    function calculateAPY() external view returns (uint256) {
        PokemonStakingPool.PokeStakePosition[] memory stakedPositions =
            pokemonStakingPool.getStakedPositions(msg.sender);
        uint256 totalAPY = 0;
        for (uint256 i = 0; i < stakedPositions.length; i++) {
            uint256 rarityMultiplier = stakedPositions[i].pokemonRarityLevel;

            (bool divSuccess, uint256 apyForPosition) = Math.tryMul(rewardPerOneDayOfStake * rarityMultiplier, 365);
            if (!divSuccess) {
                revert OperationNotSuccessful();
            }
            totalAPY += apyForPosition; // Assuming 365 days in a year
        }
        return totalAPY;
    }
}
