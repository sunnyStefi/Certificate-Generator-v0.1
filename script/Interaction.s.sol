//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Course} from "../src/Course.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract createCourses is Script {
    uint256 VALUE_001 = 0.01 ether;
    uint256 deployerKey;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);

        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY");
        }
        vm.startBroadcast(deployerKey);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0; //basic math course
        ids[1] = 1; //advanced math course
        uint256[] memory values = new uint256[](2);
        values[0] = 2;
        values[1] = 5;
        string[] memory testUri = new string[](2);
        testUri[0] = "https://ipfs.io/ipfs/Qmd4Z8G6vh4H8Cu4UXT78Vr8pq8WN92SScBntbRe6npvYG/0.json";
        testUri[1] = "https://ipfs.io/ipfs/Qmd4Z8G6vh4H8Cu4UXT78Vr8pq8WN92SScBntbRe6npvYG/1.json";
        uint256[] memory fees = new uint256[](2);
        fees[0] = VALUE_001;
        fees[1] = VALUE_001;
        Course(mostRecentlyDeployed).createCourses(ids, values, "", testUri, fees);
        vm.stopBroadcast();
    }
}

contract setUpEvaluator is Script {
    uint256 deployerKey;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);

        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY");
        }
        vm.startBroadcast(deployerKey);
        address BOB = address(bytes20(bytes("0xf015f6a767167b3f21e03D93b475c26D32DCc399")));
        Course(mostRecentlyDeployed).setUpEvaluator(BOB);
        vm.stopBroadcast();
    }
}

contract buyCourse is Script {
    uint256 VALUE_001 = 0.01 ether;
    uint256 deployerKey;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);

        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY_CARL");
        }
        vm.startBroadcast(deployerKey);
        address CARL = address(0x0B65fbabA12AACFD7c2CE17f9cbcCf82bc7a4236);
        Course(mostRecentlyDeployed).buyCourse{value: VALUE_001}(0);
        vm.stopBroadcast();
    }
}

contract transferNFT is Script {
    uint256 VALUE_001 = 0.01 ether;
    uint256 deployerKey;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);

        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY");
        }
        vm.startBroadcast(deployerKey);
        address CARL = address(0x0B65fbabA12AACFD7c2CE17f9cbcCf82bc7a4236);
        Course(mostRecentlyDeployed).transferCourseNFT(CARL, 0);
        vm.stopBroadcast();
    }
}

// evaluate carl and make certificates