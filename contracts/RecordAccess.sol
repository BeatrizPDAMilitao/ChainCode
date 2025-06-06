// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract RecordAccessContract {

    error AccessAlreadyExists(string accessId);

    struct RecordAccess {
        address requester;
        string[] recordIds;
        uint256 timestamp;
    }

    mapping(string => RecordAccess) private accesses;
    mapping(string => bool) private accessExistsMap;


    event RecordAccessed(
        string accessId,
        address indexed requester,
        string[] recordIds,
        uint256 timestamp
    );

    function logAccess(string[] memory recordIds, string memory accessId) public {
        //if (accessExistsMap[accessId]) {
        //    revert AccessAlreadyExists(accessId);
        //}

        RecordAccess memory newAccess = RecordAccess({
            requester: msg.sender,
            recordIds: recordIds,
            timestamp: block.timestamp
        });
        accesses[accessId] = newAccess;
        accessExistsMap[accessId] = true;

        emit RecordAccessed(accessId, msg.sender, recordIds, block.timestamp);
    }
}