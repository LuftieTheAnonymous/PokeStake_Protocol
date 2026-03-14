// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {IERC721Receiver} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

import {AggregatorV3Interface} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {SnorlieCoin} from "../PokeCoin.sol";

import {PokeCardCollection} from "../PokeCardCollection.sol";

contract MarketPlace is IERC721Receiver, ReentrancyGuard{

    error IncorrectAmountProvided(uint256 providedAmount, uint256 expectedAmount);

    error NotEnoughEtherToPayFee(uint256 transferredAmount, uint256 expecteAmount);

    error PriceCannotBeZero();

    error InvalidPayment();

    event ListedPokeCard(address seller, uint256 tokenId);

    event PokeCardSold(address puchasedBy, uint256 blockNumber);

    struct SaleListing {
        address listingOwner;
        uint256 nftId;
        string pinataId;
        uint256 listingBlockNumber;
        uint256 amount;
        bool isPriceInEth;
    }

    SnorlieCoin snorlieCoin;
    PokeCardCollection nftCollection;

    AggregatorV3Interface internal dataFeed;

    uint256 private s_listingAmount;

    uint256 private ethUsdPrice;

    uint256 private constant FEE_FOR_LISTING = 5e18;

    uint256 private constant ROYALTY_PERCENTAGE = 2;

    mapping(uint256 listingId => SaleListing saleListing) private listings;


constructor(address snorlieCoinAddress, address pokeCardCollectionAddress, address ethUsdPriceFeed){
nftCollection = PokeCardCollection(pokeCardCollectionAddress);
snorlieCoin = SnorlieCoin(snorlieCoinAddress);
dataFeed = AggregatorV3Interface(ethUsdPriceFeed);
}


  function updateEthUsdPrice() public returns (uint256) {
    // prettier-ignore
    (
      /* uint80 roundId */
      ,
      int256 answer,
      /*uint256 startedAt*/
      ,
      uint256 updatedAt
      ,
      /*uint80 answeredInRound*/
    ) = dataFeed.latestRoundData();

  if (answer > 0 && updatedAt >= block.timestamp - 3600) {
    ethUsdPrice =uint256(answer);
    return uint256(answer);
    }

    return ethUsdPrice;
  }

  function getLatestAnswer() public view returns (uint256) {
    // prettier-ignore
    (
      /* uint80 roundId */
      ,
      int256 answer,
      /*uint256 startedAt*/
      ,
      uint256 updatedAt
      ,
      /*uint80 answeredInRound*/
    ) = dataFeed.latestRoundData();

  if (answer > 0 && updatedAt >= block.timestamp - 3600) {
    return uint256(answer);
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


    function listPokeCard(uint256 tokenId, uint256 amountToPay, bool isEthPrice) public payable {

        if(amountToPay <= 0){
            revert PriceCannotBeZero();
        }


        uint256 convertedEthToUSDC = (msg.value * 1e18) / ethUsdPrice;

        if(convertedEthToUSDC != FEE_FOR_LISTING){
            revert NotEnoughEtherToPayFee(msg.value, convertedEthToUSDC);
        }

        s_listingAmount++;
        
        PokeCardCollection.PokemonCard memory pokemonCardFound = nftCollection.getGeneratedCardByNftId(msg.sender, tokenId);

        
        listings[s_listingAmount] = SaleListing({
            nftId:tokenId,
            isPriceInEth:isEthPrice,
            amount:amountToPay,
            pinataId: pokemonCardFound.pinataId,
            listingBlockNumber:block.number,
            listingOwner: msg.sender
        });
    }

    function purchasePokeCard(uint256 listingId, uint256 snorliesAmount) public nonReentrant payable{
        SaleListing memory saleListing = listings[listingId];

        if(saleListing.isPriceInEth){

            if(msg.value != saleListing.amount){
                revert IncorrectAmountProvided(msg.value, saleListing.amount);
            }

            uint256 convertedEthToUSDC = (msg.value * 1e18) / ethUsdPrice;

            uint256 royalty = (convertedEthToUSDC / 100) * ROYALTY_PERCENTAGE;

            uint256 reducedAmountForVendor = msg.value - royalty;

            (bool isSuccess,) = payable(saleListing.listingOwner).call{value:reducedAmountForVendor}("");

            if(!isSuccess){
             revert InvalidPayment();
            }

            nftCollection.safeTransferFrom(address(this), msg.sender, saleListing.nftId);

            delete listings[listingId];          

            emit PokeCardSold(msg.sender, listings[listingId].nftId);
        }
        else{
             if(snorliesAmount != saleListing.amount){
                revert IncorrectAmountProvided(msg.value, saleListing.amount);
            }

            (bool success) = snorlieCoin.transferFrom(msg.sender, saleListing.listingOwner,snorliesAmount);

            if(!success){
                revert InvalidPayment();
            }

            nftCollection.safeTransferFrom(address(this), msg.sender, saleListing.nftId);

            delete listings[listingId];          

            emit PokeCardSold(msg.sender, listings[listingId].nftId);            
        }
    }

    

}