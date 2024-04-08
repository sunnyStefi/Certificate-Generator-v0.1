//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;
//named-imports

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {CourseFactoryCourseCreator} from "./CourseFactoryCourseCreator.sol";
import {CourseFactorySecretary} from "./CourseFactorySecretary.sol";

/**
 * @notice This contract govern the creation, transfer and management of certificates.
 */
contract CourseFactoryUserLearningCenter is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant EVALUATOR = keccak256("EVALUATOR");
    bytes32 public constant STUDENT = keccak256("STUDENT"); //todo assign
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    CourseFactoryCourseCreator public courseCreator;
    uint256 public MAX_UINT = type(uint256).max;
    uint256 public MAX_PLACES_PER_COURSE;
    address s_defaultAdmin;

    error CourseFactoryUserLearningCenter_TotalLessonsForThisCourseCannotBeZero();
    error Course_AddressNotValid();
    error Course_AmountNotValid();
    error Course_CourseNotCreated();
    error Courses_DefaultRolesAssigned();
    error Course_StudentCannotBuyMoreThanOnePlace();
    error Course_MaxPlacesPerCourseReached();
    error Course_BuyCourse_NotEnoughEthToBuyCourse();

    mapping(address => mapping(uint256 => CoursePurchased)) private s_studentToPurchasedCourses;

    uint256[49] __gap;

    struct CoursePurchased {
        uint256 bookmarksTimestamp;
        uint256 bookmarksLesson;
        uint256 bookmarksCourse;
        uint256 courseCompletionPercentage; //%
        EnumerableSet.UintSet lessonsCompleted;
    }

    modifier validateAddress(address user) {
        if (user == address(0)) {
            revert Course_AddressNotValid();
        }
        _;
    }

    modifier validateAmount(uint256 amount) {
        if (amount >= MAX_UINT) {
            revert Course_AmountNotValid();
        }
        _;
    }

    modifier courseExists(uint256 courseId) {
        if (courseCreator.getCourseCreator(courseId) == address(0)) {
            revert Course_CourseNotCreated();
        }
        if (courseId >= MAX_UINT) {
            revert Course_AmountNotValid();
        }

        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address upgrader, address _courseCreator) public initializer {
        __ERC1155_init("");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setRoleAdmin(ADMIN, ADMIN);
        _setRoleAdmin(EVALUATOR, ADMIN);

        _grantRole(ADMIN, _msgSender());
        _grantRole(ADMIN, address(this));
        _grantRole(ADMIN, defaultAdmin);

        _grantRole(UPGRADER_ROLE, upgrader);

        s_defaultAdmin = defaultAdmin;
        courseCreator = CourseFactoryCourseCreator(_courseCreator);
        MAX_PLACES_PER_COURSE = courseCreator.getMaxPlacesPerCourse();

        emit Courses_DefaultRolesAssigned(defaultAdmin, upgrader);
    }

    function buyPlace(uint256 courseId) public payable validateAmount(courseId) courseExists(courseId) {
        if (courseCreator.getAllPlacesPurchased(courseId) >= MAX_PLACES_PER_COURSE) {
            revert Course_MaxPlacesPerCourseReached();
        }
        if (msg.value < courseCreator.getPlaceFee(courseId)) {
            revert Course_BuyCourse_NotEnoughEthToBuyCourse(courseCreator.getPlaceFee(), msg.value);
        }
        if (courseCreator.getCourseEnrolledStudents(courseId).contains(_msgSender())) {
            revert Course_StudentCannotBuyMoreThanOnePlace();
        }
        if (address(this.balance) > msg.value) {
            CourseFactorySecretary(address).transfer(msg.value);
        }
        courseCreator.incrementPlacesPurchased(courseId);
        courseCreator.addEnrolledStudents(courseId, _msgSender());
    }

    function setLessonCompleted(uint256 courseId, uint256 lessonId, address student) public {
        if (courseCreator.getLessonsCounter() == 0) {
            revert CourseFactoryUserLearningCenter_TotalLessonsForThisCourseCannotBeZero();
        }
        s_studentToPurchasedCourses[student][courseId].lessonsCompleted.add(lessonId);
        uint256 lessonsCompleted = s_studentToPurchasedCourses[student][courseId].lessonsCompleted.length();
        uint256 totalLessonCounter = courseCreator.getLessonsCounter();
        uint256 actualPercentage = (lessonsCompleted * 100 / totalLessonCounter);
        s_studentToPurchasedCourses[student][courseId].courseCompletionPercentage = actualPercentage;
    }

    function setCourseCompleted(uint256 courseId, address student) public {}

    function getCurrentLessonId(address student, uint256 courseId) public returns (uint256) {
        return s_bookmarks[student][courseId][0];
    }

    function setBookmarkOnQuit(address student, uint256 courseId, uint256 lessonId, uint256 timestamp) public {
        s_bookmarks[student][courseId][lessonId] = timestamp;
    }

    function getBookmarkTimestamp(address student, uint256 courseId, uint256 lessonId) public view returns (uint256) {
        return s_bookmarks[student][courseId][lessonId];
    }

    /**
     * Getters
     */
    function getCourseToEnrolledStudents(uint256 courseId) public view returns (address[] memory) {
        return s_courses[courseId].enrolledStudents.values();
    }

    function getCoursesPerUser(address user) public view returns (uint256[] memory) {}

    function getPromotedStudents(uint256 courseId)
        public
        view
        returns (address[] memory, address[] memory, uint256, uint256)
    {
        uint256 countPromoted = 0;
        uint256 countFailed = 0;
        uint256 evaluatedStudentsPerCourse = s_courseToEvaluatedStudents[courseId].length;
        address[] memory promoted = new address[](evaluatedStudentsPerCourse);
        address[] memory failed = new address[](evaluatedStudentsPerCourse);
        for (uint256 i = 0; i < evaluatedStudentsPerCourse; i++) {
            if (s_courseToEvaluatedStudents[courseId][i].mark >= 6) {
                promoted[countPromoted] = s_courseToEvaluatedStudents[courseId][i].student;
                countPromoted++;
            }
            if (s_courseToEvaluatedStudents[courseId][i].mark < 6) {
                failed[countFailed] = s_courseToEvaluatedStudents[courseId][i].student;
                countFailed++;
            }
        }

        assembly {
            mstore(promoted, countPromoted)
            mstore(failed, countFailed)
        }

        return (promoted, failed, countPromoted, countFailed);
    }

    function getCoursesCounter() public view returns (uint256) {
        return s_coursesTypeCounter.length();
    }

    function getCreatedPlacesCounter(uint256 courseId) public view returns (uint256) {
        return s_courses[courseId].placeNumber;
    }

    function getPurchasedPlacesCounter(uint256 courseId) public view returns (uint256) {
        return s_courses[courseId].placesPurchased;
    }

    function getEvaluatedStudents(uint256 courseId) public view returns (uint256) {
        return s_courseToEvaluatedStudents[courseId].length;
    }

    function getMaxEvaluatorsPerCourse() public view returns (uint256) {
        return MAX_EVALUATORS;
    }

    function getMaxPlacesPerCourse() public view returns (uint256) {
        return MAX_PLACES_PER_COURSE;
    }

    function getEvaluatorsPerCourse(uint256 courseId) public view returns (uint256) {
        return s_courses[courseId].evaluators.length();
    }

    function getIsEvaluatorsAssignedToCourse(address evaluator, uint256 courseId) public view returns (bool) {
        return s_courses[courseId].evaluators.contains(evaluator);
    }

    function getCourseCreator(uint256 courseId) public view returns (address) {
        return s_courses[courseId].creator;
    }

    function getCourseUri(uint256 courseId) public view returns (string memory) {
        return s_courses[courseId].uri;
    }

    function getPassedStudents(uint256 courseId) public view returns (uint256) {
        return s_courses[courseId].passedStudents;
    }

    function getCertificatesCounter() public view returns (uint256) {
        return s_certificatesCounter;
    }

    function getAllPlacesPurchased() public view returns (uint256) {
        return s_placesPurchasedCounter;
    }

    function getAllPlaces() public view returns (uint256) {
        return s_placesAllCounter;
    }

    function getVersion() external pure returns (uint256) {
        return 1;
    }

    function isStudentEnrolled(address student, uint256 courseId) public view returns (bool) {
        return s_courses[courseId].enrolledStudents.contains(student);
    }

    function isCourseCertified(uint256 courseId) public view returns (bool) {
        return s_courses[courseId].certified;
    }

    function getDefaultAdmin() public view returns (address) {
        return s_defaultAdmin;
    }
    /**
     * Setters
     */

    function setUri(string memory uri) public onlyRole(ADMIN) {
        _setURI(uri);
    }

    function _setURI(string memory newuri) internal override {
        super._setURI(newuri);
    }

    function setMaxEvaluatorsAmount(uint256 newAmount) public {
        if (newAmount == 0) {
            revert Course_SetMaxAmountCannotBeZero(newAmount);
        }
        MAX_EVALUATORS = newAmount;
    }

    function setMaxPlacesAmount(uint256 newAmount) public {
        if (newAmount == 0) {
            revert Course_SetMaxAmountCannotBeZero(newAmount);
        }
        MAX_PLACES_PER_COURSE = newAmount;
    }

    function setCourseUri(uint256 courseId, string memory uri) public onlyRole(ADMIN) {
        s_courses[courseId].uri = uri;
    }

    /**
     * Overrides
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data)
        public
        override
        onlyRole(ADMIN)
    {
        super.safeTransferFrom(from, to, id, value, data);
    }
    // OPENSEA

    function uri(uint256 _tokenid) public view override returns (string memory) {
        return s_courses[_tokenid].uri;
    }

    function setApprovalForAll(address operator, bool approved) public override onlyRole(ADMIN) {
        super.setApprovalForAll(operator, approved);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC1155Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    // PROXY

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
