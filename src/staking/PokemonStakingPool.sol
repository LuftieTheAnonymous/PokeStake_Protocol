// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SnorlieCoin} from "../PokeCoin.sol";
import {PokeCardCollection} from "../PokeCardCollection.sol";

import {PokeCardGenerator} from "../PokeCardGenerator.sol";

import {RewardCalculator} from "./RewardCalculator.sol";
import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract PokemonStakingPool is ReentrancyGuard {
    error NotTheOwnerOfTheNFT();
    error MinimumBlocksToUnstakeNotReached();

    event Staked(address indexed user, uint256 indexed tokenId, uint256 pokemonRarityLevel, uint256 stakedAtBlock);
    event Unstaked(address indexed user, uint256 indexed tokenId);
    event RewardsClaimed(address indexed user, uint256 amount);

    struct PokeStakePosition {
        uint256 nftId;
        uint256 pokemonRarityLevel;
        uint256 stakedAtBlock;
    }

    mapping(address => PokeStakePosition[]) private stakedNfts;
    mapping(address => uint256) private lastClaimedAt;
    mapping(address => uint256) totalRewardsClaimed;

    uint256 private constant minimumBlocksToUnstake = 7200; // 24 hours assuming 12s block time

    SnorlieCoin private immutable rewardToken;
    PokeCardCollection private immutable nftCollection;
    RewardCalculator private immutable rewardCalculator;
    PokeCardGenerator private immutable pokeCardGenerator;

    constructor(address rewardToken_, address nftCollection_, address pokeCardGenerator_, address _rewardCalculator) {
        rewardToken = SnorlieCoin(rewardToken_);
        nftCollection = PokeCardCollection(nftCollection_);
        pokeCardGenerator = PokeCardGenerator(pokeCardGenerator_);
        rewardCalculator = RewardCalculator(_rewardCalculator);
    }

    modifier onlyNftOwner(uint256 tokenId) {
        if (nftCollection.ownerOf(tokenId) != msg.sender) {
            revert NotTheOwnerOfTheNFT();
        }
        _;
    }

    modifier minimumBlocksToUnstakeReached(uint256 tokenId) {
        PokeStakePosition[] memory stakedPositions = stakedNfts[msg.sender];
        uint256 stakedAtBlock;
        for (uint256 i = 0; i < stakedPositions.length; i++) {
            if (stakedPositions[i].nftId == tokenId) {
                stakedAtBlock = stakedPositions[i].stakedAtBlock;
                break;
            }
        }
        if (block.number < stakedAtBlock + minimumBlocksToUnstake) {
            revert MinimumBlocksToUnstakeNotReached();
        }
        _;
    }

    function stake(uint256 tokenId) external onlyNftOwner(tokenId) nonReentrant {
        // Transfer the NFT to the staking contract
        nftCollection.safeTransferFrom(msg.sender, address(this), tokenId);

        // Determine the rarity level of the staked Pokemon (this is a placeholder, you would need to implement your own logic to determine rarity)
        uint256 pokemonRarityLevel = uint256(pokeCardGenerator.getGeneratedCardByNftId(msg.sender, tokenId).rarityLevel);

        // Record the staking position
        stakedNfts[msg.sender].push(
            PokeStakePosition({
                nftId: tokenId,
                pokemonRarityLevel: pokemonRarityLevel + 1, // Adding 1 to avoid zero rarity levels
                stakedAtBlock: block.number
            })
        );
        emit Staked(msg.sender, tokenId, pokemonRarityLevel + 1, block.number);
    }

    function unstake(uint256 tokenId) external minimumBlocksToUnstakeReached(tokenId) nonReentrant {
        // Find the staking position and remove it
        PokeStakePosition[] storage stakedPositions = stakedNfts[msg.sender];
        for (uint256 i = 0; i < stakedPositions.length; i++) {
            if (stakedPositions[i].nftId == tokenId) {
                // Transfer the NFT back to the owner
                nftCollection.safeTransferFrom(address(this), msg.sender, tokenId);

                // Remove the staking position
                stakedPositions[i] = stakedPositions[stakedPositions.length - 1];
                stakedPositions.pop();
                break;
            }
        }
        emit Unstaked(msg.sender, tokenId);
    }

    function claimRewards() external nonReentrant {
        uint256 rewardsToClaim = getRewardAmount();
        totalRewardsClaimed[msg.sender] += rewardsToClaim;
        lastClaimedAt[msg.sender] = block.number;
        rewardToken.mint(msg.sender, rewardsToClaim);

        emit RewardsClaimed(msg.sender, rewardsToClaim);
    }

    function getRewardAmount() public view returns (uint256) {
        uint256 rewardsToClaim = rewardCalculator.calculateRewards(msg.sender) - totalRewardsClaimed[msg.sender];
        // You can return this value or emit an event, depending on your needs
        return rewardsToClaim;
    }

    function getStakedPositions(address user) external view returns (PokeStakePosition[] memory) {
        return stakedNfts[user];
    }
}
