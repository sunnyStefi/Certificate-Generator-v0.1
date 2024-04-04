// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Course} from "../src/Course.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract Deployment is Script {
    address addressAdmin;
    uint256 privateKeyAdmin;

    function setUp() public {
        if (block.chainid == 11155111) {
            addressAdmin = vm.envAddress("ADDRESS_ALICE");
            privateKeyAdmin = vm.envUint("PRIVATE_KEY_ALICE");
        }
        if (block.chainid == 31337) {
            addressAdmin = vm.envAddress("ADDRESS_ALICE_ANVIL");
            privateKeyAdmin = vm.envUint("PRIVATE_KEY_ALICE_ANVIL");
        }
    }

    function run() external returns (address) {
        console.log(privateKeyAdmin);
        vm.startBroadcast(privateKeyAdmin);
        Course coursesFactory = new Course();
        bytes memory initializerData = abi.encodeWithSelector(Course.initialize.selector, addressAdmin, addressAdmin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(coursesFactory), initializerData);
        vm.stopBroadcast();
        return (address(proxy));
    }
}

contract Upgrade is Script {
    address addressAdmin;
    uint256 privateKeyAdmin;

    function setUp() public {
        if (block.chainid == 11155111) {
            addressAdmin = vm.envAddress("ADDRESS_ALICE");
            privateKeyAdmin = vm.envUint("PRIVATE_KEY_ALICE");
        }
        if (block.chainid == 31337) {
            addressAdmin = vm.envAddress("ADDRESS_ALICE_ANVIL");
            privateKeyAdmin = vm.envUint("PRIVATE_KEY_ALICE_ANVIL");
        }
    }

    function run() external returns (address) {
        vm.startBroadcast(privateKeyAdmin);
        address mostRecentDeployedProxy = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", block.chainid);
        Course newCourse = new Course(); // It will be CourseV2 when upgrading
        Course originalCourse = Course(payable(mostRecentDeployedProxy));
        bytes memory initializerData = abi.encodeWithSelector(Course.initialize.selector, addressAdmin, addressAdmin); //this can be changed
        originalCourse.upgradeToAndCall(address(newCourse), initializerData);
        vm.stopBroadcast();
        return address(originalCourse);
    }
}
