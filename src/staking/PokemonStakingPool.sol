// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SnorlieCoin} from "../PokeCoin.sol";
import {PokeCardCollection} from "../PokeCardCollection.sol";

import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {IERC721Receiver} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract PokemonStakingPool is IERC721Receiver, ReentrancyGuard {
    using Math for uint256;

    error OperationNotSuccessful();

    uint256 private constant rewardPerOneDayOfStake = 1 ether;

    

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

    constructor(address rewardToken_, address nftCollection_) {
        rewardToken = SnorlieCoin(rewardToken_);
        nftCollection = PokeCardCollection(nftCollection_);
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

   function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
) external override returns (bytes4) {
      // Determine the rarity level of the staked Pokemon (this is a placeholder, you would need to implement your own logic to determine rarity)
        uint256 pokemonRarityLevel = uint256(nftCollection.getGeneratedCardByNftId(msg.sender, tokenId).rarityLevel);

        // Record the staking position
        stakedNfts[msg.sender].push(
            PokeStakePosition({
                nftId: tokenId,
                pokemonRarityLevel: pokemonRarityLevel + 1, // Adding 1 to avoid zero rarity levels
                stakedAtBlock: block.number
            })
        );
    
     emit Staked(msg.sender, tokenId, pokemonRarityLevel, block.number);
    
    return IERC721Receiver.onERC721Received.selector;
}


    function stake(uint256 tokenId) external onlyNftOwner(tokenId) nonReentrant {
        // Transfer the NFT to the staking contract
        nftCollection.safeTransferFrom(msg.sender, address(this), tokenId);
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


    function getStakedPositions(address user) public view returns (PokeStakePosition[] memory) {
        return stakedNfts[user];
    }

    function calculateRewards(address user) public view returns (uint256) {
        PokemonStakingPool.PokeStakePosition[] memory stakedPositions = getStakedPositions(user);
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
            totalRewards += (stakedDurationInDays * rewardPerOneDayOfStake) * (rarityMultiplier + 1);
        }
        return totalRewards;
    }

    function calculateAPY() public view returns (uint256) {
        PokemonStakingPool.PokeStakePosition[] memory stakedPositions = getStakedPositions(msg.sender);
        uint256 totalAPY = 0;
        for (uint256 i = 0; i < stakedPositions.length; i++) {
            uint256 rarityMultiplier = stakedPositions[i].pokemonRarityLevel;

            (bool divSuccess, uint256 apyForPosition) = Math.tryMul(rewardPerOneDayOfStake * (rarityMultiplier + 1), 365);
            if (!divSuccess) {
                revert OperationNotSuccessful();
            }
            totalAPY += apyForPosition; // Assuming 365 days in a year
        }
        return totalAPY;
    }


    function claimRewards() external nonReentrant {
        uint256 rewardsToClaim = getRewardAmount();
        totalRewardsClaimed[msg.sender] += rewardsToClaim;
        lastClaimedAt[msg.sender] = block.number;
        rewardToken.mint(msg.sender, rewardsToClaim);

        emit RewardsClaimed(msg.sender, rewardsToClaim);
    }

    function getRewardAmount() public view returns (uint256) {
        uint256 rewardsToClaim = calculateRewards(msg.sender) - totalRewardsClaimed[msg.sender];
        // You can return this value or emit an event, depending on your needs
        return rewardsToClaim;
    }

}
