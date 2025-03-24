// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct Access {
    address requestor;
    string[] recordIDs;
    uint256 timestamp;
}
