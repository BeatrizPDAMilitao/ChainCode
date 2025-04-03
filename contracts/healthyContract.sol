// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MedicalRecordAccess {
    enum AccessStatus { Pending, Approved, Denied }

    struct AccessRequest {
        address requester;
        uint256 timestamp;
        AccessStatus status;
    }

    struct MedicalAccessLog {
        address doctor;
        address patient;
        string recordType; // e.g., "MRI", "X-Ray"
        uint256 timestamp;
    }

    address public owner;
    mapping(bytes32 => AccessRequest) public accessRequests;
    mapping(string => address[]) public recordAccessList;
    MedicalAccessLog[] public accessLogs;
    uint256 public syncPointer = 0; // Points to next unread access
    uint256 public constant SYNC_BATCH_SIZE = 3;

    event AccessRequested(string indexed recordId, address indexed requester, uint256 timestamp);
    event AccessApproved(string indexed recordId, address indexed requester);
    event AccessDenied(string indexed recordId, address indexed requester);
    event RecordAccessed(address indexed doctor, address indexed patient, string recordType, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this");
        _;
    }

    constructor() {
        owner = msg.sender;
        _generateSampleAccessLogs();
    }

    function resetSyncPointer() external onlyOwner {
        syncPointer = 0;
    }

    function requestAccess(string memory recordId) external {
        bytes32 requestKey = keccak256(abi.encodePacked(recordId, msg.sender));
        AccessRequest storage request = accessRequests[requestKey];

        require(request.status == AccessStatus.Pending || request.status == AccessStatus(0), "Already requested");

        accessRequests[requestKey] = AccessRequest({
            requester: msg.sender,
            timestamp: block.timestamp,
            status: AccessStatus.Pending
        });

        emit AccessRequested(recordId, msg.sender, block.timestamp);
    }

    function approveAccess(string memory recordId, address requester) external onlyOwner {
        bytes32 requestKey = keccak256(abi.encodePacked(recordId, requester));
        AccessRequest storage request = accessRequests[requestKey];

        require(request.status == AccessStatus.Pending, "Request not pending");

        request.status = AccessStatus.Approved;
        recordAccessList[recordId].push(requester);

        emit AccessApproved(recordId, requester);
    }

    function denyAccess(string memory recordId, address requester) external onlyOwner {
        bytes32 requestKey = keccak256(abi.encodePacked(recordId, requester));
        AccessRequest storage request = accessRequests[requestKey];

        require(request.status == AccessStatus.Pending, "Request not pending");

        request.status = AccessStatus.Denied;

        emit AccessDenied(recordId, requester);
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

    function getRequestStatus(string memory recordId, address requester) external view returns (AccessStatus) {
        bytes32 requestKey = keccak256(abi.encodePacked(recordId, requester));
        return accessRequests[requestKey].status;
    }

    function logAccess(address doctor, address patient, string memory recordType) external onlyOwner {
        accessLogs.push(MedicalAccessLog({
            doctor: doctor,
            patient: patient,
            recordType: recordType,
            timestamp: block.timestamp
        }));

        emit RecordAccessed(doctor, patient, recordType, block.timestamp);
    }

    function getAccessLogs() external view returns (MedicalAccessLog[] memory) {
        return accessLogs;
    }

    // Moves the pointer forward
    function getNextAccessLogs() external {
        uint256 remaining = accessLogs.length - syncPointer;
        uint256 count = remaining < SYNC_BATCH_SIZE ? remaining : SYNC_BATCH_SIZE;
        syncPointer += count;
    }

    // View function to inspect logs at the current pointer
    function previewNextAccessLogs() external view returns (MedicalAccessLog[] memory) {
        uint256 remaining = accessLogs.length - syncPointer;
        uint256 count = remaining < SYNC_BATCH_SIZE ? remaining : SYNC_BATCH_SIZE;

        MedicalAccessLog[] memory result = new MedicalAccessLog[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = accessLogs[syncPointer + i];
        }

        return result;
    }


    function _generateSampleAccessLogs() internal {
        for (uint256 i = 0; i < 100; i++) {
            address doctor = address(uint160(uint256(keccak256(abi.encodePacked("doctor", i)))));
            address patient = address(uint160(uint256(keccak256(abi.encodePacked("patient", i)))));
            string memory recordType = i % 2 == 0 ? "MRI" : "X-Ray";

            accessLogs.push(MedicalAccessLog({
                doctor: doctor,
                patient: patient,
                recordType: recordType,
                timestamp: block.timestamp - (i * 1 days)
            }));
        }
    }
}
