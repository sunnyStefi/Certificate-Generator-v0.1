//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Course} from "../src/Course.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract CreateCourses is Script {
    uint256 VALUE_001 = 0.01 ether;
    uint256 deployerKey;
    uint256 aliceKey;
    uint256[] ids = new uint256[](2);
    uint256[] values = new uint256[](2);
    string[] testUri = new string[](2);
    uint256[] fees = new uint256[](2);

    function run() external {
        (, aliceKey) = makeAddrAndKey("alice");
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);
        setUpCreate();
        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY");
        }
        vm.startBroadcast(deployerKey);
        Course(mostRecentlyDeployed).createCourses(ids, values, "", testUri, fees);
        vm.stopBroadcast();
    }

    function setUpCreate() public returns (uint256[] memory, uint256[] memory, string[] memory, uint256[] memory) {
        ids[0] = 0; //basic math course
        ids[1] = 1; //advanced math course
        values[0] = 7;
        values[1] = 1;
        testUri[0] = "https://ipfs.io/ipfs/QmZeczzyz6ow8vNJrP7jBnZPdF7CQYrcUjqQZrgXC6hXMF/0.json";
        testUri[1] = "https://ipfs.io/ipfs/QmZeczzyz6ow8vNJrP7jBnZPdF7CQYrcUjqQZrgXC6hXMF/1.json";
        fees[0] = VALUE_001;
        fees[1] = VALUE_001;
        return (ids, values, testUri, fees);
    }
}

contract SetUpEvaluator is Script {
    uint256 deployerKey;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);

        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY");
        }
        vm.startBroadcast(deployerKey);
        address EVE = address(0x34Fc21D79de671e5e05Ad7156A663Af8C3702E17);
        Course(mostRecentlyDeployed).setUpEvaluator(EVE, 0);
        vm.stopBroadcast();
    }
}

contract BuyCourses is Script {
    uint256 VALUE_001 = 0.01 ether;
    uint256 deployerKey;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);

        if (block.chainid == 11155111) {
            buyCourse(vm.envUint("PRIVATE_KEY_BOB"), mostRecentlyDeployed);
            buyCourse(vm.envUint("PRIVATE_KEY_CARL"), mostRecentlyDeployed);
            buyCourse(vm.envUint("PRIVATE_KEY_DAVID"), mostRecentlyDeployed);
        }
    }

    function buyCourse(uint256 broadcasterKey, address mostRecentlyDeployed) private {
        vm.startBroadcast(broadcasterKey);
        Course(mostRecentlyDeployed).buyCourse{value: VALUE_001}(0);
        vm.stopBroadcast();
    }
}

contract TransferNFT is Script {
    uint256 VALUE_001 = 0.01 ether;
    uint256 deployerKey;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);

        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY");
        }
        vm.startBroadcast(deployerKey);
        address BOB = address(0xf015f6a767167b3f21e03D93b475c26D32DCc399);
        address CARL = address(0x0B65fbabA12AACFD7c2CE17f9cbcCf82bc7a4236);
        address DAVID = address(0xF4D3a3461708F7D6DE47Da423851e3a2807eDaAD);
        Course(mostRecentlyDeployed).transferCourseNFT(BOB, 0);
        Course(mostRecentlyDeployed).transferCourseNFT(CARL, 0);
        Course(mostRecentlyDeployed).transferCourseNFT(DAVID, 0);
        vm.stopBroadcast();
    }
}

contract Evaluate is Script {
    uint256 VALUE_001 = 0.01 ether;
    uint256 deployerKey;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);

        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY_EVE");
        }
        vm.startBroadcast(deployerKey);
        address BOB = address(0xf015f6a767167b3f21e03D93b475c26D32DCc399);
        address CARL = address(0x0B65fbabA12AACFD7c2CE17f9cbcCf82bc7a4236);
        address DAVID = address(0xF4D3a3461708F7D6DE47Da423851e3a2807eDaAD);
        Course(mostRecentlyDeployed).evaluate(0, BOB, 6);
        Course(mostRecentlyDeployed).evaluate(0, CARL, 4);
        Course(mostRecentlyDeployed).evaluate(0, DAVID, 8);
        vm.stopBroadcast();
    }
}

contract MakeCertificates is Script {
    string newUri = "https://ipfs.io/ipfs/QmcbWTvWMBoRwvJdXUDjuaRXD5w6BKxTeUe3vNZ6Hm4zg6/0_success.json";
    uint256 deployerKey;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);

        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY");
        }
        vm.startBroadcast(deployerKey);
        Course(mostRecentlyDeployed).makeCertificates(0, newUri);
        vm.stopBroadcast();
    }
}

contract RemoveAll is Script {
    uint256 deployerKey;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);

        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY");
        }
        vm.startBroadcast(deployerKey);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        ids[0] = 0; //basic math course
        ids[1] = 1; //advanced math course
        values[0] = 2;
        values[1] = 0;
        Course(mostRecentlyDeployed).removeCourses(ids, values);
        vm.stopBroadcast();
    }
}
