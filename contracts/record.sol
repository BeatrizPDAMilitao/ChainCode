// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct Record {
    address requestor;
    string hash;
    string version;
    uint256 lastUpdated;
}
