// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Course} from "../../src/Course.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract MockedCourse is Test {
    uint256 public constant MAX_UINT = type(uint256).max;
    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant EVALUATOR = keccak256("EVALUATOR");
    address admin;
    Course courseFactory;

    constructor(Course _courseFactory) {
        courseFactory = _courseFactory;
        admin = msg.sender;
    }

    //evaluate only if there student has NFT
    //make certificates only if the student has been evaluated
    //buy a place only if the course exist

    modifier validInput(uint256 id, uint256 value) {
        bool validValue = (
            value < MAX_UINT
                && (courseFactory.getCreatedPlacesCounter(id) + value) < courseFactory.getMaxPlacesPerCourse()
        );
        if (id < MAX_UINT && validValue && (admin == msg.sender)) {
            _;
        }
    }

    modifier validInputId(uint256 id) {
        if (id < MAX_UINT && courseFactory.getCourseCreator(id) != address(0)) {
            _;
        }
    }

    modifier onlyAdmin() {
        if (admin == msg.sender) {
            _;
        }
    }

    modifier validateAddress(address user) {
        if (user != address(0)) {
            _;
        }
    }

    function createCourse(uint256 id, uint256 value, bytes memory data, string memory uri, uint256 fee)
        public
        validInput(id, value)
    {
        courseFactory.createCourse(id, value, data, uri, fee);
    }

    function removePlaces(address from, uint256 id, uint256 value) public validInput(id, value) {
        if (from != address(0)) {
            courseFactory.removePlaces(from, id, value);
        }
    }

    function setUpEvaluator(address evaluator, uint256 id)
        public
        validInputId(id)
        validateAddress(evaluator)
        onlyAdmin
    {
        vm.assume(!courseFactory.getIsEvaluatorsAssignedToCourse(evaluator, id));
        courseFactory.setUpEvaluator(evaluator, id);
    }

    function removeEvaluator(address evaluator, uint256 id)
        public
        validInputId(id)
        validateAddress(evaluator)
        onlyAdmin
    {
        vm.assume(!courseFactory.getIsEvaluatorsAssignedToCourse(evaluator, id));
        courseFactory.removeEvaluator(evaluator, id);
    }

    function buyPlace(uint256 courseId) public {
        if (courseFactory.getCourseCreator(courseId) != address(0)) {
            courseFactory.buyPlace(courseId);
        }
    }

    //tod.. more fuzzing here, specify detailed conditions
}
