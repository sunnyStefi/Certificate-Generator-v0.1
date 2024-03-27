//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @notice This contract govern the creation, transfer and management of certificates.
 */
contract Course is ERC1155, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant EVALUATOR = keccak256("EVALUATOR");
    bytes32 public constant STUDENT = keccak256("STUDENT");

    event Courses_CoursesCreated(uint256 indexed courseId);
    event Courses_CoursesRemoved(uint256 indexed courseId);
    event Courses_EvaluationCompleted(uint256 indexed courseId, address indexed student, uint256 indexed mark);
    event Courses_EvaluatorSetUp(address indexed evaluator);
    event RoleGranted(bytes32 indexed role, address indexed user);

    error Courses_TokenCannotBeTransferedOnlyBurned();
    error Course_IllegalMark(uint256 mark);
    error Courses_NoCourseIsRegisteredForTheUser(address user);
    error Courses_CourseNotRegisteredForTheUser(uint256 courseId, address student);
    error Courses_WithdrawalFailed();
    error Courses_SetCoursesUris_ParamsLengthDoNotMatch();
    error Course_BuyCourse_NotEnoughEthToBuyCourse(uint256 fee, uint256 value);
    error Course_EvaluatorAlreadyAssignedForThisCourse(address evaluator);
    error Course_TooManyEvaluatorsForThisCourse(uint256 maxEvaluatorsAmount);
    error Course_setMaxEvaluatorsAmountCannotBeZero(uint256 newAmount);
    error Course_EvaluatorNotAssignedToCourse(uint256 course, address evaluator);
    error Course_CourseIdDoesNotExist(uint256 courseId);
    error Course_EvaluatorNotAssignedForThisCourse(address evaluator);

    uint256 public constant BASE_COURSE_FEE = 0.01 ether;
    string public constant JSON = ".json";
    string public constant ID_JSON = "/{id}.json";
    string public constant PROTOCOL = "https://ipfs.io/ipfs/";
    string public constant URI_PINATA = "QmZeczzyz6ow8vNJrP7jBnZPdF7CQYrcUjqQZrgXC6hXMF";

    uint256 private s_coursesTypeCounter;
    uint256 private s_maxEvaluatorsAmount = 5;

    mapping(uint256 => CourseStruct) private s_courses;
    mapping(address => uint256[]) private s_userToCourses;
    mapping(uint256 => EvaluatedStudent[]) private s_courseToEvaluatedStudents;

    struct CourseStruct {
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
        if (mark < 1 || mark > 10) revert Course_IllegalMark(mark);
        _;
    }

    modifier onlyIfCourseIdExists(uint256 courseId) {
        if (s_courses[courseId].creator == address(0)) {
            revert Course_CourseIdDoesNotExist(courseId);
        }
        _;
    }

    modifier onlyAssignedEvaluator(uint256 courseId, address evaluator) {
        if (!s_courses[courseId].evaluators.contains(evaluator)) {
            revert Course_EvaluatorNotAssignedToCourse(courseId, evaluator);
        }
        _;
    }

    constructor() ERC1155(string.concat(PROTOCOL, URI_PINATA, ID_JSON)) {
        //todo role admin transfer
        _setRoleAdmin(ADMIN, ADMIN);
        _setRoleAdmin(EVALUATOR, ADMIN);
        _setRoleAdmin(STUDENT, ADMIN);

        _grantRole(ADMIN, _msgSender());
        _grantRole(ADMIN, address(this));

        s_coursesTypeCounter = 0;
    }

    /**
     * Courses
     */
    function createCourses(
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data,
        string[] memory uris,
        uint256[] memory fees
    ) public onlyRole(ADMIN) returns (uint256) {
        setCoursesPlacesData(ids, values, uris, fees);
        _mintBatch(_msgSender(), ids, values, data);
        setApprovalForAll(_msgSender(), true);
        emit Courses_CoursesCreated(s_coursesTypeCounter);
        return ids.length;
    }

    function removePlaces(
        uint256[] memory ids,
        uint256[] memory values //remove from
    ) public onlyRole(ADMIN) {
        removePlacesData(ids, values);
        _burnBatch(_msgSender(), ids, values);
        emit Courses_CoursesRemoved(values.length);
    }

    function removePlaces(
        address from,
        uint256 id,
        uint256 value //remove from
    ) public onlyRole(ADMIN) {
        removePlaceData(id, value);
        _burn(from, id, value);
        emit Courses_CoursesRemoved(value);
    }

    /**
     * Evaluator
     */
    function setUpEvaluator(address evaluator, uint256 courseId)
        public
        onlyRole(ADMIN)
        onlyIfCourseIdExists(courseId)
    {
        if (s_courses[courseId].evaluators.contains(evaluator)) {
            revert Course_EvaluatorAlreadyAssignedForThisCourse(evaluator);
        }
        //EnumerableSet uses 0 as a sentinel value -> - 1 to the desired length
        if (s_courses[courseId].evaluators.length() > (s_maxEvaluatorsAmount - 1)) {
            revert Course_TooManyEvaluatorsForThisCourse(s_maxEvaluatorsAmount);
        }
        s_courses[courseId].evaluators.add(evaluator);
        grantRole(EVALUATOR, evaluator);
        emit Courses_EvaluatorSetUp(evaluator);
    }

    function removeEvaluator(address evaluator, uint256 courseId)
        public
        onlyRole(ADMIN)
        onlyIfCourseIdExists(courseId)
    {
        if (!s_courses[courseId].evaluators.contains(evaluator)) {
            revert Course_EvaluatorNotAssignedForThisCourse(evaluator);
        }
        s_courses[courseId].evaluators.remove(evaluator);
        revokeRole(EVALUATOR, evaluator);
    }

    /**
     * Purchase
     */
    function buyPlace(uint256 courseId) public payable {
        //todo exceptions do not add replicated courses
        if (msg.value < s_courses[courseId].placeFee) {
            revert Course_BuyCourse_NotEnoughEthToBuyCourse(s_courses[courseId].placeFee, msg.value);
        }
        if (s_courses[courseId].evaluators.length() == 0) {
            revert Course_EvaluatorNotAssignedForThisCourse(address(0));
        }
        s_userToCourses[_msgSender()].push(courseId);
        s_courses[courseId].placesPurchased += 1;
        s_courses[courseId].enrolledStudents.add(_msgSender());
    }

    //todo return values
    function transferPlaceNFT(address student, uint256 courseId) public onlyRole(ADMIN) {
        safeTransferFrom(s_courses[courseId].creator, student, courseId, 1, "0x");
    }

    /**
     * Evaluation
     */
    function evaluate(uint256 courseId, address student, uint256 mark)
        public
        onlyRole(EVALUATOR)
        validateMark(mark)
        onlyAssignedEvaluator(courseId, _msgSender())
        returns (bool)
    {
        //TODO evaluated only if it has NFT!
        //TODO validate the course for the student
        //TODO do not evaluate 2 times for each course-student

        uint256[] memory user_courses = s_userToCourses[student];
        bool valid_match = false;
        if (user_courses.length == 0) revert Courses_NoCourseIsRegisteredForTheUser(student);
        uint256 i = 0;
        while (i < user_courses.length) {
            if (user_courses[i] == courseId) {
                s_courseToEvaluatedStudents[i].push(EvaluatedStudent(mark, block.timestamp, student, _msgSender()));
                valid_match = true;
                break;
            }
            i++;
        }
        if (mark > 6) s_courses[courseId].passedStudents += 1;
        if (!valid_match) revert Courses_CourseNotRegisteredForTheUser(courseId, student);
        emit Courses_EvaluationCompleted(courseId, student, mark);
        return valid_match;
    }

    /**
     * Make certificates
     */
    function makeCertificates(uint256 courseId, string memory certificateUri) public onlyRole(ADMIN) {
        //todo all evaluated = enrolled
        //Burns for the not promoted students
        uint256 evaluatedStudents = s_courseToEvaluatedStudents[courseId].length;
        uint256 notSoldCourses = s_courses[courseId].placeNumber - s_courses[courseId].placesPurchased;
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = courseId;
        values[0] = notSoldCourses;
        removePlaces(ids, values);

        for (uint256 i = 0; i < evaluatedStudents; i++) {
            if (s_courseToEvaluatedStudents[courseId][i].mark < 6) {
                removePlaces(s_courseToEvaluatedStudents[courseId][i].student, courseId, 1);
            } else {
                setCertificateUri(courseId, certificateUri);
            }
        }
    }

    /**
     * Funds management
     */
    function withdraw() public payable onlyRole(ADMIN) {
        (bool succ,) = payable(_msgSender()).call{value: address(this).balance}(""); //change owner
        if (!succ) revert Courses_WithdrawalFailed(); //todo transfer ownership
    }

    /**
     * Storage Utils
     */
    function setCoursesPlacesData(
        uint256[] memory courseIds,
        uint256[] memory values,
        string[] memory uri,
        uint256[] memory fees
    ) private onlyRole(ADMIN) {
        //check same length
        // todo make another Struct with uri, fees, owner
        if (courseIds.length != uri.length) revert Courses_SetCoursesUris_ParamsLengthDoNotMatch(); //add  fees
        s_coursesTypeCounter += values.length;
        for (uint256 i = 0; i < courseIds.length; i++) {
            uint256 courseId = courseIds[i];
            s_courses[courseId].placeFee = fees[i];
            s_courses[courseId].placeNumber += values[i];
            s_courses[courseId].creator = _msgSender();
            s_courses[courseId].uri = uri[i];
        }
    }

    function removePlacesData(uint256[] memory courseId, uint256[] memory values) public onlyRole(ADMIN) {
        // todo make another Struct with uri, fees, owner
        if (courseId.length != values.length) revert Courses_SetCoursesUris_ParamsLengthDoNotMatch();
        for (uint256 i = 0; i < values.length; i++) {
            s_courses[courseId[i]].placeNumber -= values[i];
        }
    }

    function removePlaceData(uint256 courseId, uint256 value) public onlyRole(ADMIN) {
        s_courses[courseId].placeNumber -= value;
    }

    function contractURI() public pure returns (string memory) {
        return string.concat(PROTOCOL, URI_PINATA, "/collection.json");
    }

    /**
     * Getters
     */
    function getEvaluators(uint256 courseId)
        public
        view
        onlyIfCourseIdExists(courseId)
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
        return s_coursesTypeCounter;
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
        return s_maxEvaluatorsAmount;
    }

    function getEvaluatorsPerCourse(uint256 courseId) public view returns (uint256) {
        return s_courses[courseId].evaluators.length();
    }

    function getCourseCreator(uint256 courseId) public view returns (address) {
        return s_courses[courseId].creator;
    }

    function getCourseUri(uint256 courseId) public view returns (string memory) {
        return s_courses[courseId].uri;
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
        if (newAmount == 0) revert Course_setMaxEvaluatorsAmountCannotBeZero(newAmount);
        s_maxEvaluatorsAmount = newAmount;
    }

    function setCertificateUri(uint256 courseId, string memory uri) public onlyRole(ADMIN) {
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
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
