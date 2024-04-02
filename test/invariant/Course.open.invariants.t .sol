// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Course} from "../../src/Course.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

//Statefull
contract CourseTest is StdInvariant, Test {
    Course public courseFactory;

    function setUp() public {
        courseFactory = new Course();
        // targetContract(address(courseFactory)); //it will call AccessControl functions too..
    }

    // function invariant_open_CourseCreation_CoursesLessEqualThanCertificates() external {
    //     uint256 courses = courseFactory.getCoursesCounter();
    //     uint256 certificates = courseFactory.getCertificatesCounter();
    //     assertLe(courses, certificates);
    // }
}
