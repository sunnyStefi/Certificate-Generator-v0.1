// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
// import {Courses} from "../../src/Courses.sol";
import {Course} from "../../src/Course.sol";
import {Deployment} from "../../script/Deployment.s.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {CreateCourses} from "../../script/Interaction.s.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract CourseTest is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

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
    address public FRANK = makeAddr("frank"); // JUST A GUY

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant EVALUATOR = keccak256("EVALUATOR");

    function setUp() public {
        deployer = new Deployment();
        courseFactory = Course(payable(deployer.run()));
        vm.deal(ALICE, BASE_BALANCE); //ADMIN
        vm.deal(BOB, BASE_BALANCE); //STUDENT PASSED 1
        vm.deal(CARL, BASE_BALANCE); //STUDENT PASSED 2
        vm.deal(DAVID, BASE_BALANCE); //STUDENT FAILED 1
        vm.deal(EVE, BASE_BALANCE); //EVALUATOR
    }

    function test_createCourses() public {
        createCoursesUtils();
        uint256 balanceOfCourse0 = courseFactory.balanceOf(address(ALICE), 0);
        uint256 balanceOfCourse1 = courseFactory.balanceOf(address(ALICE), 1);
        assert(balanceOfCourse0 == 7);
        assert(balanceOfCourse1 == 1);
    }

    function test_createCourses_FailsTooManyPlaces1() public {
        vm.startPrank(ALICE);
        vm.expectRevert(Course.Course_MaxPlacesPerCourseReached.selector);
        courseFactory.createCourse(0, 31, "0x", "", VALUE_001);
        vm.stopPrank();
    }

    function test_createCourses_FailsTooManyPlaces2() public {
        vm.startPrank(ALICE);
        courseFactory.createCourse(0, 30, "0x", "", VALUE_001);
        vm.expectRevert(Course.Course_MaxPlacesPerCourseReached.selector);
        courseFactory.createCourse(0, 2, "0x", "", VALUE_001);
        vm.stopPrank();
    }

    function test_setUpEvaluator() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        address[] memory evaluators = courseFactory.getEvaluators(0);
        assert(evaluators[0] == EVE);
    }

    function test_setUpEvaluator_Fails_CoursesNotCreated(address rand_evaluator, uint256 rand_courseId) public {
        vm.startPrank(ALICE);
        if (rand_evaluator == address(0)) {
            vm.expectRevert(Course.Course_AddressNotValid.selector);
        } else if (courseFactory.getCourseCreator(rand_courseId) == address(0)) {
            vm.expectRevert(Course.Course_CourseNotCreated.selector);
        } else if (rand_courseId >= MAX_UINT) {
            vm.expectRevert(Course.Course_AmountNotValid.selector);
        }
        courseFactory.setUpEvaluator(rand_evaluator, rand_courseId);
        vm.stopPrank();
    }

    //todo fuzz length of courses

    function test_setUpEvaluator_Fails_AlreadyAssignedForThisCourse() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(Course.Course_EvaluatorAlreadyAssignedForThisCourse.selector, EVE));
        courseFactory.setUpEvaluator(EVE, 0);
        vm.stopPrank();
    }

    function test_removeEvaluator() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        removeEvaluatorUtils();
        uint256 actualEvaluators = courseFactory.getEvaluatorsPerCourse(0);
        assertEq(actualEvaluators, 1);
    }

    function test_removedEvaluatorCannotEvaluate() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        removeEvaluatorUtils();
        buyPlacesUtils();
        transferNFTsUtils();
        vm.startPrank(EVE);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, EVE, EVALUATOR)
        );
        courseFactory.evaluate(0, BOB, 8);
        vm.stopPrank();
    }

    function test_setUpEvaluator_Fails_TooManyEvaluatorsForThisCourse() public {
        createCoursesUtils();
        vm.startPrank(ALICE);
        courseFactory.setUpEvaluator(ALICE, 0);
        courseFactory.setUpEvaluator(BOB, 0);
        courseFactory.setUpEvaluator(CARL, 0);
        courseFactory.setUpEvaluator(DAVID, 0);
        courseFactory.setUpEvaluator(EVE, 0);
        assert(courseFactory.getMaxEvaluatorsPerCourse() == courseFactory.getEvaluators(0).length);
        vm.expectRevert(
            abi.encodeWithSelector(
                Course.Course_TooManyEvaluatorsForThisCourse.selector, courseFactory.getMaxEvaluatorsPerCourse()
            )
        );
        courseFactory.setUpEvaluator(FRANK, 0);
        vm.stopPrank();
    }

    function test_setUpEvaluatorFailsNoPermission() public {
        vm.prank(BOB);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, BOB, ADMIN));
        courseFactory.setUpEvaluator(EVE, 0);
    }

    function test_getCourseUri() public {
        createCoursesUtils();
        string memory uri = courseFactory.getCourseUri(0);
        string memory firstCourseUri = "";
        assert(keccak256(abi.encodePacked(uri)) == keccak256(abi.encodePacked(firstCourseUri)));
    }

    function test_oneStudentBuysACourse() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        vm.prank(BOB);
        courseFactory.buyPlace{value: VALUE_001}(0);
        address[] memory students = courseFactory.getCourseToEnrolledStudents(0);
        assert(students[0] == BOB);
        assert(address(courseFactory).balance == VALUE_001);
        assert(courseFactory.getCoursesPerUser(BOB).length == 1);
    }

    function test_allStudentsBuyACourse() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlacesUtils();
        address[] memory students = courseFactory.getCourseToEnrolledStudents(0);
        assert(students[0] == BOB);
        assert(address(courseFactory).balance == VALUE_001 * 3);
        assert(courseFactory.getCoursesPerUser(BOB).length == 1);
    }

    function test_studentOwnsCourseNFT() public {
        assert(courseFactory.balanceOf(BOB, 0) == 0);
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlaceAndTransferNFTUtils();
        assert(courseFactory.balanceOf(ALICE, 0) == 6);
        assert(courseFactory.balanceOf(BOB, 0) == 1);
    }

    function test_studentCannotTransferNFTAround() public {
        assert(courseFactory.balanceOf(BOB, 0) == 0);
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlaceAndTransferNFTUtils();
        vm.startPrank(DAVID);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, DAVID, ADMIN));
        courseFactory.setApprovalForAll(BOB, true);
        vm.stopPrank();
        vm.startPrank(BOB);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, BOB, ADMIN));
        courseFactory.safeTransferFrom(BOB, DAVID, 0, 1, "0x");
        vm.stopPrank();
        assert(courseFactory.balanceOf(BOB, 0) == 1);
        assert(courseFactory.balanceOf(DAVID, 0) == 0);
    }

    function test_evaluations() public {
        evaluationsUtils();
        assert(courseFactory.getCreatedPlacesCounter(0) == 7);
        assert(courseFactory.getPurchasedPlacesCounter(0) == 3);
        (,, uint256 promoted, uint256 failed) = courseFactory.getPromotedStudents(0);
        assert(promoted == 2);
        assert(failed == 1);
        assert(courseFactory.getPassedStudents(0) == 2);
    }

    //evaluation conditions tests here..

    function test_evaluation_Fails_ValidEvaluatorButNotAssignedToCourse() public {
        createCoursesUtils();
        vm.startPrank(ALICE);
        courseFactory.setUpEvaluator(EVE, 0);
        courseFactory.setUpEvaluator(FRANK, 1);
        vm.stopPrank();
        buyPlacesUtils();
        transferNFTsUtils();
        vm.startPrank(FRANK);
        vm.expectRevert(abi.encodeWithSelector(Course.Course_EvaluatorNotAssignedToCourse.selector, 0, FRANK));
        courseFactory.evaluate(0, BOB, 6);
        vm.stopPrank();
    }

    function test_makeCertificates_removeUnsoldCourses() public {
        evaluationsUtils();
        removeUnsoldCoursesUtils();
        assert(courseFactory.getCreatedPlacesCounter(0) == 3);
        assert(courseFactory.getEvaluatedStudents(0) == 3);
    }

    function test_makeCertificates_removeFailedStudentPlaces() public {
        evaluationsUtils();
        removeUnsoldCoursesUtils();
        // assert(courseFactory.getCreatedPlacesCounter(0) == 3);
        // assert(courseFactory.balanceOf(CARL, 0) == 1);
        // vm.prank(ALICE);
        // courseFactory.removePlaces(CARL, 0, 1);
        // assert(courseFactory.balanceOf(CARL, 0) == 0);
    }

    function test_cannotRemoveCoursesForPromotedStudents() public {
        evaluationsUtils();
        makeCertificatesUtils();
        assert(courseFactory.balanceOf(BOB, 0) == 1);
        vm.prank(ALICE);
        courseFactory.removePlaces(BOB, 0, 1);
        assert(courseFactory.balanceOf(BOB, 0) == 0);
    }

    function evaluationsUtils() private {
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlacesUtils();
        transferNFTsUtils();
        evaluateUtils();
    }

    //test failing.. buy course 2 times ecc more later when checking again the contract

    //todo put all integration here: integration it's about more random interaction stuff
    function test_mintNFTandEvaluate() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlacesUtils();
        transferNFTsUtils();
        evaluateUtils();
        assert(courseFactory.getCourseToEvaluateStudents(0).length == 3);
    }

    function test_makeCertificates() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlacesUtils();
        transferNFTsUtils();
        evaluateUtils();
        vm.prank(ALICE);
        courseFactory.makeCertificates(0, "newUri");
        assert(courseFactory.balanceOf(BOB, 0) == 1);
        assert(courseFactory.balanceOf(CARL, 0) == 0);
        assert(courseFactory.balanceOf(DAVID, 0) == 1);
        assert(keccak256(abi.encodePacked(courseFactory.uri(0))) == keccak256(abi.encodePacked("newUri")));
    }

    function test_makeCertificatesFails_CannotMakeTwoCertificatesForSameCourse() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlacesUtils();
        transferNFTsUtils();
        evaluateUtils();
        vm.startPrank(ALICE);
        courseFactory.makeCertificates(0, "newUri");
        vm.expectRevert(Course.Course_CannotCertifyTheCourseTwice.selector);
        courseFactory.makeCertificates(0, "anotherUri");
        vm.stopPrank();
    }

    function test_withdraw() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlacesUtils();
        vm.startPrank(ALICE);
        assert(address(courseFactory).balance == VALUE_001 * 3);
        assert(address(ALICE).balance == BASE_BALANCE);
        courseFactory.withdraw(VALUE_001);
        vm.stopPrank();
        assert(address(courseFactory).balance == VALUE_001 * 2);
        assert(address(ALICE).balance == BASE_BALANCE + VALUE_001);
    }

    function test_withdrawFailsExceededFundsAmount() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlacesUtils();
        vm.startPrank(ALICE);
        assert(address(courseFactory).balance == VALUE_001 * 3);
        assert(address(ALICE).balance == BASE_BALANCE);
        vm.expectRevert(abi.encodeWithSelector(Course.Courses_NotEnoughFunds.selector, VALUE_001 * 4, VALUE_001 * 3));
        courseFactory.withdraw(VALUE_001 * 4);
        vm.stopPrank();
    }

    function createCoursesUtils() private {
        vm.startPrank(ALICE);
        courseFactory.createCourse(0, 7, "0x", "", VALUE_001);
        courseFactory.createCourse(1, 1, "0x", "", VALUE_001);
        vm.stopPrank();
    }

    function setUpEvaluatorUtils() private {
        vm.startPrank(ALICE);
        courseFactory.setUpEvaluator(EVE, 0);
        courseFactory.setUpEvaluator(FRANK, 0);
        vm.stopPrank();
    }

    function removeEvaluatorUtils() private {
        vm.prank(ALICE);
        courseFactory.removeEvaluator(EVE, 0);
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

    function makeCertificatesUtils() private {
        vm.prank(ALICE);
        courseFactory.makeCertificates(0, "newUri");
    }

    function removeUnsoldCoursesUtils() private {
        uint256 unsold = courseFactory.getCreatedPlacesCounter(0) - courseFactory.getPurchasedPlacesCounter(0);
        vm.prank(ALICE);
        courseFactory.removePlaces(ALICE, 0, unsold);
    }

    function removePlaceUtils() private {
        vm.prank(ALICE);
        courseFactory.removePlaces(ALICE, 0, 1);
    }
}
