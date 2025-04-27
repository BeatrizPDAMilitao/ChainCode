// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";

contract MedicalRecordAccess2 {
    using Strings for uint256;
    enum RequestStatus { Pending, Approved, Denied }

    struct AccessRequest {
        address doctor;
        address patient;
        string recordId;
        string recordType;
        uint256 timestamp;
        RequestStatus status;
    }

    struct MedicalAccessLog {
        address doctor;
        address patient;
        string recordId;
        string recordType; // e.g., "MRI", "X-Ray"
        uint256 timestamp;
    }

    address public owner;
    mapping(address => mapping(string => AccessRequest)) public accessRequests;
    AccessRequest[] public accessRequestsList;

    mapping(string => address[]) public recordAccessList;
    MedicalAccessLog[] public accessLogs;
    uint256 public syncPointer = 0; // Points to next unread access
    uint256 public constant SYNC_BATCH_SIZE = 3;

    event AccessRequested(address indexed doctor, address indexed patient, string recordId, uint256 timestamp);
    event AccessApproved(address indexed doctor, address indexed patient, string recordId, uint256 timestamp);
    event AccessDenied(address indexed doctor, address indexed patient, string recordId, uint256 timestamp);
    event RecordAccessed(address indexed doctor, address indexed patient, string recordType, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this");
        _;
    }

    constructor() {
        owner = msg.sender;
        _generateSampleAccessRequests();
    }

    function resetSyncPointer() external {
        syncPointer = 0;
    }

    function getRequestId(address doctor, address patient, string memory recordType, uint256 timestamp) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(doctor, patient, recordType, timestamp));
    }

    function doctorRequestAccess(address doctor, address patient, string memory recordId, string memory recordType) external {
        AccessRequest storage existing = accessRequests[doctor][recordId];
        require(existing.timestamp == 0, "Request already exists");

        AccessRequest memory newRequest = AccessRequest({
            doctor: doctor,
            patient: patient,
            recordId: recordId,
            recordType: recordType,
            timestamp: block.timestamp,
            status: RequestStatus.Pending
        });

        accessRequests[doctor][recordId] = newRequest;
        accessRequestsList.push(newRequest);

        emit AccessRequested(doctor, patient, recordId, block.timestamp);
    }

    function requestAccess(address patient, string memory recordId, string memory recordType) external {
        AccessRequest storage existing = accessRequests[msg.sender][recordId];
        require(existing.timestamp == 0, "Request already exists");

        AccessRequest memory newRequest = AccessRequest({
            doctor: msg.sender,
            patient: patient,
            recordId: recordId,
            recordType: recordType,
            timestamp: block.timestamp,
            status: RequestStatus.Pending
        });

        accessRequests[msg.sender][recordId] = newRequest;
        accessRequestsList.push(newRequest);

        emit AccessRequested(msg.sender, patient, recordId, block.timestamp);
    }

    function approveAccess(address doctor, string memory recordId) external {
        AccessRequest storage request = accessRequests[doctor][recordId];
        require(request.patient == msg.sender, "Only patient can approve");
        require(request.status == RequestStatus.Pending, "Already processed");

        request.status = RequestStatus.Approved;

        accessLogs.push(MedicalAccessLog({
            doctor: doctor,
            patient: msg.sender,
            recordId: recordId,
            recordType: request.recordType,
            timestamp: block.timestamp
        }));

        emit AccessApproved(doctor, msg.sender, recordId, block.timestamp);
    }

    function denyAccess(address doctor, string memory recordId) external {
        AccessRequest storage request = accessRequests[doctor][recordId];
        require(request.patient == msg.sender, "Only patient can deny");
        require(request.status == RequestStatus.Pending, "Already processed");

        request.status = RequestStatus.Denied;

        emit AccessDenied(doctor, msg.sender, recordId, block.timestamp);
    }

    function hasAccess(string memory recordId, address user) external view returns (bool) {
        address[] memory allowedUsers = recordAccessList[recordId];
        for (uint256 i = 0; i < allowedUsers.length; i++) {
            if (allowedUsers[i] == user) {
                return true;
            }
        }
        return false;
    }

    /*function getRequestStatus(string memory recordId, address requester) external view returns (AccessStatus) {
        bytes32 requestKey = keccak256(abi.encodePacked(recordId, requester));
        return accessRequests[requestKey].status;
    }*/

    function logAccess(address doctor, address patient, string memory recordId, string memory recordType) external {
        accessLogs.push(MedicalAccessLog({
            doctor: doctor,
            patient: patient,
            recordId: recordId,
            recordType: recordType,
            timestamp: block.timestamp
        }));

        emit RecordAccessed(doctor, patient, recordType, block.timestamp);
    }

    function getAccessLogs() external view returns (MedicalAccessLog[] memory) {
        return accessLogs;
    }

    function getAccessRequest(address doctor, string memory recordId) external view returns (AccessRequest memory) {
        return accessRequests[doctor][recordId];
    }

    function getAccessRequests() external view returns (AccessRequest[] memory) {
        return accessRequestsList;
    }

    // Moves the pointer forward
    function getNextAccessRequests() external {
        uint256 remaining = accessRequestsList.length - syncPointer;
        uint256 count = remaining < SYNC_BATCH_SIZE ? remaining : SYNC_BATCH_SIZE;
        syncPointer += count;
    }

    // View function to inspect logs at the current pointer
    function previewNextAccessRequests() external view returns (AccessRequest[] memory) {
        uint256 remaining = accessRequestsList.length - syncPointer;
        uint256 count = remaining < SYNC_BATCH_SIZE ? remaining : SYNC_BATCH_SIZE;

        AccessRequest[] memory result = new AccessRequest[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = accessRequestsList[syncPointer + i];
        }

        return result;
    }

    function _generateSampleAccessRequests() internal {
        for (uint256 i = 0; i < 50; i++) {
            address doctor = address(uint160(uint256(keccak256(abi.encodePacked("doctor", i)))));
            address patient = 0xe8291f943C0E168695c196482d261fC6258b30DC;
            string memory recordType = i % 2 == 0 ? "MRI" : "X-Ray";
            string memory recordId = Strings.toString(i+1);

            RequestStatus status = RequestStatus.Pending;
            if (i % 3 == 0) {
                status = RequestStatus.Pending;
            } else if (i % 3 == 1) {
                status = RequestStatus.Approved;
            } else if (i % 3 == 2) {
                status = RequestStatus.Denied;
            }

            AccessRequest memory newRequest = AccessRequest({
                doctor: doctor,
                patient: patient,
                recordId: recordId,
                recordType: recordType,
                timestamp: block.timestamp - (i * 1 days),
                status: status
            });

            accessRequests[msg.sender][recordId] = newRequest;
            accessRequestsList.push(newRequest);
        }
    }

    function deleteAccessRequests() external onlyOwner {
        // Clean up the accessRequests mapping using accessRequestsList
        for (uint256 i = 0; i < accessRequestsList.length; i++) {
            AccessRequest storage request = accessRequestsList[i];
            delete accessRequests[request.doctor][request.recordId];
        }

        // Clear the array
        delete accessRequestsList;

        // Reset sync pointer
        syncPointer = 0;

        // Re-generate sample access requests for testing
        _generateSampleAccessRequests();
    }

}
