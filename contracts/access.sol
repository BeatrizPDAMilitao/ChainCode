// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct Access {
    address requestor;
    string[] recordIDs;
    uint256 timestamp;
}
