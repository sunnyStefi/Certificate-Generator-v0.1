// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import {Test, console} from "forge-std/Test.sol";
// import {Certificates} from "../../src/Certificates.sol";
// import {Deployment} from "../../script/Deployment.s.sol";

// contract DispatcherTest is Test {
//     Deployment deployer;
//     Dispatcher public Dispatcher;
//     uint256 s_test_value = 0.01 ether;
//     address public ALICE = makeAddr("alice");
//     address public BOB = makeAddr("bob");
//     string public constant JSON_URI = "QmQhAv2bmYacdEUqh4qJ5XsAZR2MmocopBxrU4Zb8Npsuu";

//     function setUp() public {
//         deployer = new DispatcherDeploy();
//         Dispatcher = deployer.run();
//         vm.deal(ALICE, 1 ether);
//         vm.deal(BOB, 1 ether);
//     }

//     function test_name() public view {
//         string memory expectedName = "Dispatcher";
//         string memory actualName = Dispatcher.name();
//         bytes32 encodedExpectedName = keccak256(abi.encodePacked(expectedName));
//         bytes32 encodedActualName = keccak256(abi.encodePacked(actualName));
//         assert(encodedExpectedName == encodedActualName);
//     }

//     function test_createToken() public {
//         createToken(ALICE);
//         assert(Dispatcher.balanceOf(address(Dispatcher)) == 1);
//     }

//     function test_getInfoListedToken() public {
//         createToken(ALICE);
//         Dispatcher.InfoListedToken memory info = Dispatcher.getListedForTokenId(1);
//         assertEq(info.seller, address(ALICE));
//     }

//     function test_getAll() public {
//         createToken(ALICE);
//         createToken(BOB);
//         Dispatcher.InfoListedToken[] memory allInfos = Dispatcher.getAll();
//         assertEq(allInfos[1].seller, address(BOB));
//     }

//     function test_getUsersToken() public {
//         createToken(ALICE);
//         createToken(ALICE);
//         vm.startPrank(ALICE);
//         Dispatcher.InfoListedToken[] memory userInfos = Dispatcher.getUsersToken();
//         assertEq(userInfos.length, 2);
//         vm.stopPrank();
//     }

//     function test_sellToken() public {
//         createToken(ALICE);
//     }

//     function createToken(address user) private returns (uint256) {
//         vm.prank(user);
//         return Dispatcher.createToken{value: s_test_value}(JSON_URI, s_test_value);
//     }
// }
