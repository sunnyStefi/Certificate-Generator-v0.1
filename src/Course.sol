//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.18;

// import {Register} from "./Register.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
// import {Certificate} from "./Certificate.sol";

/**
 * @notice This contract govern the creation, transfer and management of certificates.
 */
contract Course is ERC1155, AccessControl {
    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant EVALUATOR = keccak256("EVALUATOR");
    bytes32 public constant STUDENT = keccak256("STUDENT");

    event Courses_CoursesCreated(uint256 courseId);
    event Courses_CoursesRemoved(uint256 courseId);
    event Courses_EvaluationCompleted(uint256 courseId, address student, uint256 mark);
    event Courses_EvaluatorSetUp(address evaluator);
    event RoleGranted(bytes32 role, address user);

    error Courses_TokenCannotBeTransferedOnlyBurned();
    error Course_IllegalMark(uint256 mark);
    error Courses_NoCourseIsRegisteredForTheUser(address user);
    error Courses_CourseNotRegisteredForTheUser(uint256 courseId, address student);
    error Courses_WithdrawalFailed();
    error Courses_SetCoursesUris_ParamsLengthDoNotMatch();
    error Course_BuyCourse_NotEnoughEthToBuyCourse(uint256 fee, uint256 value);

    string public constant JSON = ".json";
    string public constant ID_JSON = "/{id}.json";
    string public constant PROTOCOL = "https://ipfs.io/ipfs/";
    string public constant URI_PINATA = "QmcbWTvWMBoRwvJdXUDjuaRXD5w6BKxTeUe3vNZ6Hm4zg6";
    uint256 public constant BASE_COURSE_FEE = 0.01 ether;

    // Certificate s_certificate_contract;

    uint256 private s_coursesCounter;
    address[] private s_evaluators;
    mapping(uint256 => string) private s_uris; // each course has an uri that points to its metadata
    mapping(address => uint256[]) private s_userToCourses;
    mapping(uint256 => uint256) private s_courseToFee;

    mapping(uint256 => uint256) private s_courseToCounter;
    mapping(uint256 => address) private s_courseToOwner;
    mapping(uint256 => address[]) private s_courseToEnrolledStudents;
    mapping(uint256 => EvaluatedStudent[]) private s_courseToEvaluatedStudents;
    mapping(uint256 => uint256) private s_courseToPassedUsers;

    struct EvaluatedStudent {
        uint256 mark;
        uint256 date;
        address student;
        address evaluator;
    }
    //more info here, ..

    modifier validateMark(uint256 mark) {
        if (mark < 1 || mark > 10) revert Course_IllegalMark(mark);
        _;
    }

    constructor() public ERC1155(string.concat(PROTOCOL, URI_PINATA, ID_JSON)) {
        //todo role admin transfer
        _setRoleAdmin(ADMIN, ADMIN);
        _setRoleAdmin(EVALUATOR, ADMIN);
        _setRoleAdmin(STUDENT, ADMIN);

        _grantRole(ADMIN, _msgSender());
        _grantRole(ADMIN, address(this));

        s_coursesCounter = 0;
        //s_certificate_contract = new Certificate();
    }

    function getSender() public view returns (bool) {
        return hasRole(ADMIN, _msgSender());
    }

    function setUpEvaluator(address evaluator) public onlyRole(ADMIN) {
        // todo course evaluator
        s_evaluators.push(evaluator);
        grantRole(EVALUATOR, evaluator);
        emit Courses_EvaluatorSetUp(evaluator);
    }

    function createCourses(
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data,
        string[] memory uris,
        uint256[] memory fees
    ) public onlyRole(ADMIN) returns (uint256) {
        uint256 numberOfCourses = values.length;
        s_coursesCounter += numberOfCourses;
        setCoursesData(ids, uris, fees);
        _mintBatch(_msgSender(), ids, values, data);
        //approve their transfer for later // can we costumise this? e.g they cannot move it around
        setApprovalForAll(_msgSender(), true);
        emit Courses_CoursesCreated(numberOfCourses);
        return 2;
    }

    function removeCourses(
        uint256[] memory ids,
        uint256[] memory values //remove from
    ) public onlyRole(ADMIN) returns (uint256) {
        uint256 numberOfCourses = values.length;
        s_coursesCounter -= numberOfCourses; // check if s_counter is still valid
        _burnBatch(_msgSender(), ids, values);
        emit Courses_CoursesRemoved(numberOfCourses);
        return s_coursesCounter;
    }

    function removeFailedStudentCourse(
        address from,
        uint256 id,
        uint256 value //remove from
    ) public onlyRole(ADMIN) returns (uint256) {
        s_coursesCounter -= value; // check if s_counter is still valid
        _burn(from, id, value);
        emit Courses_CoursesRemoved(value);
        return s_coursesCounter;
    }

    // function getCoursesPerUser(address user) public view returns (Course[] memory) {
    //     return s_userToCourses[user];
    // }

    function buyCourse(uint256 courseId) public payable returns (bool) {
        //todo exceptions do not add replicated courses
        if (msg.value < s_courseToFee[courseId]) {
            revert Course_BuyCourse_NotEnoughEthToBuyCourse(s_courseToFee[courseId], msg.value);
        }
        s_userToCourses[_msgSender()].push(courseId);
        s_courseToCounter[courseId] += 1;
        s_courseToEnrolledStudents[courseId].push(_msgSender());
    }
    //todo return bool even above

    function transferCourseNFT(address student, uint256 courseId) public onlyRole(ADMIN) returns (bool) {
        //this can be initialized only by the owner of the NFT --> cannot put inside buycourse
        safeTransferFrom(s_courseToOwner[courseId], student, courseId, 1, "0x");
    }

    // function transferCoursesCertificate(address from, address to){}  //

    // function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override {
    //     if (_msgSender() == owner() || to == address(0)) revert Courses_TokenCannotBeTransferedOnlyBurned();
    //     super._update(from, to, ids, values);
    // }

    //todo evaluate many
    function evaluate(uint256 courseId, address student, uint256 mark)
        public
        onlyRole(EVALUATOR)
        validateMark(mark)
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
        if (mark > 6) s_courseToPassedUsers[courseId] += 1;
        if (!valid_match) revert Courses_CourseNotRegisteredForTheUser(courseId, student);
        emit Courses_EvaluationCompleted(courseId, student, mark);
        return valid_match;
    }

    //Only Admin can approve whom is transferred to
    function setApprovalForAll(address operator, bool approved) public override onlyRole(ADMIN) {
        super.setApprovalForAll(operator, approved);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data){
        public
        override
        onlyRole(ADMIN){
        super.safeTransferFrom(from, to, id, value, data);
    }

    function makeCertificates(uint256 courseId, string memory certificateUri) public onlyRole(ADMIN) {
        //todo all evaluated = enrolled
        //Burns for the not promoted students
        uint256 evaluatedStudents = s_courseToEvaluatedStudents[courseId].length;
        uint256 notSoldCourses = s_courseToCounter[courseId] - evaluatedStudents;
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = courseId;
        values[0] = notSoldCourses;
        removeCourses(ids, values);

        for (uint256 i = 0; i < evaluatedStudents; i++) {
            if (s_courseToEvaluatedStudents[courseId][i].mark < 6) {
                removeFailedStudentCourse(s_courseToEvaluatedStudents[courseId][i].student, courseId, 1);
            } else {
                setCertificateUri(courseId, certificateUri);
            }
        }
    }

    function withdraw() public payable onlyRole(ADMIN) {
        (bool succ,) = payable(_msgSender()).call{value: address(this).balance}(""); //change owner
        if (!succ) revert Courses_WithdrawalFailed(); //todo transfer ownership
    }

    function uri(uint256 _tokenid) public view override returns (string memory) {
        return s_uris[_tokenid];
        // return string.concat(BASE_URI, Strings.toString(_tokenid), JSON);
    }

    function setCoursesData(uint256[] memory courseId, string[] memory uri, uint256[] memory fees)
        public
        onlyRole(ADMIN)
    {
        //check same length
        // todo make another Struct with uri, fees, owner
        if (courseId.length != uri.length) revert Courses_SetCoursesUris_ParamsLengthDoNotMatch(); //add  fees
        for (uint256 i = 0; i < s_coursesCounter; i++) {
            s_uris[courseId[i]] = uri[i];
            s_courseToFee[courseId[i]] = fees[i];
            s_courseToOwner[courseId[i]] = _msgSender();
        }
    }

    function setCertificateUri(uint256 courseId, string memory uri) public onlyRole(ADMIN) {
        s_uris[courseId] = uri;
    }

    function getCourseUri(uint256 courseId) public returns (string memory) {
        return s_uris[0];
    }

    function contractURI() public pure returns (string memory) {
        return string.concat(PROTOCOL, URI_PINATA, "/collection.json");
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

    function getEvaluator(uint256 index) public view returns (address) {
        return s_evaluators[index];
    }

    function getCourseToEnrolledStudents(uint256 courseId) public view returns (address[] memory) {
        return s_courseToEnrolledStudents[courseId];
    }

    function getCoursesPerUser(address user) public view returns (uint256[] memory) {
        return s_userToCourses[user];
    }

    function getCourseToEvaluateStudents(uint256 courseId) public view returns (EvaluatedStudent[] memory) {
        return s_courseToEvaluatedStudents[courseId];
    }
}
