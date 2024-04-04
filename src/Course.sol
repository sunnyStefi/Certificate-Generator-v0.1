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
contract Course is Initializable, ERC1155Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
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
    uint256 private MAX_EVALUATORS;
    uint256 private MAX_PLACES_PER_COURSE;

    mapping(uint256 => CourseStruct) private s_courses;
    mapping(address => uint256[]) private s_userToCourses;
    mapping(uint256 => EvaluatedStudent[]) private s_courseToEvaluatedStudents;

    uint256[49] __gap;

    struct CourseStruct {
        bool certified;
        uint256 placeFee;
        uint256 placeNumber;
        uint256 placesPurchased;
        uint256 passedStudents;
        address creator;
        string uri;
        EnumerableSet.AddressSet evaluators;
        EnumerableSet.AddressSet enrolledStudents;
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
        //address defaultAdmin, address upgrader
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
    }

    /**
     * 1 Courses
     */
    function createCourse(uint256 id, uint256 value, bytes memory data, string memory uri, uint256 fee)
        public
        onlyRole(ADMIN)
        validateAmount(id)
        validateAmount(value)
        returns (uint256)
    {
        setCoursePlacesData(id, value, uri, fee);
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
     * 2 Evaluator
     */
    function setUpEvaluator(address evaluator, uint256 courseId)
        public
        onlyRole(ADMIN)
        validateAddress(evaluator)
        courseExists(courseId)
    {
        if (s_courses[courseId].evaluators.contains(evaluator)) {
            revert Course_EvaluatorAlreadyAssignedForThisCourse(evaluator);
        }
        //EnumerableSet uses 0 as a sentinel value -> - 1 to the desired length
        if (s_courses[courseId].evaluators.length() > (MAX_EVALUATORS - 1)) {
            revert Course_TooManyEvaluatorsForThisCourse(MAX_EVALUATORS);
        }

        s_courses[courseId].evaluators.add(evaluator);
        grantRole(EVALUATOR, evaluator);
    }

    function removeEvaluator(address evaluator, uint256 courseId) public onlyRole(ADMIN) courseExists(courseId) {
        if (!s_courses[courseId].evaluators.contains(evaluator)) {
            revert Course_EvaluatorNotAssignedForThisCourse(evaluator);
        }
        s_courses[courseId].evaluators.remove(evaluator);
        revokeRole(EVALUATOR, evaluator);
    }

    /**
     * 3 Purchase
     */
    function buyPlace(uint256 courseId) public payable validateAmount(courseId) courseExists(courseId) {
        if (s_courses[courseId].placesPurchased >= MAX_PLACES_PER_COURSE) {
            revert Course_MaxPlacesPerCourseReached();
        }
        if (msg.value < s_courses[courseId].placeFee) {
            revert Course_BuyCourse_NotEnoughEthToBuyCourse(s_courses[courseId].placeFee, msg.value);
        }
        if (s_courses[courseId].evaluators.length() == 0) {
            revert Course_EvaluatorNotAssignedForThisCourse(address(0));
        }
        if (s_courses[courseId].enrolledStudents.contains(_msgSender())) {
            revert Course_StudentCannotBuyMoreThanOnePlace();
        }
        if (s_courses[courseId].evaluators.contains(_msgSender())) {
            revert Course_EvaluatorCannotBeStudent();
        }
        s_userToCourses[_msgSender()].push(courseId);
        s_courses[courseId].placesPurchased += 1;
        s_courses[courseId].enrolledStudents.add(_msgSender());
        s_placesPurchasedCounter += 1;
    }

    //todo return values
    function transferPlaceNFT(address student, uint256 courseId)
        public
        onlyRole(ADMIN)
        validateAddress(student)
        courseExists(courseId)
    {
        if (!s_courses[courseId].enrolledStudents.contains(student)) {
            revert Courses_CourseNotRegisteredForTheUser(courseId, student);
        }
        if (s_courses[courseId].evaluators.contains(student)) {
            revert Course_EvaluatorCannotBeStudent();
        }

        safeTransferFrom(s_courses[courseId].creator, student, courseId, 1, "0x");
    }

    /**
     *  4 Evaluation
     */
    function evaluate(uint256 courseId, address student, uint256 mark)
        public
        onlyRole(EVALUATOR)
        validateAddress(student)
        validateMark(mark)
        courseExists(courseId)
    {
        if (!s_courses[courseId].evaluators.contains(_msgSender())) {
            revert Course_EvaluatorNotAssignedToCourse(courseId, _msgSender());
        }
        if (s_courses[courseId].evaluators.contains(student)) {
            revert Course_StudentCannotBeEvaluator(student);
        }
        if (!s_courses[courseId].enrolledStudents.contains(student)) {
            revert Course_StudentNotEnrolled(student);
        }
        if (isStudentEvaluated(courseId, student)) {
            revert Course_StudentAlreadyEvaluated(student);
        }
        if (this.balanceOf(student, courseId) != 1) {
            revert Course_DoesNotHaveExactlyOnePlaceNFT(student, this.balanceOf(student, courseId));
        }
        if (s_userToCourses[student].length == 0) {
            revert Courses_NoCourseIsRegisteredForTheUser(student);
        }
        if (mark >= 6) {
            s_courses[courseId].passedStudents += 1;
        }
        s_courseToEvaluatedStudents[courseId].push(EvaluatedStudent(mark, block.timestamp, student, _msgSender()));
        emit Courses_EvaluationCompleted(courseId, student, mark);
    }

    /**
     * 5 Make certificates
     */
    function makeCertificates(uint256 courseId, string memory certificateUri)
        public
        onlyRole(ADMIN)
        courseExists(courseId)
    {
        if (s_courses[courseId].certified) {
            revert Course_CannotCertifyTheCourseTwice();
        }
        s_certificatesCounter += 1;
        s_courses[courseId].certified = true;

        uint256 evaluatedStudents = s_courseToEvaluatedStudents[courseId].length;
        uint256 notSoldPlaces = s_courses[courseId].placeNumber - s_courses[courseId].placesPurchased;
        removePlaces(_msgSender(), courseId, notSoldPlaces);

        for (uint256 i = 0; i < evaluatedStudents; i++) {
            if (s_courseToEvaluatedStudents[courseId][i].mark < 6) {
                removePlaces(s_courseToEvaluatedStudents[courseId][i].student, courseId, 1);
            } else {
                setCourseUri(courseId, certificateUri);
            }
        }
    }

    /**
     * 6 Funds management
     */
    function withdraw(uint256 amount) public payable onlyRole(ADMIN) {
        if (amount > address(this).balance) {
            revert Courses_NotEnoughFunds(amount, address(this).balance);
        }
        (bool succ,) = payable(_msgSender()).call{value: amount}("");

        if (!succ) {
            revert Courses_WithdrawalFailed();
        }
        emit Courses_Withdrawal(_msgSender(), amount);
    }

    /**
     * Storage Utils
     */
    function setCoursePlacesData(uint256 courseId, uint256 value, string memory uri, uint256 fee)
        private
        onlyRole(ADMIN)
    {
        if (value == 0) {
            revert Course_AmountNotValid();
        }
        if (s_courses[courseId].placeNumber + value > MAX_PLACES_PER_COURSE) {
            revert Course_MaxPlacesPerCourseReached();
        }
        s_courses[courseId].placeFee = fee;
        s_courses[courseId].placeNumber += value;
        s_courses[courseId].creator = _msgSender();
        s_courses[courseId].uri = uri;
        s_coursesTypeCounter.add(courseId);
        s_placesAllCounter += value;
    }

    function removePlaceData(uint256 courseId, uint256 value) public onlyRole(ADMIN) {
        if (s_courses[courseId].placeNumber < value) {
            revert Course_TooManyPlacesForThisCourse(s_courses[courseId].placeNumber, value);
        }
        if (s_courses[courseId].creator == address(0)) {
            revert Course_CourseIdDoesNotExist(courseId);
        }
        s_courses[courseId].placeNumber -= value;
    }

    function contractURI() public pure returns (string memory) {
        return string.concat(PROTOCOL, URI_PINATA, "/collection.json");
    }

    function isStudentEvaluated(uint256 courseId, address student) public view returns (bool) {
        for (uint256 i = 0; i < s_courseToEvaluatedStudents[courseId].length; i++) {
            if (s_courseToEvaluatedStudents[courseId][i].student == student) {
                return true;
            }
        }
        return false;
    }

    /**
     * Getters
     */
    function getEvaluators(uint256 courseId)
        public
        view
        validateAmount(courseId)
        returns (address[] memory evaluators)
    {
        return s_courses[courseId].evaluators.values();
    }

    function getCourseToEnrolledStudents(uint256 courseId) public view returns (address[] memory) {
        return s_courses[courseId].enrolledStudents.values();
    }

    function getCoursesPerUser(address user) public view returns (uint256[] memory) {
        return s_userToCourses[user];
    }

    function getCourseToEvaluateStudents(uint256 courseId) public view returns (EvaluatedStudent[] memory) {
        return s_courseToEvaluatedStudents[courseId];
    }

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
