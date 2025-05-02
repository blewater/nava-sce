// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ReentrancyGuard} from "@openzeppelin-contracts-5.3.0/utils/ReentrancyGuard.sol";

// Requirements:
// 1. The candidate must implement the multisig contract, along with appropriate
// integration/unit testing of the implemented functionality.
// 2. The solution must include, at a minimum, the following features:
// - Allow proposal of transactions (sending ETH to a specified address with a
// specified amount)
// - Allow authorized signers to approve proposed transactions
// - Execute transactions once the required approval threshold is met
// - Provide appropriate event emissions for important state changes

/**
 * @title MultisigWallet: A simple n-of-m multisig Ether wallet.
 * Allows a set of owners to approve transactions and execute them once the required approval threshold is met.
 * `n` - number of owners
 * `m` - number of required approvals
 */
contract MultisigWallet is ReentrancyGuard {

    /*
     * Custom errors
     */
    error NotOwner(address sender);
    error NotEnoughApprovals(uint256 requiredApprovals);
    error InvalidRequiredApprovals(uint256 requiredApprovals, uint256 ownerCount);
    error NoOwners();
    error ZeroAddressOwner();

    /*
     * Events
     */
    event OwnerAdded(address indexed owner);

    /*
     * Storage
     */
    // track owners: address => isOwner
    mapping(address => bool) private _isOwner;
    // track approvals: transaction => owner => approval
    mapping(uint256 => mapping(address => bool)) private _trxApprovals;
    uint256 private _ownerCount; // n
    uint256 private _requiredApprovals; // of m

    /*
     * Modifiers
     */
    modifier onlyOwner() {
        if (!_isOwner[msg.sender]) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    constructor(address[] memory owners, uint256 requiredApprovals) {
        uint256 ownerCount = owners.length;

        // Validate required approvals relative to owner count
        if (requiredApprovals == 0 || requiredApprovals > ownerCount) {
            revert InvalidRequiredApprovals(requiredApprovals, ownerCount);
        }

        // Validate owner array is not empty
        if (ownerCount == 0) {
            revert NoOwners();
        }

        // Initialize owners and check for duplicates/zero addresses
        for (uint256 i = 0; i < ownerCount; i++) {
            address owner = owners[i];
            
            if (owner == address(0)) {
                revert ZeroAddressOwner();
            }
            
            // Add unique owners
            if (!_isOwner[owner]) {
                _isOwner[owner] = true;

                emit OwnerAdded(owner);
                
                // Unique owner count
                _ownerCount++;
            }
        }

        _requiredApprovals = requiredApprovals;
    }
}
