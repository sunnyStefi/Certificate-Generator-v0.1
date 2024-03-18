// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
// import {Dispatcher} from "../src/Dispatcher.sol";
import {Course} from "../src/Course.sol";
// import {Register} from "../src/Register.sol";

contract Deployment is Script {
    uint256 deployerKey;
    uint256 aliceKey;

    function setUp() public {}

    function run() external returns (Course) {
        (, aliceKey) = makeAddrAndKey("alice");
        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY");
        } else {
            deployerKey = aliceKey;
        }
        vm.startBroadcast(deployerKey);
        // Register register = new Register();
        Course university = new Course();
        // Dispatcher dispatcher = new Dispatcher();
        vm.stopBroadcast();
        return (university);
    }
}
