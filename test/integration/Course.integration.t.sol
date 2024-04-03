// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
// import {Courses} from "../../src/Courses.sol";
import {Course} from "../../src/Course.sol";
import {Deployment} from "../../script/Deployment.s.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {CreateCourses} from "../../script/Interaction.s.sol";

contract CourseTest is Test {
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

    function test_multiplePlacesCreationAdd() public {
        createCoursesUtils();
        createCoursesUtils();
        uint256 balanceOfCourse0 = courseFactory.balanceOf(address(ALICE), 0);
        assert(balanceOfCourse0 == 14);
        assert(courseFactory.getCreatedPlacesCounter(1) == 2);
        assert(courseFactory.getCourseCreator(0) == ALICE);
    }

    // function test_createCoursesAndRemovePlaces(uint256 numberOfCourses, uint256 courseId, uint256 value) public {
    //     for (uint256 i = 0; i < numberOfCourses; i++) {
    //         test_createCoursesFuzz(courseId, value);
    //     }
    // }

    function test_multiplePlacesCreationAddRemoveAdd() public {
        createCoursesUtils();
        removePlacesUtils();
        createCoursesUtils();
        assert(courseFactory.getCreatedPlacesCounter(0) == 13);
    }

    function test_removeMorePlacesForACourse() public {
        createCoursesUtils();
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(Course.Course_TooManyPlacesForThisCourse.selector, 7, 8));
        courseFactory.removePlaces(ALICE, 0, 8);
    }

    /**
     * MORE INTEGRATION TESTS EXAMPLE
     * 1. Combine functions in the wrong order and expect a result
     *      e.g. evaluate student before it has received the place NFT ec.
     * 2. Call the same function in a correct order multiple times
     * 3. Mixing Actions point 1 and 2
     * 4. Mixing Users interactions (e.g. same student will purchase differnt courseFactory..)
     */

    /**
     * Fuzz
     */
    function test_createCourseFuzz(uint256 courseId, uint256 value) public {
        vm.startPrank(ALICE);
        uint256 boundedId = bound(courseId, 0, MAX_UINT);
        uint256 boundedValue = bound(value, 1, MAX_UINT);
        if (boundedId >= MAX_UINT || boundedValue >= MAX_UINT) {
            // first revert expected (input)
            vm.expectRevert(Course.Course_AmountNotValid.selector);
            courseFactory.createCourse(boundedId, boundedValue, "0x", "", VALUE_001);
        } else {
            // second revert expected (overflow internal sum)
            if (
                (courseFactory.getCreatedPlacesCounter(boundedId) + boundedValue)
                    > courseFactory.getMaxPlacesPerCourse()
            ) {
                vm.expectRevert(abi.encodeWithSelector(Course.Course_MaxPlacesPerCourseReached.selector));
                courseFactory.createCourse(boundedId, boundedValue, "0x", "", VALUE_001);
            } else {
                // No revert expected
                courseFactory.createCourse(boundedId, boundedValue, "0x", "", VALUE_001);
            }
        }
        vm.stopPrank();
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
