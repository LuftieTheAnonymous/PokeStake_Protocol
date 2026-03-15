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
    using Math for uint256;

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
    bytes32 private constant MARKETPLACE_MANAGER_ROLE = keccak256("MARKETPLACE_MANAGER_ROLE");
    mapping(uint256 listingId => SaleListing saleListing) private listings;
    mapping(uint256 priceInUSDC => uint256 blockQuantity) private prelongingOffersInETH;
    mapping(uint256 priceInUSDC => uint256 blockQuantity) private prelongingOffersInSnorlies;

    constructor(address snorlieCoinAddress, address pokeCardCollectionAddress, address ethUsdPriceFeed) {
        nftCollection = PokeCardCollection(pokeCardCollectionAddress);
        snorlieCoin = SnorlieCoin(snorlieCoinAddress);
        dataFeed = AggregatorV3Interface(ethUsdPriceFeed);
        (uint256 ethUsdValue) = updateEthUsdPrice();

        prelongingOffersInETH[2e18] = 7200;
        prelongingOffersInETH[5e18] = 50400;
        prelongingOffersInETH[10e17] = 216000;
        prelongingOffersInETH[50e18] = 2628000;

        prelongingOffersInSnorlies[100e18] = 7200;
        prelongingOffersInETH[500e18] = 50400;
        prelongingOffersInETH[750e18] = 216000;
        prelongingOffersInETH[1000e18] = 2628000;

        _grantRole(MARKETPLACE_MANAGER_ROLE, msg.sender);
    }

    modifier isOwnerOfListing(uint256 listingId) {
        if (listings[listingId].listingOwner != msg.sender) {
            revert NotOwnerOfListing(msg.sender);
        }
        _;
    }

    modifier isListingActive(uint256 listingId) {
        if (listings[listingId].expiryBlock > block.number) {
            revert ListingExpired(listings[listingId].expiryBlock, listingId);
        }
        _;
    }

    modifier onlyManager() {
        if (!hasRole(MARKETPLACE_MANAGER_ROLE, msg.sender)) {
            revert NotManager(msg.sender);
        }
        _;
    }

    modifier isAmountInBalance(uint256 amount) {
        if (amount > (address(this)).balance) {
            revert NotEnoughContractBalance();
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
        (bool success,) = payable(msg.sender).call{value: amountToPayout}("");

        if (!success) {
            revert InvalidPayment();
        }

        emit WithdrawnAmount(amountToPayout, msg.sender);
    }

    function grantManagerRole(address newManager) public onlyManager {
        (bool success) = _grantRole(MARKETPLACE_MANAGER_ROLE, newManager);

        if(!success){
            revert UnsuccessfullGrant();
        }
    }

    function revokeManagerRole() public onlyManager {
        (bool success) =_revokeRole(MARKETPLACE_MANAGER_ROLE, msg.sender);

         if(!success){
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

        if (answer > 0 && updatedAt >= block.timestamp - 3600) {
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

        if (answer > 0 && updatedAt >= block.timestamp - 3600) {
            return uint256(answer) * DECIMAL_NORMALIZER;
        }

        return ethUsdPrice;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        emit ListedPokeCard(from, tokenId);

        return IERC721Receiver.onERC721Received.selector;
    }

    function listPokeCard(uint256 tokenId, uint256 listingPrice, bool isEthPrice) public {
        if (listingPrice <= 0) {
            revert PriceCannotBeZero();
        }

        s_listingAmount++;

        PokeCardCollection.PokemonCard memory pokemonCardFound =
            nftCollection.getGeneratedCardByNftId(msg.sender, tokenId);

        listings[s_listingAmount] = SaleListing({
            nftId: tokenId,
            isPriceInEth: isEthPrice,
            listingPrice: listingPrice,
            pinataId: pokemonCardFound.pinataId,
            listingBlockNumber: block.number,
            expiryBlock: block.number + 100800,
            listingOwner: msg.sender
        });
    }

    function purchasePokeCard(uint256 listingId, uint256 snorliesAmount)
        public
        payable
        isListingActive(listingId)
        nonReentrant
    {
        SaleListing memory saleListing = listings[listingId];

        // Case for the listing in ETH
        if (saleListing.isPriceInEth) {
            // If message value does not fit the listing price, REVERT
            if (msg.value != saleListing.listingPrice) {
                revert IncorrectAmountProvided(msg.value, saleListing.listingPrice);
            }

            // Get the 2% from the actual price and convert it to eth
            uint256 royalty = (msg.value / 100) * ROYALTY_PERCENTAGE;

            uint256 reducedAmountForVendor = msg.value - royalty;

            (bool isSuccess,) = payable(saleListing.listingOwner).call{value: reducedAmountForVendor}("");

            if (!isSuccess) {
                revert InvalidPayment();
            }

        } 
        else {
            if (snorliesAmount != saleListing.listingPrice) {
                revert IncorrectAmountProvided(msg.value, saleListing.listingPrice);
            }

            (bool success) = snorlieCoin.transferFrom(msg.sender, saleListing.listingOwner, snorliesAmount);

            if (!success) {
                revert InvalidPayment();
            }
        }
            nftCollection.safeTransferFrom(address(this), msg.sender, saleListing.nftId);

            delete listings[listingId];
            emit PokeCardSold(msg.sender, listings[listingId].nftId);
    }

    function delistPokemonCard(uint256 listingId) public isOwnerOfListing(listingId) nonReentrant {
        uint256 pokeCardId = listings[listingId].nftId;

        nftCollection.safeTransferFrom(address(this), msg.sender, listings[listingId].nftId);

        delete listings[listingId];

        emit PokeCardDelisted(listingId, pokeCardId);
    }

    function preLongListingTime(uint256 listingId, uint256 amountOfSnorlies, bool paidInEth) public payable isOwnerOfListing(listingId) nonReentrant {
      
      if(paidInEth){
        uint256 latestEthUsdPrice = updateEthUsdPrice();

        uint256 convertedEthToUSDC = (msg.value * 1e18) / latestEthUsdPrice;

        if (prelongingOffersInETH[convertedEthToUSDC] == 0) {
            revert NotEnoughEtherToPayFee(msg.value);
        }

        listings[listingId].expiryBlock += prelongingOffersInETH[convertedEthToUSDC];
      }else{

        if(snorlieCoin.balanceOf(msg.sender) < amountOfSnorlies){
            revert NotEnoughSnorlies();
        }

        if(prelongingOffersInSnorlies[amountOfSnorlies] == 0){
             revert NonExistingSnorliePrelongingOffer();
        }

        snorlieCoin.burn(amountOfSnorlies);

        listings[listingId].expiryBlock += prelongingOffersInSnorlies[amountOfSnorlies];
      }
      
        emit ListingApperancePrelonged(listingId, msg.sender);
    }
}
