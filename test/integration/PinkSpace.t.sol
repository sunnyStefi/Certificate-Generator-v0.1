// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PinkSpace} from "../../src/PinkSpace.sol";
import {PinkSpaceDeploy} from "../../script/PinkSpaceDeploy.s.sol";

contract CounterTest is Test {
    PinkSpaceDeploy deployer;
    PinkSpace public pinkSpace;
    uint256 s_test_value = 0.01 ether;
    address public ALICE = makeAddr("alice");
    address public BOB = makeAddr("bob");
    string public constant JSON_URI = "QmQhAv2bmYacdEUqh4qJ5XsAZR2MmocopBxrU4Zb8Npsuu";

    function setUp() public {
        deployer = new PinkSpaceDeploy();
        pinkSpace = deployer.run();
        vm.deal(ALICE, 1 ether);
        vm.deal(BOB, 1 ether);
    }

    function test_name() public view {
        string memory expectedName = "PinkSpace";
        string memory actualName = pinkSpace.name();
        bytes32 encodedExpectedName = keccak256(abi.encodePacked(expectedName));
        bytes32 encodedActualName = keccak256(abi.encodePacked(actualName));
        assert(encodedExpectedName == encodedActualName);
    }

    function test_createToken() public {
        createToken(ALICE);
        assert(pinkSpace.balanceOf(address(pinkSpace)) == 1);
    }

    function test_getInfoListedToken() public {
        createToken(ALICE);
        PinkSpace.InfoListedToken memory info = pinkSpace.getListedForTokenId(1);
        assertEq(info.seller, address(ALICE));
    }

    function test_getAll() public {
        createToken(ALICE);
        createToken(BOB);
        PinkSpace.InfoListedToken[] memory allInfos = pinkSpace.getAll();
        assertEq(allInfos[1].seller, address(BOB));
    }

    function test_getUsersToken() public {
        createToken(ALICE);
        createToken(ALICE);
        vm.startPrank(ALICE);
        PinkSpace.InfoListedToken[] memory userInfos = pinkSpace.getUsersToken();
        assertEq(userInfos.length, 2);
        vm.stopPrank();
    }

    function test_sellToken() public {
        createToken(ALICE);
        
    }

    function createToken(address user) private returns (uint256) {
        vm.prank(user);
        return pinkSpace.createToken{value: s_test_value}(JSON_URI, s_test_value);
    }
}
