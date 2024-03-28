// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
// import {Courses} from "../../src/Courses.sol";
import {Course} from "../../src/Course.sol";
import {Deployment} from "../../script/Deployment.s.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {CreateCourses} from "../../script/Interaction.s.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract CourseTest is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

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
    address public FRANK = makeAddr("frank"); // JUST A GUY

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

    function test_createCourses() public {
        createCoursesUtils();
        uint256 balanceOfCourse0 = courses.balanceOf(address(ALICE), 0);
        uint256 balanceOfCourse1 = courses.balanceOf(address(ALICE), 1);
        assert(balanceOfCourse0 == 7);
        assert(balanceOfCourse1 == 1);
    }

    function test_setUpEvaluator() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        address[] memory evaluators = courses.getEvaluators(0);
        assert(evaluators[0] == EVE);
    }

    function test_setUpEvaluator_Fails_CoursesNotCreated() public {
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(Course.Course_CourseIdDoesNotExist.selector, 0));
        courses.setUpEvaluator(EVE, 0);
        vm.stopPrank();
    }

    function test_setUpEvaluator_Fails_AlreadyAssignedForThisCourse() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(Course.Course_EvaluatorAlreadyAssignedForThisCourse.selector, EVE));
        courses.setUpEvaluator(EVE, 0);
        vm.stopPrank();
    }

    function test_setUpEvaluator_Fails_CourseIdDoesNotExist() public {
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(Course.Course_CourseIdDoesNotExist.selector, 74543));
        courses.setUpEvaluator(EVE, 74543);
        vm.stopPrank();
    }

    function test_removeEvaluator() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        removeEvaluatorUtils();
        uint256 actualEvaluators = courses.getEvaluatorsPerCourse(0);
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
        courses.evaluate(0, BOB, 8);
        vm.stopPrank();
    }

    function test_setUpEvaluator_Fails_TooManyEvaluatorsForThisCourse() public {
        createCoursesUtils();
        vm.startPrank(ALICE);
        courses.setUpEvaluator(ALICE, 0);
        courses.setUpEvaluator(BOB, 0);
        courses.setUpEvaluator(CARL, 0);
        courses.setUpEvaluator(DAVID, 0);
        courses.setUpEvaluator(EVE, 0);
        assert(courses.getMaxEvaluatorsPerCourse() == courses.getEvaluators(0).length);
        vm.expectRevert(
            abi.encodeWithSelector(
                Course.Course_TooManyEvaluatorsForThisCourse.selector, courses.getMaxEvaluatorsPerCourse()
            )
        );
        courses.setUpEvaluator(FRANK, 0);
        vm.stopPrank();
    }

    function test_setUpEvaluatorFailsNoPermission() public {
        vm.prank(BOB);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, BOB, ADMIN));
        courses.setUpEvaluator(EVE, 0);
    }

    function test_getCourseUri() public {
        createCoursesUtils();
        string memory uri = courses.getCourseUri(0);
        string memory firstCourseUri = "https://ipfs.io/ipfs/QmZeczzyz6ow8vNJrP7jBnZPdF7CQYrcUjqQZrgXC6hXMF/0.json";
        assert(keccak256(abi.encodePacked(uri)) == keccak256(abi.encodePacked(firstCourseUri)));
    }

    function test_oneStudentBuysACourse() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        vm.prank(BOB);
        courses.buyPlace{value: VALUE_001}(0);
        address[] memory students = courses.getCourseToEnrolledStudents(0);
        assert(students[0] == BOB);
        assert(address(courses).balance == VALUE_001);
        assert(courses.getCoursesPerUser(BOB).length == 1);
    }

    function test_allStudentsBuyACourse() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlacesUtils();
        address[] memory students = courses.getCourseToEnrolledStudents(0);
        assert(students[0] == BOB);
        assert(address(courses).balance == VALUE_001 * 3);
        assert(courses.getCoursesPerUser(BOB).length == 1);
    }

    function test_studentOwnsCourseNFT() public {
        assert(courses.balanceOf(BOB, 0) == 0);
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlaceAndTransferNFTUtils();
        assert(courses.balanceOf(ALICE, 0) == 6);
        assert(courses.balanceOf(BOB, 0) == 1);
    }

    function test_studentCannotTransferNFTAround() public {
        assert(courses.balanceOf(BOB, 0) == 0);
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlaceAndTransferNFTUtils();
        vm.startPrank(DAVID);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, DAVID, ADMIN));
        courses.setApprovalForAll(BOB, true);
        vm.stopPrank();
        vm.startPrank(BOB);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, BOB, ADMIN));
        courses.safeTransferFrom(BOB, DAVID, 0, 1, "0x");
        vm.stopPrank();
        assert(courses.balanceOf(BOB, 0) == 1);
        assert(courses.balanceOf(DAVID, 0) == 0);
    }

    function test_evaluations() public {
        evaluationsUtils();
        assert(courses.getCreatedPlacesCounter(0) == 7);
        assert(courses.getPurchasedPlacesCounter(0) == 3);
        (,, uint256 promoted, uint256 failed) = courses.getPromotedStudents(0);
        assert(promoted == 2);
        assert(failed == 1);
        assert(courses.getPassedStudents(0) == 2);
    }

    //evaluation conditions tests here..

    function test_evaluation_Fails_ValidEvaluatorButNotAssignedToCourse() public {
        createCoursesUtils();
        vm.startPrank(ALICE);
        courses.setUpEvaluator(EVE, 0);
        courses.setUpEvaluator(FRANK, 1);
        vm.stopPrank();
        buyPlacesUtils();
        transferNFTsUtils();
        vm.startPrank(FRANK);
        vm.expectRevert(abi.encodeWithSelector(Course.Course_EvaluatorNotAssignedToCourse.selector, 0, FRANK));
        courses.evaluate(0, BOB, 6);
        vm.stopPrank();
    }

    function test_makeCourses_removeUnsoldCourses() public {
        evaluationsUtils();
        removeUnsoldCoursesUtils();
        assert(courses.getCreatedPlacesCounter(0) == 3);
        assert(courses.getEvaluatedStudents(0) == 3);
    }

    function test_makeCourses_removeFailedStudentPlaces() public {
        evaluationsUtils();
        removeUnsoldCoursesUtils();
        assert(courses.getCreatedPlacesCounter(0) == 3);
        assert(courses.balanceOf(CARL, 0) == 1);
        vm.prank(ALICE);
        courses.removePlaces(CARL, 0, 1);
        assert(courses.balanceOf(CARL, 0) == 0);
    }

    function test_cannotRemoveCoursesForPromotedStudents() public {
        evaluationsUtils();
        makeCoursesUtils();
        assert(courses.balanceOf(BOB, 0) == 1);
        vm.prank(ALICE);
        courses.removePlaces(BOB, 0, 1);
        assert(courses.balanceOf(BOB, 0) == 0);
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
        assert(courses.getCourseToEvaluateStudents(0).length == 3);
    }

    function test_makeCourses() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlacesUtils();
        transferNFTsUtils();
        evaluateUtils();
        vm.prank(ALICE);
        courses.makeCourses(0, "newUri");
        assert(courses.balanceOf(BOB, 0) == 1);
        assert(courses.balanceOf(CARL, 0) == 0);
        assert(courses.balanceOf(DAVID, 0) == 1);
        assert(keccak256(abi.encodePacked(courses.uri(0))) == keccak256(abi.encodePacked("newUri")));
    }

    function test_withdraw() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlacesUtils();
        vm.startPrank(ALICE);
        assert(address(courses).balance == VALUE_001 * 3);
        assert(address(ALICE).balance == BASE_BALANCE);
        courses.withdraw(VALUE_001);
        vm.stopPrank();
        assert(address(courses).balance == VALUE_001 * 2);
        assert(address(ALICE).balance == BASE_BALANCE + VALUE_001);
    }

    function test_withdrawFailsExceededFundsAmount() public {
        createCoursesUtils();
        setUpEvaluatorUtils();
        buyPlacesUtils();
        vm.startPrank(ALICE);
        assert(address(courses).balance == VALUE_001 * 3);
        assert(address(ALICE).balance == BASE_BALANCE);
        vm.expectRevert(abi.encodeWithSelector(Course.Courses_NotEnoughFunds.selector, VALUE_001 * 4, VALUE_001 * 3));
        courses.withdraw(VALUE_001 * 4);
        vm.stopPrank();
    }

    function createCoursesUtils() private {
        vm.startPrank(ALICE);
        (uint256[] memory ids, uint256[] memory values, string[] memory testUri, uint256[] memory fees) =
            createCourses.setUpCreate();
        courses.createCourses(ids, values, "0x", testUri, fees);
        vm.stopPrank();
    }

    function setUpEvaluatorUtils() private {
        vm.startPrank(ALICE);
        courses.setUpEvaluator(EVE, 0);
        courses.setUpEvaluator(FRANK, 0);
        vm.stopPrank();
    }

    function removeEvaluatorUtils() private {
        vm.prank(ALICE);
        courses.removeEvaluator(EVE, 0);
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

    function makeCoursesUtils() private {
        vm.prank(ALICE);
        courses.makeCourses(0, "newUri");
    }

    function removeUnsoldCoursesUtils() private {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = 0;
        values[0] = courses.getCreatedPlacesCounter(0) - courses.getPurchasedPlacesCounter(0);
        vm.prank(ALICE);
        courses.removePlaces(ids, values);
    }

    function removePlaceUtils() private {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = 0;
        values[0] = 1;
        vm.prank(ALICE);
        courses.removePlaces(ids, values);
    }

    function removePlacesUtils() private {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = 0;
        values[0] = 10;
        vm.prank(ALICE);
        courses.removePlaces(ids, values);
    }
}
