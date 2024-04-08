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

/**
 * @notice This contract govern the creation, transfer and management of certificates.
 */
contract CourseFactoryCourseCreator is Initializable, ERC1155Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant EVALUATOR = keccak256("EVALUATOR");
    bytes32 public constant STUDENT = keccak256("STUDENT"); //todo assign
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    event Courses_CourseCreated();
    event Courses_CoursesRemoved(uint256 indexed courseId);
    event Courses_EvaluationCompleted(uint256 indexed courseId, address indexed student, uint256 indexed mark);
    event Courses_Withdrawal(address sender, uint256 amount);
    event Courses_DefaultRolesAssigned(address admin, address upgrader);

    error Course_IllegalMark(uint256 mark);
    error Courses_NoCourseIsRegisteredForTheUser(address user);
    error Courses_CourseNotRegisteredForTheUser(uint256 courseId, address student);
    error Courses_WithdrawalFailed();
    error Course_AddressNotValid();
    error Course_BuyCourse_NotEnoughEthToBuyCourse(uint256 fee, uint256 value);
    error Course_EvaluatorAlreadyAssignedForThisCourse(address evaluator);
    error Course_TooManyEvaluatorsForThisCourse(uint256 maxEvaluatorsAmount);
    error Course_SetMaxAmountCannotBeZero(uint256 newAmount);
    error Course_EvaluatorNotAssignedToCourse(uint256 course, address evaluator);
    error Course_CourseIdDoesNotExist(uint256 courseId);
    error Course_EvaluatorNotAssignedForThisCourse(address evaluator);
    error Course_StudentCannotBeEvaluator(address student);
    error Course_DoesNotHaveExactlyOnePlaceNFT(address student, uint256 balance);
    error Course_StudentNotEnrolled(address student);
    error Course_StudentAlreadyEvaluated(address student);
    error Courses_NotEnoughFunds(uint256 amount, uint256 balance);
    error Course_TooManyPlacesForThisCourse(uint256 actualPlaces, uint256 desiredPlaces);
    error Course_AmountNotValid();
    error Course_MaxPlacesPerCourseReached();
    error Course_StudentCannotBuyMoreThanOnePlace();
    error Course_CannotCertifyTheCourseTwice();
    error Course_CourseNotCreated();
    error Course_EvaluatorCannotBeStudent();
    error Course_MaxNumberOfCoursesReached();
    error CourseFactoryCourseCreator_LessonUrisMustBeMoreThanZero();

    uint256 public constant BASE_COURSE_FEE = 0.01 ether;
    uint256 public constant MAX_UINT = type(uint256).max;
    string public constant JSON = ".json";
    string public constant ID_JSON = "/{id}.json";
    string public constant PROTOCOL = "https://ipfs.io/ipfs/";
    string public constant URI_PINATA = "QmZeczzyz6ow8vNJrP7jBnZPdF7CQYrcUjqQZrgXC6hXMF";

    EnumerableSet.UintSet s_coursesTypeCounter;
    uint256 private s_placesAllCounter;
    uint256 private s_placesPurchasedCounter;
    uint256 private s_certificatesCounter;
    uint256 private s_lessonsCounter;
    uint256 private MAX_EVALUATORS;
    uint256 private MAX_PLACES_PER_COURSE;
    uint256 public COURSES_NUMBER;

    address private s_defaultAdmin;

    mapping(uint256 => CourseStruct) private s_courses;

    uint256[49] __gap;

    struct CourseStruct {
        uint256 placeFee;
        uint256 totalPlacesAvailable;
        uint256 placesPurchased;
        uint256 passedStudents;
        address creator;
        EnumerableSet.AddressSet enrolledStudents;
        string uri;
        string[] lessonsUris;

    }

    struct EvaluatedStudent {
        uint256 mark;
        uint256 date;
        address student;
        address evaluator;
    }

    modifier validateMark(uint256 mark) {
        if (mark < 1 || mark > 10) {
            revert Course_IllegalMark(mark);
        }
        _;
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
        if (s_courses[courseId].creator == address(0)) {
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

    function initialize(address defaultAdmin, address upgrader) public initializer {
        __ERC1155_init("");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setRoleAdmin(ADMIN, ADMIN);
        _setRoleAdmin(EVALUATOR, ADMIN);

        _grantRole(ADMIN, _msgSender());
        _grantRole(ADMIN, address(this));
        _grantRole(ADMIN, defaultAdmin);

        _grantRole(UPGRADER_ROLE, upgrader);

        MAX_EVALUATORS = 5;
        MAX_PLACES_PER_COURSE = 30;
        COURSES_NUMBER = 10;
        s_defaultAdmin = defaultAdmin;

        emit Courses_DefaultRolesAssigned(defaultAdmin, upgrader);
    }

    function createCourse(
        uint256 id,
        uint256 value,
        bytes memory data,
        string memory uri,
        uint256 fee,
        string[] memory lessonsUris
    ) public onlyRole(ADMIN) validateAmount(id) validateAmount(value) returns (uint256) {
        if (s_coursesTypeCounter.length() > COURSES_NUMBER) {
            revert Course_MaxNumberOfCoursesReached();
        }
        setCoursePlacesData(id, value, uri, fee, lessonsUris);
        _mint(_msgSender(), id, value, data);
        setApprovalForAll(_msgSender(), true);
        emit Courses_CourseCreated();
        return id;
    }

    function removePlaces(address from, uint256 id, uint256 value) public onlyRole(ADMIN) validateAmount(value) {
        removePlaceData(id, value);
        _burn(from, id, value);
        emit Courses_CoursesRemoved(value);
    }

    /**
     * Storage Utils
     */
    function setCoursePlacesData(
        uint256 courseId,
        uint256 value,
        string memory courseUri,
        uint256 fee,
        string[] memory lessonsUris
    ) private onlyRole(ADMIN) {
        if (value == 0) {
            revert Course_AmountNotValid();
        }
        if (s_courses[courseId].totalPlacesAvailable + value > MAX_PLACES_PER_COURSE) {
            revert Course_MaxPlacesPerCourseReached();
        }
        s_courses[courseId].placeFee = fee;
        s_courses[courseId].totalPlacesAvailable += value;
        s_courses[courseId].creator = _msgSender();
        s_courses[courseId].uri = courseUri;
        s_coursesTypeCounter.add(courseId);
        s_placesAllCounter += value;
        s_lessonsCounter += lessonsUris.length; //todo check that does not have repetitions
    }

    function removePlaceData(uint256 courseId, uint256 value) public onlyRole(ADMIN) {
        if (s_courses[courseId].totalPlacesAvailable < value) {
            revert Course_TooManyPlacesForThisCourse(s_courses[courseId].totalPlacesAvailable, value);
        }
        if (s_courses[courseId].creator == address(0)) {
            revert Course_CourseIdDoesNotExist(courseId);
        }
        s_courses[courseId].totalPlacesAvailable -= value;
    }

    function contractURI() public pure returns (string memory) {
        return string.concat(PROTOCOL, URI_PINATA, "/collection.json");
    }

    /**
     * Getters
     */
    //COURSES

    function getPlaceFee(uint256 courseId) public view returns (uint256) {
        return s_courses[courseId].placeFee;
    }

    function getCoursetotalPlacesAvailable(uint256 courseId) public view returns (uint256) {
        return s_courses[courseId].totalPlacesAvailable;
    }

    function getCoursePlacePurchased(uint256 courseId) public view returns (uint256) {
        return s_courses[courseId].placesPurchased;
    }

    function getCoursePassedStudents(uint256 courseId) public view returns (uint256) {
        return s_courses[courseId].passedStudents;
    }

    function getCourseCreator(uint256 courseId) public view returns (address) {
        return s_courses[courseId].creator;
    }

    function getCourseEnrolledStudents(uint256 courseId) public view returns (address[] memory) {
        return s_courses[courseId].enrolledStudents.values();
    }

    function getCourseUri(uint256 courseId) public view returns (string memory) {
        return s_courses[courseId].uri;
    }

    function getLessonsUris(uint256 courseId) public view returns (string[] memory) {
        return s_courses[courseId].lessonsUris;
    }

    function getDefaultAdmin() public view returns (address) {
        return s_defaultAdmin;
    }

    //COUNTERS
    function getAllPlaces() public view returns (uint256) {
        return s_placesAllCounter;
    }

    function getCoursesCounter() public view returns (uint256) {
        return s_coursesTypeCounter.length();
    }

    function getLessonsCounter(uint256 courseId) public view returns (uint256) {
        return s_courses[courseId].lessonsUris.length;
    }

    //CONSTANTS
    function getMaxPlacesPerCourse() public view returns (uint256) {
        return MAX_PLACES_PER_COURSE;
    }

    function getVersion() external pure returns (uint256) {
        return 1;
    }

    /**
     * Setters
     */

    //todo finish..
    function setUri(string memory uri) public onlyRole(ADMIN) {
        _setURI(uri);
    }

    function _setURI(string memory newuri) internal override {
        super._setURI(newuri);
    }

    function setMaxPlacesAmount(uint256 newAmount) public onlyRole(ADMIN) {
        if (newAmount == 0) {
            revert Course_SetMaxAmountCannotBeZero(newAmount);
        }
        MAX_PLACES_PER_COURSE = newAmount;
    }

    function incrementPlacesPurchased(uint256 courseId) public onlyRole(ADMIN) {
        s_courses[courseId].placesPurchased += 1;
    }

    function addEnrolledStudents(uint256 courseId, address student) public {
        s_courses[courseId].enrolledStudents.add(student);
    }

    function setCourseUri(uint256 courseId, string memory uri) public onlyRole(ADMIN) {
        s_courses[courseId].uri = uri;
    }

    function setLessonsUris(uint256 courseId, string[] memory lessonsUris) public onlyRole(ADMIN) {
        if (lessonsUris.length == 0) {
            revert CourseFactoryCourseCreator_LessonUrisMustBeMoreThanZero();
        }
        s_courses[courseId].lessonsUris = lessonsUris;
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
