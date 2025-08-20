// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";

contract MedicalRecordAccess2 {
    using Strings for uint256;
    enum RequestStatus { Pending, Approved, Denied }

    error RequestAlreadyExists(string accessId);
    error OnlyPatientCanApprove();
    error OnlyPatientCanDeny();
    error RequestAlreadyProcessed();
    error AccessWasNotApproved();

    
    struct Record {
        address requestor;
        string hash;
        string version;
        uint256 lastUpdated;
    }

    struct AccessRequest {
        address doctorAddress;
        address patientAddress;
        string doctorMedplumId;
        string recordId;
        uint256 timestamp;
        RequestStatus status;
    }

    struct MedicalAccessLog {
        address doctor;
        address patient;
        string recordId;
        uint256 timestamp;
    }

    address public owner;
    mapping(string => Record) private records; // Maps recordId to Record. Where recordId is like "Patient/resourcedId"
    mapping(string => bool) private recordExistsMap;

    mapping(address => mapping(string => AccessRequest)) public accessRequests; // Maps doctor address to recordId to AccessRequest
    AccessRequest[] public accessRequestsList;

    mapping(string => address[]) public recordAccessList;
    MedicalAccessLog[] public accessLogs;
    uint256 public syncPointer = 0; // Points to next unread access
    uint256 public constant SYNC_BATCH_SIZE = 3;

    event AccessRequested(address indexed doctor, address indexed patient, string recordId, uint256 timestamp);
    event AccessApproved(address indexed doctor, address indexed patient, string recordId, uint256 timestamp);
    event AccessDenied(address indexed doctor, address indexed patient, string recordId, uint256 timestamp);
    event RecordCreated(string recordId, address indexed requestor);
    event AccessRevoked(address indexed doctor, address indexed patient, string recordId, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function resetSyncPointer() external {
        syncPointer = 0;
    }

    function doctorRequestAccess(address doctor, address patient, string memory doctorId, string memory recordId) external {
        AccessRequest storage existing = accessRequests[doctor][recordId];
        if (existing.timestamp != 0) {
            revert RequestAlreadyExists(recordId);
        }

        AccessRequest memory newRequest = AccessRequest({
            doctorAddress: doctor,
            patientAddress: patient,
            doctorMedplumId: doctorId,
            recordId: recordId,
            timestamp: block.timestamp,
            status: RequestStatus.Pending
        });

        accessRequests[doctor][recordId] = newRequest;
        accessRequestsList.push(newRequest);

        emit AccessRequested(doctor, patient, recordId, block.timestamp);
    }

    function approveAccess(address doctor, string memory recordId) external {
        AccessRequest storage request = accessRequests[doctor][recordId];
        if (request.patientAddress != msg.sender) {
            revert OnlyPatientCanApprove();
        }
        if (request.status != RequestStatus.Pending) {
            revert RequestAlreadyProcessed();
        }

        request.status = RequestStatus.Approved;
        // Also update the access list for the record
        // Update the status in the accessRequestsList as well
        for (uint256 i = 0; i < accessRequestsList.length; i++) {
            if (
            accessRequestsList[i].doctorAddress == doctor &&
            keccak256(abi.encodePacked(accessRequestsList[i].recordId)) == keccak256(abi.encodePacked(recordId)) &&
            accessRequestsList[i].patientAddress == msg.sender
            ) {
            accessRequestsList[i].status = RequestStatus.Approved;
            break;
            }
        }

        accessLogs.push(MedicalAccessLog({
            doctor: doctor,
            patient: msg.sender,
            recordId: recordId,
            timestamp: block.timestamp
        }));

        emit AccessApproved(doctor, msg.sender, recordId, block.timestamp);
    }

    function denyAccess(address doctor, string memory recordId) external {
        AccessRequest storage request = accessRequests[doctor][recordId];
        if (request.patientAddress != msg.sender) {
            revert OnlyPatientCanDeny();
        }
        if (request.status != RequestStatus.Pending) {
            revert RequestAlreadyProcessed();
        }

        //request.status = RequestStatus.Denied;
        // Delete the request instead of marking as Denied
        delete accessRequests[doctor][recordId];
        // Remove from the accessRequestsList
        deleteRecordFromAccessRequestsList(request);

        emit AccessDenied(doctor, msg.sender, recordId, block.timestamp);
    }

    function revokeAccess(address doctor, string memory recordId) external {
        AccessRequest storage request = accessRequests[doctor][recordId];
        if (request.patientAddress != msg.sender) {
            revert OnlyPatientCanDeny();
        }
        if (request.status == RequestStatus.Approved) {
            delete accessRequests[doctor][recordId];
            // Remove from the accessRequestsList
            deleteRecordFromAccessRequestsList(request);
            emit AccessRevoked(doctor, msg.sender, recordId, block.timestamp);
        } else {
            revert AccessWasNotApproved();
        }

        emit AccessDenied(doctor, msg.sender, recordId, block.timestamp);
    }

    function deleteRecordFromAccessRequestsList(AccessRequest memory request) internal {
        for (uint256 i = 0; i < accessRequestsList.length; i++) {
            if (keccak256(abi.encodePacked(accessRequestsList[i].recordId)) == keccak256(abi.encodePacked(request.recordId)) &&
                accessRequestsList[i].doctorAddress == request.doctorAddress &&
                accessRequestsList[i].patientAddress == request.patientAddress) {
                accessRequestsList[i] = accessRequestsList[accessRequestsList.length - 1];
                accessRequestsList.pop();
                break;
            }
        }
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

    function createRecord(string memory recordId, string memory hash) public {
        Record storage newRecord = records[recordId];
        newRecord.requestor = msg.sender;
        newRecord.hash = hash;
        newRecord.version = "xyz";
        newRecord.lastUpdated = block.timestamp;
        recordExistsMap[recordId] = true;

        emit RecordCreated(recordId, msg.sender);
    }

    function getPatientAccessRequests() external view returns (AccessRequest[] memory) {
        uint256 total = 0;

        // First pass: count the number of requests for msg.sender
        for (uint256 i = 0; i < accessRequestsList.length; i++) {
            if (accessRequestsList[i].patientAddress == msg.sender) {
                total++;
            }
        }

        // Second pass: collect them
        AccessRequest[] memory result = new AccessRequest[](total);
        uint256 index = 0;
        for (uint256 i = 0; i < accessRequestsList.length; i++) {
            if (accessRequestsList[i].patientAddress == msg.sender) {
                result[index] = accessRequestsList[i];
                index++;
            }
        }

        return result;
    }

}