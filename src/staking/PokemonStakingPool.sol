// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SnorlieCoin} from "../PokeCoin.sol";
import {PokeCardCollection} from "../PokeCardCollection.sol";

import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {IERC721Receiver} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract PokemonStakingPool is IERC721Receiver, ReentrancyGuard {
    using Math for uint256;

    // ERRORS
    error NotTheOwnerOfTheNFT();
    error MinimumBlocksToUnstakeNotReached();
    error NeedToClaimRewardsFirst();
    error ZeroAmountOfAwards();

    // EVENTS
    event Staked(address indexed user, uint256 indexed tokenId, uint256 pokemonRarityLevel, uint256 stakedAtBlock);
    event Unstaked(address indexed user, uint256 indexed tokenId);
    event RewardsClaimed(address indexed user, uint256 amount);

    struct PokeStakePosition {
        uint256 pokedexId;
        uint256 rarityLevel;
        uint256 nftId;
        string tokenURI;
        string pinataId;
        uint256 stakedAtBlock;
    }

    // Mappings
    mapping(address => PokeStakePosition[]) private stakedNfts;
    mapping(address => uint256) private lastClaimedAt;
    mapping(address => uint256) totalRewardsClaimed;

    // Constant values
    uint256 private constant minimumBlocksToUnstake = 7200; // 24 hours assuming 12s block time
    uint256 private constant rewardPerOneDayOfStake = 1e18;

    // External contracts referrences
    SnorlieCoin private immutable rewardToken;
    PokeCardCollection private immutable nftCollection;

    constructor(address rewardToken_, address nftCollection_) {
        // Initialize contracts' refferrences
        rewardToken = SnorlieCoin(rewardToken_);
        nftCollection = PokeCardCollection(nftCollection_);
    }

    // Modifiers

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

    modifier hasClaimedRewards() {
        uint256 amountToClaim = getRewardAmount(msg.sender);
        if (amountToClaim > 0) {
            revert NeedToClaimRewardsFirst();
        }
        _;
    }

    // Function

    // Callback for event once contract receives the token.
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        // Determine the rarity level of the staked Pokemon (this is a placeholder, you would need to implement your own logic to determine rarity)
        PokeCardCollection.PokemonCard memory pokemonCard = nftCollection.getGeneratedCardByNftId(from, tokenId);

        // Record the staking position
        stakedNfts[from].push(
            PokeStakePosition({
                nftId: tokenId,
                rarityLevel: uint256(pokemonCard.rarityLevel) + 1, // Adding 1 to avoid zero rarity levels
                tokenURI: pokemonCard.tokenURI,
                stakedAtBlock: block.number,
                pokedexId: pokemonCard.pokedexId,
                pinataId: pokemonCard.pinataId
            })
        );

        // Emit staked event
        emit Staked(from, tokenId, uint256(pokemonCard.rarityLevel), block.number);

        return IERC721Receiver.onERC721Received.selector;
    }

    function getStakedPositions(address user) public view returns (PokeStakePosition[] memory) {
        return stakedNfts[user];
    }

    // Transfers token the contract
    function stake(uint256 tokenId) public onlyNftOwner(tokenId) {
        nftCollection.safeTransferFrom(msg.sender, address(this), tokenId);
    }

    // Returns the token to it's owner only if the cooldownIsReached and he claimed the rewards he earned.
    function unstake(uint256 tokenId) external minimumBlocksToUnstakeReached(tokenId) nonReentrant hasClaimedRewards {
        // Find the staking position
        PokeStakePosition[] storage stakedPositions = stakedNfts[msg.sender];

        // store the destination address
        address destinationAddress = msg.sender;

        // Search the through staked positions
        for (uint256 i = 0; i < stakedPositions.length; i++) {
            // If found staked position with the sought idea
            if (stakedPositions[i].nftId == tokenId) {
                // Contract approves to send the token
                nftCollection.approve(destinationAddress, tokenId);

                // Transfer the NFT back to the owner
                nftCollection.safeTransferFrom(address(this), destinationAddress, tokenId);

                // Remove the staking position
                stakedPositions[i] = stakedPositions[stakedPositions.length - 1];
                stakedPositions.pop();

                // emit event of unstaked
                emit Unstaked(msg.sender, tokenId);
                break;
            }
        }
    }

    // calculates and returns the reward amount in SNORLIE-token from all staked positions.
    function calculateRewards(address user) public view returns (uint256) {
        // return staked positions
        PokemonStakingPool.PokeStakePosition[] memory stakedPositions = getStakedPositions(user);
        // define the variable for total rewards
        uint256 totalRewards = 0;
        // Iterate through the array of stakedPositions
        for (uint256 i = 0; i < stakedPositions.length; i++) {
            // Difference between current and starting block
            uint256 blocksDifference = block.number - stakedPositions[i].stakedAtBlock;

            // amount of seconds passed from staking to now
            uint256 stakedDurationInSeconds = blocksDifference * 12; // 12 seconds per block

            // amount of days, converted from seconds
            uint256 stakedDurationInDaysWad = (stakedDurationInSeconds * 1e18) / 86400;

            if (stakedDurationInDaysWad == 0) {
                continue; // Skip this position
            }

            // Derive the rarity multiplier
            uint256 rarityMultiplier = stakedPositions[i].rarityLevel;

            // calculate the rewards for staking and increase totalRewards amount
            uint256 positionRewards = (stakedDurationInDaysWad * rewardPerOneDayOfStake * rarityMultiplier) / 1e18;

            totalRewards += positionRewards;
        }
        return totalRewards;
    }

    // calculate and retrieved expected APY (Yearly earned tokens)
    function calculateAPY(address user) public view returns (uint256) {
        // retrieved staked positions
        PokemonStakingPool.PokeStakePosition[] memory stakedPositions = getStakedPositions(user);
        uint256 totalAPY = 0;

        // Go through the staked positions
        for (uint256 i = 0; i < stakedPositions.length; i++) {
            // get multiplier of a position
            uint256 rarityMultiplier = stakedPositions[i].rarityLevel;

            // retrieve APY for position
            uint256 apyForPosition = rewardPerOneDayOfStake * rarityMultiplier * 365;

            totalAPY += apyForPosition; // Assuming 365 days in a year
        }
        return totalAPY;
    }

    // claims rewards user earned through staking
    function claimRewards() public nonReentrant {
        uint256 rewardsToClaim = getRewardAmount(msg.sender);
        // if rewards to claim are 0, revert
        if (rewardsToClaim == 0) {
            revert ZeroAmountOfAwards();
        }
        // Increased amount of claimed rewards
        totalRewardsClaimed[msg.sender] += rewardsToClaim;
        // Change last claimed block number
        lastClaimedAt[msg.sender] = block.number;

        // mint reward amount
        rewardToken.mint(msg.sender, rewardsToClaim);

        // Emit successful reward claim.
        emit RewardsClaimed(msg.sender, rewardsToClaim);
    }

    function getRewardAmount(address member) public view returns (uint256) {
        uint256 rewardsToClaim = calculateRewards(member) - totalRewardsClaimed[member];
        // You can return this value or emit an event, depending on your needs
        return rewardsToClaim;
    }
}
