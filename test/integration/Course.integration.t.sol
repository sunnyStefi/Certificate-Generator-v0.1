// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
// import {Certificates} from "../../src/Certificates.sol";
import {Course} from "../../src/Course.sol";
import {Deployment} from "../../script/Deployment.s.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {CreateCourses} from "../../script/Interaction.s.sol";

contract CourseTest is Test {
    Deployment deployer;
    Course public courses;
    CreateCourses public createCourses;
    uint256 VALUE_001 = 0.01 ether;
    address public ALICE = makeAddr("alice"); // DEPLOYER
    address public BOB = makeAddr("bob"); //STUDENT 1
    address public CARL = makeAddr("carl"); //STUDENT  2
    address public DAVID = makeAddr("david"); //STUDENT 3
    address public EVE = makeAddr("eve"); // EVALUATOR

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant EVALUATOR = keccak256("EVALUATOR");

    function setUp() public {
        deployer = new Deployment();
        (courses, createCourses) = deployer.run();
        vm.deal(ALICE, 1 ether); //ADMIN
        vm.deal(BOB, 1 ether); //STUDENT PASSED 1
        vm.deal(CARL, 1 ether); //STUDENT FAILED 1
        vm.deal(DAVID, 1 ether); //STUDENT PASSED 2
        vm.deal(EVE, 1 ether); //EVALUATOR
    }

    function createCoursesUtils() private {
        vm.startPrank(ALICE);
        (uint256[] memory ids, uint256[] memory values, string[] memory testUri, uint256[] memory fees) =
            createCourses.setUpCreate();
        courses.createCourses(ids, values, "0x", testUri, fees);
        vm.stopPrank();
    }

    function setUpEvaluatorUtils() private {
        vm.prank(ALICE);
        courses.setUpEvaluator(EVE, 0);
    }

    function buyPlacesUtils() private {
        vm.prank(BOB);
        courses.buyPlace{value: VALUE_001}(0);
        vm.prank(CARL);
        courses.buyPlace{value: VALUE_001}(0);
        vm.prank(DAVID);
        courses.buyPlace{value: VALUE_001}(0);
    }

    function buyPlaceAndTransferNFTUtils() private {
        vm.prank(BOB);
        courses.buyPlace{value: VALUE_001}(0);
        vm.prank(ALICE);
        courses.transferPlaceNFT(BOB, 0);
    }

    function transferNFTsUtils() private {
        vm.startPrank(ALICE);
        courses.transferPlaceNFT(BOB, 0);
        courses.transferPlaceNFT(CARL, 0);
        courses.transferPlaceNFT(DAVID, 0);
        vm.stopPrank();
    }

    function evaluateUtils() private {
        vm.startPrank(EVE);
        courses.evaluate(0, BOB, 6);
        courses.evaluate(0, CARL, 4);
        courses.evaluate(0, DAVID, 8);
        vm.stopPrank();
    }
}
