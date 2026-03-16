// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC721Receiver} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {
    AggregatorV3Interface
} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {SnorlieCoin} from "../PokeCoin.sol";
import {PokeCardCollection} from "../PokeCardCollection.sol";
import {AccessControl} from "../../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

contract MarketPlace is IERC721Receiver, ReentrancyGuard, AccessControl {
    // Securing the math for decimal 
    using Math for uint256;

    //ERRORS
    
    error NotPokeCardOwner(address caller, address actualOwner);

    error IncorrectAmountProvided(uint256 providedAmount, uint256 expectedAmount);

    error NotEnoughEtherToPayFee(uint256 transferredAmount);

    error PriceCannotBeZero();

    error InvalidPayment();

    error ListingExpired(uint256 expiryBlock, uint256 listingId);

    error NotOwnerOfListing(address sender);

    error NotManager(address sender);

    error NotEnoughContractBalance();

    error UnsuccessfullGrant();

    error NotEnoughSnorlies();

    error NonExistingSnorliePrelongingOffer();

    error IncorrectListingIdProvided();

    // EVENTS

    event ListedPokeCard(address seller, uint256 tokenId);

    event PokeCardSold(address puchasedBy, uint256 blockNumber);

    event PokeCardDelisted(uint256 listingId, uint256 tokenId);

    event ListingApperancePrelonged(uint256 listingId, address prelonger);

    event WithdrawnAmount(uint256 amountPaidout, address managerAddress);
    struct SaleListing {
        address listingOwner;
        uint256 nftId;
        string pinataId;
        uint256 listingBlockNumber;
        uint256 expiryBlock;
        uint256 listingPrice;
        bool isPriceInEth;
    }

    SnorlieCoin snorlieCoin;
    PokeCardCollection nftCollection;
    AggregatorV3Interface internal dataFeed;
    uint256 private s_listingAmount;
    uint256 private ethUsdPrice;
    uint256 private constant ROYALTY_PERCENTAGE = 3;
    uint256 private constant DECIMAL_NORMALIZER = 1e10;
    uint256 private constant UPDATE_BLOCK_QUANTITY = 3600;
    uint256 private constant INITIAL_LISTING_DURATION_IN_BLOCK = 216000;
    bytes32 private constant MARKETPLACE_MANAGER_ROLE = keccak256("MARKETPLACE_MANAGER_ROLE");
    mapping(uint256 listingId => SaleListing saleListing) private listings;
    mapping(uint256 priceInUSDC => uint256 blockQuantity) private prelongingOffersInETH;
    mapping(uint256 priceInUSDC => uint256 blockQuantity) private prelongingOffersInSnorlies;

    constructor(
        address snorlieCoinAddress,
        address pokeCardCollectionAddress,
        address ethUsdPriceFeed,
        address initialManager
    ) {
        // RETRIEVING REFERENCES TO CONTRACTS
        nftCollection = PokeCardCollection(pokeCardCollectionAddress);
        snorlieCoin = SnorlieCoin(snorlieCoinAddress);
        dataFeed = AggregatorV3Interface(ethUsdPriceFeed);
        
        // Updating the value for ethUsdPrice
        (uint256 ethUsdValue) = updateEthUsdPrice();

        // Define the price in USDC value required (paid in ETH) for prelonging the offer 
        prelongingOffersInETH[2e18] = 7200;
        prelongingOffersInETH[5e18] = 50400;
        prelongingOffersInETH[10e17] = 216000;
        prelongingOffersInETH[50e18] = 2628000;

        // Define the price in USDC value required (paid in SNORLIE) for prelonging the offer 
        prelongingOffersInSnorlies[100e18] = 7200;
        prelongingOffersInETH[500e18] = 50400;
        prelongingOffersInETH[750e18] = 216000;
        prelongingOffersInETH[1000e18] = 2628000;

        _grantRole(MARKETPLACE_MANAGER_ROLE, initialManager);
    }

    modifier isOwnerOfListing(uint256 listingId) {
        // If caller is not owner of the listing given the listingId, revert
        if (listings[listingId].listingOwner != msg.sender) {
            revert NotOwnerOfListing(msg.sender);
        }
        _;
    }

    modifier isListingActive(uint256 listingId) {
        // If expiryBlock is reached, do not allow to purchase (revert)
        if (listings[listingId].expiryBlock > block.number) {
            revert ListingExpired(listings[listingId].expiryBlock, listingId);
        }
        _;
    }

    modifier onlyManager() {
        // If has not manager role, revert
        if (!hasRole(MARKETPLACE_MANAGER_ROLE, msg.sender)) {
            revert NotManager(msg.sender);
        }
        _;
    }

    modifier isAmountInBalance(uint256 amount) {
        // If balance too small then the amount willing to be withdrawn
        if (amount > (address(this)).balance) {
            revert NotEnoughContractBalance();
        }
        _;
    }

    modifier isNftOwner(uint256 tokenId){
        if(nftCollection.ownerOf(tokenId) != msg.sender){
            revert NotPokeCardOwner(msg.sender, nftCollection.ownerOf(tokenId));
        }
        _;
    }

    fallback() external {}

    // MANAGER ONLY FUNCTIONS

    function withdrawContractAmount(uint256 amountToPayout)
        external
        nonReentrant
        onlyManager
        isAmountInBalance(amountToPayout)
    {
        // Attempt to send the amount specified by the manager/user
        (bool success,) = payable(msg.sender).call{value: amountToPayout}("");

        // If attempt not successful, revert
        if (!success) {
            revert InvalidPayment();
        }

        emit WithdrawnAmount(amountToPayout, msg.sender);
    }

    function grantManagerRole(address newManager) public onlyManager {
        // Grant Manager role to the address
        (bool success) = _grantRole(MARKETPLACE_MANAGER_ROLE, newManager);

        if (!success) {
            revert UnsuccessfullGrant();
        }
    }

    function revokeManagerRole() public onlyManager {
        // Revoke your manager role
        (bool success) = _revokeRole(MARKETPLACE_MANAGER_ROLE, msg.sender);

        if (!success) {
            revert UnsuccessfullGrant();
        }
    }

    function updateEthUsdPrice() public returns (uint256) {
        // prettier-ignore
        (
            /* uint80 roundId */
            ,
            int256 answer,
            /*uint256 startedAt*/
            ,
            uint256 updatedAt,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();

        // If answer is 0 and update time expired, update variable with normalizer and return the value, else return variable value
        if (answer > 0 && updatedAt >= block.timestamp - UPDATE_BLOCK_QUANTITY) {
            ethUsdPrice = uint256(answer) * DECIMAL_NORMALIZER;
            return uint256(answer) * DECIMAL_NORMALIZER;
        }

        return (ethUsdPrice);
    }

    function getLatestEthUsdPrice() public view returns (uint256) {
        // prettier-ignore
        (
            /* uint80 roundId */
            ,
            int256 answer,
            /*uint256 startedAt*/
            ,
            uint256 updatedAt,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();

        // If answer is 0 and update time expired, return the newest value, else return variable value
        if (answer > 0 && updatedAt >= block.timestamp - UPDATE_BLOCK_QUANTITY) {
            return uint256(answer) * DECIMAL_NORMALIZER;
        }

        return ethUsdPrice;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        // If ERC721 
        emit ListedPokeCard(from, tokenId);

        return IERC721Receiver.onERC721Received.selector;
    }

    function listPokeCard(uint256 tokenId, uint256 listingPrice, bool isEthPrice) public isNftOwner(tokenId) {
        // If listing price is 0, revert
        if (listingPrice <= 0) {
            revert PriceCannotBeZero();
        }

        // Transfer safely the token to the contract
        nftCollection.safeTransferFrom(msg.sender, address(this), tokenId);

        // Increase amount of listings
        s_listingAmount++;
        
        // Retrieve pokecard details
        PokeCardCollection.PokemonCard memory pokemonCardFound =
            nftCollection.getGeneratedCardByNftId(msg.sender, tokenId);

        // Create and add to listings a new object
        listings[s_listingAmount] = SaleListing({
            nftId: tokenId,
            isPriceInEth: isEthPrice,
            listingPrice: listingPrice,
            pinataId: pokemonCardFound.pinataId,
            listingBlockNumber: block.number,
            expiryBlock: block.number + INITIAL_LISTING_DURATION_IN_BLOCK,
            listingOwner: msg.sender
        });
    }

    function purchasePokeCard(uint256 listingId, uint256 snorliesAmount)
        public
        payable
        isListingActive(listingId)
        nonReentrant
    {
        // If listing greater than actual listings amount or is 0
          if(listingId == 0 || listingId > s_listingAmount){
            revert IncorrectListingIdProvided();
        }
        // Get the listing element
        SaleListing memory saleListing = listings[listingId];

        // Case for the listing in ETH
        if (saleListing.isPriceInEth) {
            // If message value does not fit the listing price, REVERT
            if (msg.value != saleListing.listingPrice) {
                revert IncorrectAmountProvided(msg.value, saleListing.listingPrice);
            }

            // Get the 2% from the actual price and convert it to eth
            uint256 royalty = (msg.value / 100) * ROYALTY_PERCENTAGE;

// Get reduced value by the royalty and send it to the vendor
            uint256 reducedAmountForVendor = msg.value - royalty;

            (bool isSuccess,) = payable(saleListing.listingOwner).call{value: reducedAmountForVendor}("");

// If not successful, revert
            if (!isSuccess) {
                revert InvalidPayment();
            }
        }
        // CASE FOR PAYMENT IN SNORLIEs
         else {
            // If amount of snorlies provided as *snorliesAmount*
             if (snorlieCoin.balanceOf(msg.sender) < snorliesAmount) {
                revert NotEnoughSnorlies();
            }

            // If Snorlies amount is not enough to be paid the price
            if (snorliesAmount != saleListing.listingPrice) {
                revert IncorrectAmountProvided(msg.value, saleListing.listingPrice);
            }

            // Attempt the transfer to the contract
            (bool success) = snorlieCoin.transferFrom(msg.sender, saleListing.listingOwner, snorliesAmount);

            // If payment not successful, revert
            if (!success) {
                revert InvalidPayment();
            }
        }

        // If the cases have been successfully validated, send the listing token
        nftCollection.safeTransferFrom(address(this), msg.sender, saleListing.nftId);

        // Delete listing and emit the event
        delete listings[listingId];
        emit PokeCardSold(msg.sender, listings[listingId].nftId);
    }

    // Removes listing
    function delistPokemonCard(uint256 listingId) public isOwnerOfListing(listingId) nonReentrant {
        // Retrieve nftId from the listing
        uint256 pokeCardId = listings[listingId].nftId;

        // Approve the token to be sent to the function caller, the approver is contract 
        nftCollection.approve(msg.sender, listings[listingId].nftId);
        // Send the NFT to user  
        nftCollection.safeTransferFrom(address(this), msg.sender, listings[listingId].nftId);

        // delete listing and emit event on delisting
        delete listings[listingId];

        emit PokeCardDelisted(listingId, pokeCardId);
    }
    
    // Prelongs the listing time (existence in the smart-contract), able to be paid in ETH or In-game Token
    function preLongListingTime(uint256 listingId, uint256 amountOfSnorlies, bool paidInEth)
        public
        payable
        isOwnerOfListing(listingId)
        nonReentrant
    {
        // If prelong-fee is paid in ETH 
        if (paidInEth) {
            // Retrieve ethUsdPrice
            uint256 latestEthUsdPrice = updateEthUsdPrice();

            // Convert sent eth-value to usdc value
            uint256 convertedEthToUSDC = (msg.value * 1e18) / latestEthUsdPrice;

            // If there is no option with the amount paid, revert
            if (prelongingOffersInETH[convertedEthToUSDC] == 0) {
                revert NotEnoughEtherToPayFee(msg.value);
            }

            // Increase the listing expriry block
            listings[listingId].expiryBlock += prelongingOffersInETH[convertedEthToUSDC];
        } 
        // If Prelong lisitng time is paid in snorlies
        else {
            // If provided amount is above caller's balance, revert 
            if (snorlieCoin.balanceOf(msg.sender) < amountOfSnorlies) {
                revert NotEnoughSnorlies();
            }

            // If there is no option with provided amountOfSnorlies
            if (prelongingOffersInSnorlies[amountOfSnorlies] == 0) {
                revert NonExistingSnorliePrelongingOffer();
            }

            // Burn Snorlies
            snorlieCoin.burn(amountOfSnorlies);

            // Update expiry block
            listings[listingId].expiryBlock += prelongingOffersInSnorlies[amountOfSnorlies];
        }
        // Emit if any of this case gone without being reverted.
        emit ListingApperancePrelonged(listingId, msg.sender);
    }
}
