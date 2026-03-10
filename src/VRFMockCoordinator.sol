// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    VRFCoordinatorV2_5Mock
} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract VRFMockCoordinator is VRFCoordinatorV2_5Mock {
    constructor(uint96 _baseFee, uint96 _gasPriceLink, int256 _weiPerUnitLink)
        VRFCoordinatorV2_5Mock(_baseFee, _gasPriceLink, _weiPerUnitLink){}
}
