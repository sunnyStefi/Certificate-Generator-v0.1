// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
// import {Courses} from "../../src/Courses.sol";
import {Course} from "../../src/Course.sol";
import {Deployment} from "../../script/Deployment.s.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {CreateCourses} from "../../script/Interaction.s.sol";

contract CourseTest is Test {
    Deployment deployer;
    Course public courses;
    CreateCourses public createCourses;
    uint256 VALUE_001 = 0.01 ether;
    uint256 BASE_BALANCE = 1 ether;
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
        vm.deal(ALICE, BASE_BALANCE); //ADMIN
        vm.deal(BOB, BASE_BALANCE); //STUDENT PASSED 1
        vm.deal(CARL, BASE_BALANCE); //STUDENT PASSED 2
        vm.deal(DAVID, BASE_BALANCE); //STUDENT FAILED 1
        vm.deal(EVE, BASE_BALANCE); //EVALUATOR
    }

    function test_multiplePlacesCreationAdd() public {
        createCoursesUtils();
        createCoursesUtils();
        uint256 balanceOfCourse0 = courses.balanceOf(address(ALICE), 0);
        assert(balanceOfCourse0 == 14);
        assert(courses.getCreatedPlacesCounter(1) == 2);
        assert(courses.getCourseCreator(0) == ALICE);
    }

    function test_multiplePlacesCreationAddRemoveAdd() public {
        createCoursesUtils();
        removePlacesUtils();
        createCoursesUtils();
        assert(courses.getCreatedPlacesCounter(0) == 13);
    }

    function test_removeMorePlacesForACourse() public {
        createCoursesUtils();
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = 0;
        values[0] = 8;
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(Course.Course_TooManyPlacesForThisCourse.selector, 7, 8));
        courses.removePlaces(ids, values);
    }

    /**
     * MORE INTEGRATION TESTS EXAMPLE
     * 1. Combine functions in the wrong order and expect a result
     *      e.g. evaluate student before it has received the place NFT ec.
     * 2. Call the same function in a correct order multiple times
     * 3. Mixing Actions point 1 and 2
     * 4. Mixing Users interactions (e.g. same student will purchase differnt courses..)
     */
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

    function removePlacesUtils() private {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = 0;
        values[0] = 1;
        vm.prank(ALICE);
        courses.removePlaces(ids, values);
    }
}
