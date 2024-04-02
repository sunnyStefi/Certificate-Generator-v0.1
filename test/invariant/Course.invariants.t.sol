// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {MockedCourse} from "./MockedCourse.sol";
import {Course} from "../../src/Course.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

//Statefull
contract CourseTest is StdInvariant, Test {
    Course public courseFactory;
    MockedCourse public handler;

    function setUp() public {
        courseFactory = new Course();
        handler = new MockedCourse(courseFactory);
        targetContract(address(handler));
    }

    function invariant_CourseCreation_CoursesLessEqualThanCertificates() external {
        uint256 courses = courseFactory.getCoursesCounter();
        uint256 certificates = courseFactory.getCertificatesCounter();
        assertLe(courses, certificates);
    }

    function invariant_CourseCreation_PlacesCreatedPerCourseAreLessThanMAX() external {
        uint256 MAX_PLACES = courseFactory.getMaxPlacesPerCourse();
        uint256 coursesCounter = courseFactory.getCoursesCounter();
        uint256 placesPurchased = courseFactory.getCertificatesCounter();
        assertLe(placesPurchased, MAX_PLACES * coursesCounter);
    }
}
