// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
// import {Certificates} from "../../src/Certificates.sol";
import {Course} from "../../src/Course.sol";
import {Deployment} from "../../script/Deployment.s.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract CourseTest is Test {
    Deployment deployer;
    Course public courses;
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
        courses = deployer.run();
        vm.deal(ALICE, 1 ether);
        vm.deal(BOB, 1 ether);
        vm.deal(CARL, 1 ether);
        vm.deal(DAVID, 1 ether);
    }

    function test_setUpEvaluator() public {
        vm.prank(ALICE);
        courses.setUpEvaluator(EVE);
        assert(courses.getEvaluator(0) == EVE);
    }

    function test_setUpEvaluatorFails() public {
        vm.prank(BOB);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, BOB, ADMIN));
        courses.setUpEvaluator(EVE);
    }

    function test_createCourses() public {
        vm.startPrank(address(ALICE));
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0; //basic math course
        ids[1] = 1; //advanced math course
        uint256[] memory values = new uint256[](2);
        values[0] = 4;
        values[1] = 5;
        string[] memory testUri = new string[](2);
        testUri[0] = "https://ipfs.io/ipfs/Qmd4Z8G6vh4H8Cu4UXT78Vr8pq8WN92SScBntbRe6npvYG/0.json";
        testUri[1] = "https://ipfs.io/ipfs/Qmd4Z8G6vh4H8Cu4UXT78Vr8pq8WN92SScBntbRe6npvYG/1.json";
        uint256[] memory fees = new uint256[](2);
        fees[0] = VALUE_001;
        fees[1] = VALUE_001;
        uint256 numberOfCourses = courses.createCourses(ids, values, "", testUri, fees);
        vm.stopPrank();

        uint256 balanceOfCourse0 = courses.balanceOf(address(ALICE), 0);
        uint256 balanceOfCourse1 = courses.balanceOf(address(ALICE), 1);
        assert(balanceOfCourse0 == 4);
        assert(balanceOfCourse1 == 5);
    }

    function test_getCourseUri() public {
        test_createCourses();
        string memory uri = courses.getCourseUri(0);
        string memory firstCourseUri = "https://ipfs.io/ipfs/Qmd4Z8G6vh4H8Cu4UXT78Vr8pq8WN92SScBntbRe6npvYG/0.json";
        assert(keccak256(abi.encodePacked(uri)) == keccak256(abi.encodePacked(firstCourseUri)));
    }

    function test_studentBuysACourse() public {
        test_createCourses();
        vm.prank(BOB);
        courses.buyCourse{value: VALUE_001}(0);
        address[] memory students = courses.getCourseToEnrolledStudents(0);
        assert(students[0] == BOB);
        assert(address(courses).balance == VALUE_001);
        assert(courses.getCoursesPerUser(BOB).length == 1);
    }

    function test_studentsBuyACourse() public {
        test_createCourses();
        vm.prank(BOB);
        courses.buyCourse{value: VALUE_001}(0);
        vm.prank(CARL);
        courses.buyCourse{value: VALUE_001}(0);
        vm.prank(DAVID);
        courses.buyCourse{value: VALUE_001}(0);
        address[] memory students = courses.getCourseToEnrolledStudents(0);
        assert(students[0] == BOB);
        assert(address(courses).balance == VALUE_001 * 3);
        assert(courses.getCoursesPerUser(BOB).length == 1);
    }

    function test_studentOwnsCourseNFT() public {
        assert(courses.balanceOf(BOB, 0) == 0);
        test_studentBuysACourse();
        vm.prank(ALICE);
        courses.transferCourseNFT(BOB, 0);
        assert(courses.balanceOf(ALICE, 0) == 1);
        assert(courses.balanceOf(BOB, 0) == 1);
    }

    //test if the user cannot transfer it
    function test_hexConversion() public {
        address test = address(0x0B65fbabA12AACFD7c2CE17f9cbcCf82bc7a4236);
        console.log(test);
    }

    //test failing.. buy course 2 times ecc
    //HERE Reason: panic: array out-of-bounds access
    function test_evaluateStudentsAndMintNFT() public {
        // HERE
        test_studentsBuyACourse();
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
        test_evaluateStudentsAndMintNFT();
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
}
