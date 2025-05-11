// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";

contract MedicalRecordAccess2 {
    using Strings for uint256;
    enum RequestStatus { Pending, Approved, Denied }

    struct AccessRequest {
        address doctorAddress;
        address patientAddress;
        string doctorMedplumId;
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

    function doctorRequestAccess(address doctor, address patient, string memory doctorId, string memory recordId, string memory recordType) external {
        AccessRequest storage existing = accessRequests[doctor][recordId];
        require(existing.timestamp == 0, "Request already exists");

        AccessRequest memory newRequest = AccessRequest({
            doctorAddress: doctor,
            patientAddress: patient,
            doctorMedplumId: doctorId,
            recordId: recordId,
            recordType: recordType,
            timestamp: block.timestamp,
            status: RequestStatus.Pending
        });

        accessRequests[doctor][recordId] = newRequest;
        accessRequestsList.push(newRequest);

        emit AccessRequested(doctor, patient, recordId, block.timestamp);
    }

    function approveAccess(address doctor, string memory recordId) external {
        AccessRequest storage request = accessRequests[doctor][recordId];
        require(request.patientAddress == msg.sender, "Only patient can approve");
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
        require(request.patientAddress == msg.sender, "Only patient can deny");
        require(request.status == RequestStatus.Pending, "Already processed");

        request.status = RequestStatus.Denied;

        emit AccessDenied(doctor, msg.sender, recordId, block.timestamp);
    }

    function getAccessRequest(address doctor, string memory recordId) external view returns (AccessRequest memory) {
        return accessRequests[doctor][recordId];
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
        for (uint256 i = 0; i < 12; i++) {
            address doctor = address(uint160(uint256(keccak256(abi.encodePacked("doctor", i)))));
            address patient = 0xe8291f943C0E168695c196482d261fC6258b30DC;
            string memory recordType = i % 2 == 0 ? "MRI" : "X-Ray";
            string memory recordId = Strings.toString(i+1);
            string memory doctorId = "01968b55-08af-70ce-8159-23b14e09a48a";

            RequestStatus status = RequestStatus.Pending;
            if (i % 3 == 0) {
                status = RequestStatus.Pending;
            } else if (i % 3 == 1) {
                status = RequestStatus.Approved;
            } else if (i % 3 == 2) {
                status = RequestStatus.Denied;
            }

            AccessRequest memory newRequest = AccessRequest({
                doctorAddress: doctor,
                patientAddress: patient,
                doctorMedplumId: doctorId,
                recordId: recordId,
                recordType: recordType,
                timestamp: block.timestamp - (i * 1 days),
                status: status
            });

            accessRequests[doctor][recordId] = newRequest;
            accessRequestsList.push(newRequest);
        }
    }
}