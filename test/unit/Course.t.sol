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
        vm.deal(CARL, 1 ether); //STUDENT PASSED 2
        vm.deal(DAVID, 1 ether); //STUDENT FAILED 1
        vm.deal(EVE, 1 ether); //EVALUATOR
    }

    function test_createCourses() public {
        createCoursesUtils();
        uint256 balanceOfCourse0 = courses.balanceOf(address(ALICE), 0);
        uint256 balanceOfCourse1 = courses.balanceOf(address(ALICE), 1);
        assert(balanceOfCourse0 == 7);
        assert(balanceOfCourse1 == 1);
    }

    function test_setUpEvaluator() public {
        vm.prank(ALICE);
        courses.setUpEvaluator(EVE);
        assert(courses.getEvaluator(0) == EVE);
    }

    function test_setUpEvaluatorFailsNoPermission() public {
        vm.prank(BOB);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, BOB, ADMIN));
        courses.setUpEvaluator(EVE);
    }

    function test_getCourseUri() public {
        createCoursesUtils();
        string memory uri = courses.getCourseUri(0);
        string memory firstCourseUri = "https://ipfs.io/ipfs/Qmd4Z8G6vh4H8Cu4UXT78Vr8pq8WN92SScBntbRe6npvYG/0.json";
        assert(keccak256(abi.encodePacked(uri)) == keccak256(abi.encodePacked(firstCourseUri)));
    }

    function test_oneStudentBuysACourse() public {
        createCoursesUtils();
        vm.prank(BOB);
        courses.buyCourse{value: VALUE_001}(0);
        address[] memory students = courses.getCourseToEnrolledStudents(0);
        assert(students[0] == BOB);
        assert(address(courses).balance == VALUE_001);
        assert(courses.getCoursesPerUser(BOB).length == 1);
    }

    function test_allStudentsBuyACourse() public {
        createCoursesUtils();
        buyCoursesUtils();
        address[] memory students = courses.getCourseToEnrolledStudents(0);
        assert(students[0] == BOB);
        assert(address(courses).balance == VALUE_001 * 3);
        assert(courses.getCoursesPerUser(BOB).length == 1);
    }

    function test_studentOwnsCourseNFT() public {
        assert(courses.balanceOf(BOB, 0) == 0);
        createCoursesUtils();
        buyCourseAndTransferNFTUtils();
        assert(courses.balanceOf(ALICE, 0) == 6);
        assert(courses.balanceOf(BOB, 0) == 1);
    }

    function test_studentCannotTransferNFTAround() public {
        assert(courses.balanceOf(BOB, 0) == 0);
        createCoursesUtils();
        buyCourseAndTransferNFTUtils();
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

        // vm.prank(BOB);
        // courses.safeTransferFrom(BOB, DAVID, 0, 1, "0x");
        // assert(courses.balanceOf(DAVID, 0) == 0);
        // assert(courses.balanceOf(BOB, 0) == 1);
    }

    //test failing.. buy course 2 times ecc more later when checking again the contract

    function test_mintNFTandEvaluate() public {
        // HERE
        test_allStudentsBuyACourse();
        test_setUpEvaluator();
        vm.startPrank(ALICE);
        courses.transferCourseNFT(BOB, 0);
        courses.transferCourseNFT(CARL, 0);
        courses.transferCourseNFT(DAVID, 0);
        vm.stopPrank();
        vm.startPrank(address(EVE));
        bool evaluation1 = courses.evaluate(0, BOB, 6);
        bool evaluation2 = courses.evaluate(0, CARL, 4);
        bool evaluation3 = courses.evaluate(0, DAVID, 8);
        vm.stopPrank();
        assert(courses.getCourseToEvaluateStudents(0).length == 3);
    }

    function test_makeCertificates() public {
        test_mintNFTandEvaluate();
        vm.prank(ALICE);
        courses.makeCertificates(0, "asd");
        assert(courses.balanceOf(CARL, 0) == 0);
        assert(courses.balanceOf(DAVID, 0) == 1);
    }

    // function test_

    // function test_evaluateStudentFailsIfNoEvaluator() public {
    //     test_setUpEvaluator();
    //     test_studentOwnsCourseNFT();
    //     vm.prank(address(ALICE));
    //     vm.expectRevert(
    //         abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, ALICE, EVALUATOR)
    //     );
    //     bool success = courses.evaluate(0, BOB, 6);
    //     assert(success);
    // }

    function createCoursesUtils() private {
        vm.startPrank(ALICE);
        (uint256[] memory ids, uint256[] memory values, string[] memory testUri, uint256[] memory fees) =
            createCourses.setUpCreate();
        courses.createCourses(ids, values, "0x", testUri, fees);
        vm.stopPrank();
    }

    function buyCoursesUtils() private {
        vm.prank(BOB);
        courses.buyCourse{value: VALUE_001}(0);
        vm.prank(CARL);
        courses.buyCourse{value: VALUE_001}(0);
        vm.prank(DAVID);
        courses.buyCourse{value: VALUE_001}(0);
    }

    function buyCourseAndTransferNFTUtils() private {
        vm.prank(BOB);
        courses.buyCourse{value: VALUE_001}(0);
        vm.prank(ALICE);
        courses.transferCourseNFT(BOB, 0);
    }
}
