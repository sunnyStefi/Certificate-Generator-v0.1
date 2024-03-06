// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PinkSpace} from "../src/PinkSpace.sol";

contract PinkSpaceDeploy is Script {
    function setUp() public {}

    //deploy
    function run() external returns (PinkSpace) {
        vm.startBroadcast();
        PinkSpace ps = new PinkSpace();
        vm.stopBroadcast();
        return ps;
    }
}
