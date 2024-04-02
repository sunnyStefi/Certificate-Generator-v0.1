// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
// import {Courses} from "../../src/Courses.sol";
import {Course} from "../../src/Course.sol";
import {Deployment} from "../../script/Deployment.s.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {CreateCourses} from "../../script/Interaction.s.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract CourseTest is StdInvariant, Test {
    Deployment deployer;
    Course public courseFactory;
    uint256 VALUE_001 = 0.01 ether;
    uint256 BASE_BALANCE = 1 ether;
    uint256 MAX_UINT = type(uint256).max;
    address public ALICE = makeAddr("alice"); // DEPLOYER
    address public BOB = makeAddr("bob"); //STUDENT 1
    address public CARL = makeAddr("carl"); //STUDENT  2
    address public DAVID = makeAddr("david"); //STUDENT 3
    address public EVE = makeAddr("eve"); // EVALUATOR

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant EVALUATOR = keccak256("EVALUATOR");

    function setUp() public {
        deployer = new Deployment();
        courseFactory = deployer.run();
        vm.deal(ALICE, BASE_BALANCE); //ADMIN
        vm.deal(BOB, BASE_BALANCE); //STUDENT PASSED 1
        vm.deal(CARL, BASE_BALANCE); //STUDENT PASSED 2
        vm.deal(DAVID, BASE_BALANCE); //STUDENT FAILED 1
        vm.deal(EVE, BASE_BALANCE); //EVALUATOR
    }

   function invariant_evaluate() public {
     
   }

    /**
     * Utils
     */
    function createCoursesUtils() private {
        vm.startPrank(ALICE);
        courseFactory.createCourse(0, 7, "0x", "", VALUE_001);
        courseFactory.createCourse(1, 1, "0x", "", VALUE_001);
        vm.stopPrank();
    }

    function setUpEvaluatorUtils() private {
        vm.prank(ALICE);
        courseFactory.setUpEvaluator(EVE, 0);
    }

    function buyPlacesUtils() private {
        vm.prank(BOB);
        courseFactory.buyPlace{value: VALUE_001}(0);
        vm.prank(CARL);
        courseFactory.buyPlace{value: VALUE_001}(0);
        vm.prank(DAVID);
        courseFactory.buyPlace{value: VALUE_001}(0);
    }

    function buyPlaceAndTransferNFTUtils() private {
        vm.prank(BOB);
        courseFactory.buyPlace{value: VALUE_001}(0);
        vm.prank(ALICE);
        courseFactory.transferPlaceNFT(BOB, 0);
    }

    function transferNFTsUtils() private {
        vm.startPrank(ALICE);
        courseFactory.transferPlaceNFT(BOB, 0);
        courseFactory.transferPlaceNFT(CARL, 0);
        courseFactory.transferPlaceNFT(DAVID, 0);
        vm.stopPrank();
    }

    function evaluateUtils() private {
        vm.startPrank(EVE);
        courseFactory.evaluate(0, BOB, 6);
        courseFactory.evaluate(0, CARL, 4);
        courseFactory.evaluate(0, DAVID, 8);
        vm.stopPrank();
    }

    function removePlacesUtils() private {
        vm.prank(ALICE);
        courseFactory.removePlaces(ALICE, 0, 1);
    }
}
