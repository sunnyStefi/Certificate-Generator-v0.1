// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {MockedCourse} from "./MockedCourse.sol";
import {Course} from "../../src/Course.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

//Statefull
contract CourseTestInvariants is StdInvariant, Test {
    Course public courseFactory;
    MockedCourse public mockedCourse;
    address admin = makeAddr("ALICE");

    function setUp() public {
        vm.startPrank(admin);
        courseFactory = new Course();
        mockedCourse = new MockedCourse(courseFactory);
        targetContract(address(mockedCourse));
        vm.stopPrank();
    }

    //todo finish mocked course functions
    function invariant_CourseCreation_CoursesLessEqualThanCertificates() public {
        uint256 places = courseFactory.getAllPlaces();
        uint256 certificates = courseFactory.getCertificatesCounter();
        console.log("Places created: ", places);
        console.log("Certificates created: ", certificates);
        assertLe(certificates, places);
    }

    function invariant_CourseCreation_TotalPlacesCreatedAreLessEThanAllowed() public {
        uint256 MAX_PLACES = courseFactory.getMaxPlacesPerCourse();
        uint256 coursesCounter = courseFactory.getCoursesCounter();
        uint256 placesPurchased = courseFactory.getAllPlaces();
        console.log("Courses created called: ", mockedCourse.getGhostCreateCourses());
        console.log("Places created: ", placesPurchased);
        console.log("Total places: ", MAX_PLACES * coursesCounter);
        assertLe(placesPurchased, MAX_PLACES * coursesCounter);
    }

    function invariant_gettersCannotRevert() public view {
        courseFactory.getCertificatesCounter();
        //..
    }
}
