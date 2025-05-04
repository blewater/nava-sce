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
 * `n` - number of required approvals
 * `m` - number of owners
 */
contract MultisigWallet is ReentrancyGuard {
    /*
     * Custom errors
     */
    error NotOwner(address sender);
    error NotEnoughApprovals(uint256 nonce, uint256 approvals, uint256 requiredApprovals);
    error InvalidRequiredApprovals(uint256 requiredApprovals, uint256 ownerCount);
    error NoOwners();
    error ZeroAddressOwner();
    error OwnerAlreadyExists(address owner);
    error ZeroAddressRecipient();
    error TransactionAlreadyExecuted(uint256 nonce);
    error InvalidTransactionNonce(uint256 nonce);
    error TransferFailed();

    /*
     * Events
     */
    event OwnerAdded(address indexed owner);
    event Deposit(address indexed sender, uint256 amount);
    event ProposedTransaction(uint256 indexed nonce, address indexed proposer, address indexed to, uint256 value);
    event ApprovedTransaction(uint256 indexed nonce, address indexed approver);
    event AlreadyApprovedTransaction(uint256 nonce, address approver);
    event ExecutedTransaction(uint256 indexed nonce, address indexed executor);

    /*
     * Types
     */

    // Transaction: An ETH value transfer transaction to be approved by the multisig wallet.
    struct Transaction {
        address to; // Recipient address
        uint256 value; // Amount of ETH to send
        uint256 approvalCount; // Received approvals
        bool executed; // Whether the transaction has been executed
    }

    /*
     * Storage
     */

    // track owners: address => isOwner
    mapping(address => bool) public isOwner;
    // track approvals: transaction => owner => approval
    mapping(uint256 => mapping(address => bool)) private _trxApprovals;
    uint256 private _ownerCount; // n
    uint256 public requiredApprovals; // of m
    address[] private _owners;
    uint256 public transactionNonce;
    // track transactions: txNonce => Transaction
    mapping(uint256 => Transaction) public transactions;

    /*
     * Modifiers
     */
    modifier onlyOwner() {
        if (!isOwner[msg.sender]) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    /**
     * Initializes the multisig wallet with a list of owners and a required approval threshold.
     * @param owners Array of owner addresses.
     * @param newRequiredApprovals Number of approvals required to execute a transaction.
     */
    constructor(address[] memory owners, uint256 newRequiredApprovals) {
        uint256 ownerCount = owners.length;

        // Validate owner array is not empty
        if (ownerCount == 0) {
            revert NoOwners();
        }

        // Validate required approvals relative to owner count
        if (newRequiredApprovals == 0 || newRequiredApprovals > ownerCount) {
            revert InvalidRequiredApprovals(newRequiredApprovals, ownerCount);
        }

        // Initialize owners and check for duplicates/zero addresses
        for (uint256 i = 0; i < ownerCount; i++) {
            address owner = owners[i];

            if (owner == address(0)) {
                revert ZeroAddressOwner();
            }

            // Add unique owners
            if (!isOwner[owner]) {
                _owners.push(owner);
                isOwner[owner] = true;

                emit OwnerAdded(owner);

                // Unique owner count
                _ownerCount++;
            } else {
                revert OwnerAlreadyExists(owner);
            }
        }

        requiredApprovals = newRequiredApprovals;
    }

    function getOwners() external view returns (address[] memory) {
        return _owners;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * Proposes a new transaction to send ETH.
     * Only callable by an owner.
     * @param to The recipient address.
     * @param value The amount of ETH to send (in wei).
     * @return nonce The ID of the newly proposed transaction.
     */
    function proposeTransaction(address to, uint256 value) external onlyOwner returns (uint256 nonce) {
        // Validate recipient address
        if (to == address(0)) {
            revert ZeroAddressRecipient();
        }

        nonce = transactionNonce;
        transactions[nonce] = Transaction({to: to, value: value, approvalCount: 0, executed: false});
        transactionNonce++;

        emit ProposedTransaction(nonce, msg.sender, to, value);
        return nonce;
    }

    /**
     * Approves a pending transaction.
     * Only callable by an owner. Transaction must exist and not be executed.
     * Owner cannot approve the same transaction twice.
     * @param nonce The ID of the transaction to approve.
     */
    function approveTransaction(uint256 nonce) external onlyOwner {
        if (nonce >= transactionNonce) {
            revert InvalidTransactionNonce(nonce);
        }

        // Check if the owner has already approved this transaction
        if (_trxApprovals[nonce][msg.sender]) {
            emit AlreadyApprovedTransaction(nonce, msg.sender);
            return;
        }

        Transaction storage transaction = transactions[nonce];

        // Check if transaction is already executed
        if (transaction.executed) {
            revert TransactionAlreadyExecuted(nonce);
        }

        // Mark approval
        _trxApprovals[nonce][msg.sender] = true;
        transaction.approvalCount++;

        emit ApprovedTransaction(nonce, msg.sender);
    }

    /**
     * Checks if a specific owner has approved a transaction.
     * @param nonce The ID of the transaction.
     * @param owner The address of the owner to check.
     * @return True if the owner has approved, false otherwise.
     */
    function hasApproved(uint256 nonce, address owner) external view returns (bool) {
        return _trxApprovals[nonce][owner];
    }

    /**
     * Executes a transaction if it has enough approvals.
     * Only callable by an owner.
     * Transaction must exist,
     * Not be already executed,
     * Have sufficient approvals.
     * Contract must have enough ETH balance.
     * @param nonce The ID of the transaction to execute.
     */
    function executeTransaction(uint256 nonce)
        external
        onlyOwner
        nonReentrant // Prevent reentrancy attacks
    {
        // Validate nonce
        if (nonce >= transactionNonce) {
            revert InvalidTransactionNonce(nonce);
        }

        Transaction storage transaction = transactions[nonce];

        // Check if transaction is already executed
        if (transaction.executed) {
            revert TransactionAlreadyExecuted(nonce);
        }

        // Check if the transaction has enough approvals
        if (transaction.approvalCount < requiredApprovals) {
            revert NotEnoughApprovals(nonce, transaction.approvalCount, requiredApprovals);
        }

        // Mark as executed *before* sending ETH (Checks-Effects-Interactions pattern)
        transaction.executed = true;

        // Execute the transaction (send ETH)
        (bool success,) = transaction.to.call{value: transaction.value}("");
        if (!success) {
            // Revert execution status if transfer fails
            transaction.executed = false;
            revert TransferFailed();
        }

        emit ExecutedTransaction(nonce, msg.sender);
    }
}
