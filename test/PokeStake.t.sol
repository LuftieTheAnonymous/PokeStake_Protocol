// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.27;

import {Test} from "../lib/forge-std/src/Test.sol";

import {SnorlieCoin} from "../src/PokeCoin.sol";


contract PokeStakeTest is Test {

SnorlieCoin snorlieCoin;

function setUp() public {
    snorlieCoin = new SnorlieCoin(address(this), address(this));
}


function testDefaultMinting() public {
    snorlieCoin.burn()
}



}