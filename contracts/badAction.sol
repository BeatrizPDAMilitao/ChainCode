// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct BadAction {
    string identity;
    string reason;
    // docType field is omitted since it's redundant in Solidity
}
