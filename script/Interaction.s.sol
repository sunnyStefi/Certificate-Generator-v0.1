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
        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY_ALICE");
        }
        vm.startBroadcast(deployerKey);
        Course(mostRecentlyDeployed).createCourse(
            0, 7, "", "https://ipfs.io/ipfs/QmZeczzyz6ow8vNJrP7jBnZPdF7CQYrcUjqQZrgXC6hXMF/0.json", VALUE_001
        );
        Course(mostRecentlyDeployed).createCourse(
            1, 1, "", "https://ipfs.io/ipfs/QmZeczzyz6ow8vNJrP7jBnZPdF7CQYrcUjqQZrgXC6hXMF/1.json", VALUE_001
        );
        vm.stopBroadcast();
    }
}

contract SetUpEvaluator is Script {
    uint256 deployerKey;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);

        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY_ALICE");
        }
        vm.startBroadcast(deployerKey);
        address EVE = vm.envAddress("EVE_ADDRESS");
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
            buyPlace(vm.envUint("PRIVATE_KEY_BOB"), mostRecentlyDeployed);
            buyPlace(vm.envUint("PRIVATE_KEY_CARL"), mostRecentlyDeployed);
            buyPlace(vm.envUint("PRIVATE_KEY_DAVID"), mostRecentlyDeployed);
        }
    }

    function buyPlace(uint256 broadcasterKey, address mostRecentlyDeployed) private {
        vm.startBroadcast(broadcasterKey);
        Course(mostRecentlyDeployed).buyPlace{value: VALUE_001}(0);
        vm.stopBroadcast();
    }
}

contract TransferNFT is Script {
    uint256 VALUE_001 = 0.01 ether;
    uint256 deployerKey;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);

        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY_ALICE");
        }
        vm.startBroadcast(deployerKey);
        address BOB = vm.envAddress("BOB_ADDRESS");
        address CARL = vm.envAddress("CARL_ADDRESS");
        address DAVID = vm.envAddress("DAVID_ADDRESS");
        Course(mostRecentlyDeployed).transferPlaceNFT(BOB, 0);
        Course(mostRecentlyDeployed).transferPlaceNFT(CARL, 0);
        Course(mostRecentlyDeployed).transferPlaceNFT(DAVID, 0);
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
        address BOB = vm.envAddress("BOB_ADDRESS");
        address CARL = vm.envAddress("CARL_ADDRESS");
        address DAVID = vm.envAddress("DAVID_ADDRESS");
        Course(mostRecentlyDeployed).evaluate(0, BOB, 6);
        Course(mostRecentlyDeployed).evaluate(0, CARL, 4);
        Course(mostRecentlyDeployed).evaluate(0, DAVID, 8);
        vm.stopBroadcast();
    }
}

contract makeCertificates is Script {
    string newUri = "https://ipfs.io/ipfs/QmcbWTvWMBoRwvJdXUDjuaRXD5w6BKxTeUe3vNZ6Hm4zg6/0_success.json";
    uint256 deployerKey;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Course", block.chainid);

        if (block.chainid == 11155111) {
            deployerKey = vm.envUint("PRIVATE_KEY_ALICE");
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
            deployerKey = vm.envUint("PRIVATE_KEY_ALICE");
        }
        vm.startBroadcast(deployerKey);
        Course(mostRecentlyDeployed).removePlaces(msg.sender, 0, 7);
        Course(mostRecentlyDeployed).removePlaces(msg.sender, 1, 1);
        vm.stopBroadcast();
    }
}
