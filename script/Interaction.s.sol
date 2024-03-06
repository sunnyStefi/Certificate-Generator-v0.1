//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {PinkSpace} from "../src/PinkSpace.sol";

contract MintBasicNFT is Script {
    uint256 s_test_value = 0.01 ether;
    string public constant JSON_URI = "QmQhAv2bmYacdEUqh4qJ5XsAZR2MmocopBxrU4Zb8Npsuu";

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("PinkSpace", block.chainid);
        vm.startBroadcast();
        PinkSpace(mostRecentlyDeployed).createToken{value: s_test_value}(JSON_URI, s_test_value);
        vm.stopBroadcast();
    }
}
