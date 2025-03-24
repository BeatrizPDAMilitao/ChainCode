// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./record.sol";
import "./access.sol";
import "./badAction.sol";

contract MedskyContract {

    mapping(string => Record) private records;
    mapping(string => bool) private recordExistsMap;

    mapping(string => Access) private accesses;
    mapping(string => bool) private accessExistsMap;

    mapping(string => BadAction) private badActions;

    // Events
    event RecordCreated(string recordId, address indexed requestor);
    event RecordsCreated(string[] recordIds, address indexed requestor);
    event RecordDeleted(string recordId, address indexed requestor);
    event AccessLogged(string accessId, address indexed requestor, string[] recordIds);
    event BadActionLogged(string badActionId, string identity, string reason);

    function accessExists(string memory accessId) public view returns (bool) {
        return accessExistsMap[accessId];
    }

    function readAccesses(string[] memory accessIds) public view returns (Access[] memory) {
        Access[] memory result = new Access[](accessIds.length);
        for (uint i = 0; i < accessIds.length; i++) {
            if (accessExistsMap[accessIds[i]]) {
                result[i] = accesses[accessIds[i]];
            }
        }
        return result;
    }

    function logAccess(string[] memory recordIds, string memory accessId) public {
        require(!accessExistsMap[accessId], "Access already exists");

        Access storage newAccess = accesses[accessId];
        newAccess.requestor = msg.sender;
        newAccess.recordIDs = recordIds;
        newAccess.timestamp = block.timestamp;
        accessExistsMap[accessId] = true;

        emit AccessLogged(accessId, msg.sender, recordIds);
    }

    function recordExists(string memory recordId) public view returns (bool) {
        return recordExistsMap[recordId];
    }

    function readRecordsTx(string[] memory recordIds, string memory accessId) public returns (Record[] memory) {
        Record[] memory result = new Record[](recordIds.length);
        for (uint i = 0; i < recordIds.length; i++) {
            if (recordExistsMap[recordIds[i]]) {
                result[i] = records[recordIds[i]];
            }
        }
        logAccess(recordIds, accessId);
        return result;
    }

    function readRecordTx(string memory recordId, string memory accessId) public returns (Record memory) {
        require(recordExistsMap[recordId], "Record does not exist");

        string[] memory temp = new string[](1);
        temp[0] = recordId;
        logAccess(temp, accessId);

        return records[recordId];
    }

    function readRecords(string[] memory recordIds) public view returns (Record[] memory) {
        Record[] memory result = new Record[](recordIds.length);
        for (uint i = 0; i < recordIds.length; i++) {
            if (recordExistsMap[recordIds[i]]) {
                result[i] = records[recordIds[i]];
            }
        }
        return result;
    }

    function createRecords(string[] memory recordIds, string[] memory hashes) public {
        require(recordIds.length == hashes.length, "Mismatched array lengths");

        for (uint i = 0; i < recordIds.length; i++) {
            Record storage newRecord = records[recordIds[i]];
            newRecord.requestor = msg.sender;
            newRecord.hash = hashes[i];
            newRecord.version = "xyz";
            newRecord.lastUpdated = block.timestamp;
            recordExistsMap[recordIds[i]] = true;
        }

        emit RecordsCreated(recordIds, msg.sender);
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

    function deleteRecord(string memory recordId, string memory actionId) public {
        require(recordExistsMap[recordId], "Record does not exist");

        string[] memory temp = new string[](1);
        temp[0] = recordId;
        logAccess(temp, actionId);

        delete records[recordId];
        recordExistsMap[recordId] = false;

        emit RecordDeleted(recordId, msg.sender);
    }

    function logBadAction(string memory badActionId, string memory identity, string memory reason) public {
        BadAction storage action = badActions[badActionId];
        action.identity = identity;
        action.reason = reason;

        emit BadActionLogged(badActionId, identity, reason);
    }
}