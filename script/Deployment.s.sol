// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
// import {Dispatcher} from "../src/Dispatcher.sol";
import {Course} from "../src/Course.sol";
import {CreateCourses} from "./Interaction.s.sol";

contract Deployment is Script {
    uint256 deployerKey;
    uint256 aliceKey;

    function setUp() public {}

    function run() external returns (Course) {
        (, aliceKey) = makeAddrAndKey("alice");
        if (block.chainid == 11155111) {
            vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        }
        if (block.chainid == 31337) {
            vm.startBroadcast(aliceKey); //Deploy utils contract for testing
        }
        Course university = new Course();
        vm.stopBroadcast();
        return (university);
    }
}
