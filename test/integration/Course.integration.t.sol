// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Course} from "../../src/Course.sol";
import {CourseV2} from "../../src/CourseV2.sol";
import {Deployment} from "../../script/Deployment.s.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {CreateCourses} from "../../script/Interaction.s.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Deployment, Upgrade} from "../../script/Deployment.s.sol";

contract CourseTest is Test {
    string[] emptyArray;
    ERC1967Proxy proxy;
    Course public courseFactory;
    uint256 VALUE_001 = 0.01 ether;
    uint256 BASE_BALANCE = 1 ether;
    uint256 MAX_UINT = type(uint256).max;
    address public ALICE = vm.envAddress("ADDRESS_ALICE_ANVIL"); // DEPLOYER
    address public BOB = vm.envAddress("ADDRESS_BOB_ANVIL"); //STUDENT 1
    address public CARL = vm.envAddress("ADDRESS_CARL_ANVIL"); //STUDENT  2
    address public DAVID = vm.envAddress("ADDRESS_DAVID_ANVIL"); //STUDENT 3
    address public EVE = vm.envAddress("ADDRESS_EVE_ANVIL"); // EVALUATOR

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant EVALUATOR = keccak256("EVALUATOR");

    function setUp() public {
        vm.startPrank(ALICE);
        courseFactory = new Course();
        bytes memory initializerData = abi.encodeWithSelector(Course.initialize.selector, ALICE, ALICE);
        proxy = new ERC1967Proxy(address(courseFactory), initializerData);
        vm.deal(ALICE, BASE_BALANCE); //ADMIN
        vm.deal(BOB, BASE_BALANCE); //STUDENT PASSED 1
        vm.deal(CARL, BASE_BALANCE); //STUDENT PASSED 2
        vm.deal(DAVID, BASE_BALANCE); //STUDENT FAILED 1
        vm.deal(EVE, BASE_BALANCE); //EVALUATOR
        vm.stopPrank();
    }

    function test_multiplePlacesCreationAddd() public {
        createCoursesUtils();
        createCoursesUtils();
        uint256 balanceOfCourse0 = Course(payable(proxy)).balanceOf(ALICE, 0);
        assert(balanceOfCourse0 == 14);
        assert(Course(payable(proxy)).getCreatedPlacesCounter(1) == 2);
        assert(Course(payable(proxy)).getCourseCreator(0) == ALICE);
    }

    function test_multiplePlacesCreationAddRemoveAdd() public {
        createCoursesUtils();
        removePlacesUtils();
        createCoursesUtils();
        assert(Course(payable(proxy)).getCreatedPlacesCounter(0) == 13);
    }

    function test_removeMorePlacesForACourse() public {
        createCoursesUtils();
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(Course.Course_TooManyPlacesForThisCourse.selector, 7, 8));
        Course(payable(proxy)).removePlaces(ALICE, 0, 8);
    }

    /**
     * MORE INTEGRATION TESTS EXAMPLE
     * 1. Combine functions in the wrong order and expect a result
     *      e.g. evaluate student before it has received the place NFT ec.
     * 2. Call the same function in a correct order multiple times
     * 3. Mixing Actions point 1 and 2
     * 4. Mixing Users interactions (e.g. same student will purchase differnt Course(payable(proxy))..)
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
            Course(payable(proxy)).createCourse(boundedId, boundedValue, "0x", "", VALUE_001, emptyArray);
        } else {
            // second revert expected (overflow internal sum)
            if (
                (Course(payable(proxy)).getCreatedPlacesCounter(boundedId) + boundedValue)
                    > Course(payable(proxy)).getMaxPlacesPerCourse()
            ) {
                vm.expectRevert(abi.encodeWithSelector(Course.Course_MaxPlacesPerCourseReached.selector));
                Course(payable(proxy)).createCourse(boundedId, boundedValue, "0x", "", VALUE_001, emptyArray);
            } else {
                // No revert expected
                Course(payable(proxy)).createCourse(boundedId, boundedValue, "0x", "", VALUE_001, emptyArray);
            }
        }
        vm.stopPrank();
    }

    function test_courseUpgrade() public {
        vm.startPrank(ALICE);
        assertEq(Course(payable(proxy)).getVersion(), 1);
        bytes memory initializerDataV2 =
            abi.encodeWithSelector(CourseV2.initializeV2.selector, address(ALICE), address(ALICE));
        CourseV2 courseV2 = new CourseV2();
        Course(payable(proxy)).upgradeToAndCall(address(courseV2), initializerDataV2);
        assertEq(CourseV2(payable(proxy)).getVersion(), 2);
        vm.stopPrank();
    }

    /**
     * Utils
     */
    function createCoursesUtils() private {
        vm.startPrank(ALICE);
        Course(payable(proxy)).createCourse(0, 7, "0x", "", VALUE_001, emptyArray);
        Course(payable(proxy)).createCourse(1, 1, "0x", "", VALUE_001, emptyArray);
        vm.stopPrank();
    }

    function setUpEvaluatorUtils() private {
        vm.prank(ALICE);
        Course(payable(proxy)).setUpEvaluator(EVE, 0);
    }

    function buyPlacesUtils() private {
        vm.prank(BOB);
        Course(payable(proxy)).buyPlace{value: VALUE_001}(0);
        vm.prank(CARL);
        Course(payable(proxy)).buyPlace{value: VALUE_001}(0);
        vm.prank(DAVID);
        Course(payable(proxy)).buyPlace{value: VALUE_001}(0);
    }

    function buyPlaceAndTransferNFTUtils() private {
        vm.prank(BOB);
        Course(payable(proxy)).buyPlace{value: VALUE_001}(0);
        vm.prank(ALICE);
        Course(payable(proxy)).transferPlaceNFT(BOB, 0);
    }

    function transferNFTsUtils() private {
        vm.startPrank(ALICE);
        Course(payable(proxy)).transferPlaceNFT(BOB, 0);
        Course(payable(proxy)).transferPlaceNFT(CARL, 0);
        Course(payable(proxy)).transferPlaceNFT(DAVID, 0);
        vm.stopPrank();
    }

    function evaluateUtils() private {
        vm.startPrank(EVE);
        Course(payable(proxy)).evaluate(0, BOB, 6);
        Course(payable(proxy)).evaluate(0, CARL, 4);
        Course(payable(proxy)).evaluate(0, DAVID, 8);
        vm.stopPrank();
    }

    function removePlacesUtils() private {
        vm.prank(ALICE);
        Course(payable(proxy)).removePlaces(ALICE, 0, 1);
    }
}
