// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract PokemonStakingPool {

struct PokeStakePosition{
    uint256 nftId;
    uint256 pokemonRarityLevel;
    uint256 stakedAtBlock;
}

mapping(address=>PokeStakePosition[]) private stakedNfts;
mapping(address=>uint256) private lastClaimedAt;

mapping(address => uint256) totalRewardsClaimed;



uint256 constant private minimumBlocksToUnstake = 86400;

constructor(){}



function stake(uint256 tokenId) external {}


function unstake(uint256 tokenId) external {}


function claimRewards() external {}


function getRewardAmount() external {}


}