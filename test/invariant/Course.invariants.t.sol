// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {MockedCourse} from "./MockedCourse.sol";
import {Course} from "../../src/Course.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

//Statefull
contract CourseTestInvariants is StdInvariant, Test {
    Course public courseFactory;
    MockedCourse public mockedCourse;
    address public ALICE = vm.envAddress("ADDRESS_ALICE_ANVIL"); // DEPLOYER
    ERC1967Proxy proxy;

    function setUp() public {
        vm.startPrank(ALICE);
        courseFactory = new Course();
        bytes memory initializerData = abi.encodeWithSelector(Course.initialize.selector, ALICE, ALICE);
        proxy = new ERC1967Proxy(address(courseFactory), initializerData);
        mockedCourse = new MockedCourse(Course(payable(proxy)));
        targetContract(address(mockedCourse));
        vm.stopPrank();
    }

    //todo finish mocked course functions
    function invariant_CourseCreation_CoursesLessEqualThanCertificates() public view {
        uint256 places = Course(payable(proxy)).getAllPlaces();
        uint256 certificates = Course(payable(proxy)).getCertificatesCounter();
        console.log("Places created: ", places);
        console.log("Certificates created: ", certificates);
        assertLe(certificates, places);
    }

    function invariant_CourseCreation_TotalPlacesCreatedAreLessEThanAllowed() public view {
        uint256 MAX_PLACES = Course(payable(proxy)).getMaxPlacesPerCourse();
        uint256 coursesCounter = Course(payable(proxy)).getCoursesCounter();
        uint256 placesPurchased = Course(payable(proxy)).getAllPlaces();
        console.log("Courses created called: ", mockedCourse.getGhostCreateCourses());
        console.log("Places created: ", placesPurchased);
        console.log("Total places: ", MAX_PLACES * coursesCounter);
        assertLe(placesPurchased, MAX_PLACES * coursesCounter);
    }

    function invariant_gettersDoNotRevert() public view {
        Course(payable(proxy)).getCertificatesCounter();
        //..
    }
}
