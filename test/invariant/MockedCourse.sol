// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Course} from "../../src/Course.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract MockedCourse is Test {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public constant MAX_UINT = type(uint256).max;
    uint256 public s_ghost_variable_makeCertificates;
    uint256 public s_ghost_variable_createCourses;
    bytes32 public constant ADMIN = keccak256("ADMIN");
    address private admin;
    Course courseFactory;
    EnumerableSet.UintSet private coursesCreated;
    EnumerableSet.AddressSet private evaluators;
    EnumerableSet.AddressSet private students;
    EnumerableSet.AddressSet private promotedStudents;

    constructor(Course _courseFactory) {
        courseFactory = _courseFactory;
        admin = vm.envAddress("ADDRESS_ALICE_ANVIL");
    }

    //evaluate only if there student has NFT
    //make certificates only if the student has been evaluated
    //buy a place only if the course exist

    modifier validInput(uint256 id, uint256 value) {
        bool enoughPlacesAvailable =
            (courseFactory.getCreatedPlacesCounter(id) + value) < courseFactory.getMaxPlacesPerCourse();
        if (enoughPlacesAvailable) {
            _;
        }
    }

    modifier validInputId(uint256 id) {
        if (id < MAX_UINT && courseFactory.getCourseCreator(id) != address(0)) {
            _;
        }
    }

    modifier validateAddress(address user) {
        if (user != address(0)) {
            _;
        }
    }

    function createCourse(uint256 id, uint256 value, bytes memory data, string memory uri, uint256 fee) public {
        uint256 boundedId = bound(id, 1, UINT256_MAX - 1);
        uint256 boundedValue = bound(value, 1, UINT256_MAX - 1);
        uint256 availablePlaces =
            courseFactory.getMaxPlacesPerCourse() - courseFactory.getCreatedPlacesCounter(boundedId);
        uint256 boundedAvailablePlaces = boundedValue % availablePlaces; //returns a number between 0 and availablePlaces
        if (boundedAvailablePlaces > 0) {
            vm.prank(admin);
            courseFactory.createCourse(boundedId, boundedAvailablePlaces, data, uri, 1 ether);
            s_ghost_variable_createCourses++;
            coursesCreated.add(id);
        }
    }

    // TODO bound input
    // function removePlaces(uint256 fromSeed, uint256 idSeed, uint256 value) public validInput(idSeed, value) {
    //     address from = students.at(fromSeed % students.length());
    //     uint256 id = coursesCreated.at(idSeed % coursesCreated.length());
    //     vm.startPrank(admin);
    //     courseFactory.removePlaces(from, id, value);
    //     vm.stopPrank();
    // }

    // function setUpEvaluator(address evaluator, uint256 id) public validInputId(id) validateAddress(evaluator) {
    //     vm.startPrank(admin);
    //     vm.assume(!courseFactory.getIsEvaluatorsAssignedToCourse(evaluator, id));
    //     courseFactory.setUpEvaluator(evaluator, id);
    //     evaluators.add(evaluator);
    //     vm.stopPrank();
    // }

    // function removeEvaluator(address evaluator, uint256 id)
    //     public
    //     validInputId(id)
    //     validateAddress(evaluator)
    // {
    //     vm.startPrank(admin);
    //     vm.assume(!courseFactory.getIsEvaluatorsAssignedToCourse(evaluator, id));
    //     courseFactory.removeEvaluator(evaluator, id);
    //     vm.stopPrank();
    // }

    // function buyPlace(uint256 id) public validInputId(id) {
    //     vm.assume(courseFactory.getCourseCreator(id) != address(0));
    //     courseFactory.buyPlace(id);
    //     students.add(msg.sender);
    // }

    // function transferPlaceNFT(address student, uint256 id) public validInputId(id) {
    //     vm.startPrank(admin);
    //     vm.assume(courseFactory.isStudentEnrolled(student, id));
    //     courseFactory.transferPlaceNFT(student, id);
    //     vm.stopPrank();
    // }

    // function evaluate(uint256 courseId, address student, uint256 mark) public validInputId(courseId) {
    //     uint256 boundedMark = bound(mark, 1, 10);
    //     vm.assume(courseFactory.getIsEvaluatorsAssignedToCourse(msg.sender, courseId));
    //     vm.assume(courseFactory.balanceOf(student, courseId) == 1);
    //     courseFactory.evaluate(courseId, student, boundedMark);
    //     vm.stopPrank();
    // }

    // function makeCertificates(uint256 courseId, string memory certificateUri) public address(courseFactory) validInputId(courseId) {
    //     vm.startPrank(admin);
    //     vm.assume(!courseFactory.isCourseCertified(courseId));
    //     courseFactory.makeCertificates(courseId, certificateUri);
    //     s_ghost_variable_makeCertificates += 1;
    //     console.log(getGhostMakeCertificates());
    //     vm.stopPrank();
    // }

    // function getGhostMakeCertificates() public view returns (uint256) {
    //     return s_ghost_variable_makeCertificates;
    // }

    function getGhostCreateCourses() public view returns (uint256) {
        return s_ghost_variable_createCourses;
    }
}
