// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import {MultisigWallet} from "../src/MultisigWallet.sol";

contract MultisigWalletTest is Test {

    MultisigWallet wallet;
    uint256 TwoOfThree = 2;

    address owner1 = address(0x1);
    address owner2 = address(0x2);
    address owner3 = address(0x3);
    address[] owners = [owner1, owner2, owner3];
    address recipient = address(0xcafe);

    function setUp() public {
        wallet = new MultisigWallet(owners, TwoOfThree);
        vm.deal(address(wallet), 10 ether);
    }

    // =============================================================
    // Constructor & Deployment Tests
    // =============================================================
    function test_constructor_SetsOwnersCorrectly() public view {
        address[] memory retrievedOwners = wallet.getOwners();
        assertEq(retrievedOwners.length, owners.length, "Owner count mismatch");
        assertEq(retrievedOwners[0], owner1, "Owner 1 mismatch");
        assertEq(retrievedOwners[1], owner2, "Owner 2 mismatch");
        assertEq(retrievedOwners[2], owner3, "Owner 3 mismatch");
        assertTrue(wallet.isOwner(owner1), "Owner 1 not marked");
        assertTrue(wallet.isOwner(owner2), "Owner 2 not marked");
        assertTrue(wallet.isOwner(owner3), "Owner 3 not marked");
        assertFalse(wallet.isOwner(address(0x4)), "Non-owner marked");
    }

    function test_constructor_SetsRequiredApprovalsCorrectly() public view {
        assertEq(wallet.requiredApprovals(), TwoOfThree, "Required approvals mismatch");
    }

    function test_constructor_RevertsIfRequiredApprovalsIsZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                MultisigWallet.InvalidRequiredApprovals.selector,
                0,
                owners.length
            )
        );
        new MultisigWallet(owners, 0);
    }

    function test_constructor_RevertsIfRequiredApprovalsExceedsOwners() public {
        vm.expectRevert(
             abi.encodeWithSelector(
                MultisigWallet.InvalidRequiredApprovals.selector,
                owners.length + 1,
                owners.length
            )
        );
        new MultisigWallet(owners, owners.length + 1);
    }

     function test_constructor_RevertsIfOwnersIsEmpty() public {
        address[] memory emptyOwners;
        vm.expectRevert(MultisigWallet.NoOwners.selector);
        new MultisigWallet(emptyOwners, 1);
    }

    function test_constructor_RevertsIfOwnerIsZeroAddress() public {
        address[] memory ownersWithZero = new address[](2);
        ownersWithZero[0] = owner1;
        ownersWithZero[1] = address(0);
        vm.expectRevert(MultisigWallet.ZeroAddressOwner.selector);
        new MultisigWallet(ownersWithZero, 1);
    }

     function test_constructor_RevertsIfDuplicateOwner() public {
        address[] memory duplicateOwners = new address[](2);
        duplicateOwners[0] = owner1;
        duplicateOwners[1] = owner1; // Duplicate
        vm.expectRevert(
            abi.encodeWithSelector(MultisigWallet.OwnerAlreadyExists.selector, owner1)
        );
        new MultisigWallet(duplicateOwners, 1);
    }

    function test_receive_AcceptsEthAndEmitsEvent() public {
        uint256 depositAmount = 1 ether;
        uint256 initialBalance = address(wallet).balance;

        // Expect Deposit event
        vm.expectEmit(true, true, true, true);
        emit MultisigWallet.Deposit(address(this), depositAmount); // address(this) is the default msg.sender in tests

        // Send ETH to the contract using low-level call
        (bool success, ) = address(wallet).call{value: depositAmount}("");
        assertTrue(success, "ETH transfer failed");

        // Check final balance
        assertEq(address(wallet).balance, initialBalance + depositAmount, "Balance mismatch after deposit");
    }    


    // =============================================================
    // Transaction Proposal Tests
    // =============================================================
    function test_proposeTransaction_Success() public {
        uint256 valueToSend = 1 ether;
        uint256 expectedNonce = 0;


        // Propose as owner1
        // Expect TransactionProposed event
        vm.expectEmit(true, true, true, true);
        emit MultisigWallet.ProposedTransaction(expectedNonce, owner1, recipient, valueToSend);

        vm.prank(owner1);
        uint256 nonce = wallet.proposeTransaction(recipient, valueToSend);

        assertEq(nonce, expectedNonce, "Incorrect nonce returned");
        assertEq(wallet.transactionNonce(), expectedNonce + 1, "Transaction nonce not incremented");

        // Verify transaction details
        (address to, uint256 value, uint256 approvalCount, bool executed) = wallet.transactions(nonce);
        assertEq(to, recipient, "Recipient mismatch");
        assertEq(value, valueToSend, "Value mismatch");
        assertEq(approvalCount, 0, "Approval count should be 0");
        assertEq(executed, false, "Transaction should not be executed");
    }

    function test_proposeTransaction_RevertsIfSenderIsNotOwner() public {
        uint256 valueToSend = 1 ether;

        // Try to propose as non-owner
        address nonOwner = address(0xbaddad);

        vm.expectRevert(abi.encodeWithSelector(MultisigWallet.NotOwner.selector, nonOwner));
        vm.prank(nonOwner);
        wallet.proposeTransaction(recipient, valueToSend);
    }

    function test_proposeTransaction_RevertsIfRecipientIsZeroAddress() public {
        uint256 valueToSend = 1 ether;

        vm.expectRevert(MultisigWallet.ZeroAddressRecipient.selector);
        vm.prank(owner1);
        wallet.proposeTransaction(address(0), valueToSend);
    }

    // =============================================================
    // Transaction Approval Tests
    // =============================================================
    function test_approveTransaction_Success() public {
        uint256 valueToSend = 1 ether;
        vm.prank(owner1);
        uint256 nonce = wallet.proposeTransaction(recipient, valueToSend); // owner1 auto-approves

        // Approve as owner2
        // Expect TransactionApproved event
        vm.expectEmit(true, true, false, true); // nonce, approver
        emit MultisigWallet.ApprovedTransaction(nonce, owner2);

        vm.prank(owner2);
        wallet.approveTransaction(nonce);

        // Verify approval count and status
        (, , uint256 approvalCount, ) = wallet.transactions(nonce); // Get the 3rd element
        assertEq(approvalCount, 1, "Approval count should be 1 after one approval");
        // Use the new hasApproved getter
        assertTrue(wallet.hasApproved(nonce, owner2), "Owner2 approval missing");
    }

     function test_approveTransaction_RevertsIfSenderIsNotOwner() public {
        uint256 valueToSend = 1 ether;
        vm.prank(owner1);
        uint256 nonce = wallet.proposeTransaction(recipient, valueToSend);

        // Try to approve as non-owner
        address nonOwner = address(0xbaddad);
        vm.expectRevert(abi.encodeWithSelector(MultisigWallet.NotOwner.selector, nonOwner));
        vm.prank(nonOwner);
        wallet.approveTransaction(nonce);
    }

    function test_approveTransaction_RevertsIfTransactionDoesNotExist() public {
        uint256 nonExistentnonce = 99;
        vm.prank(owner1);
        vm.expectRevert(
            abi.encodeWithSelector(MultisigWallet.InvalidTransactionNonce.selector, nonExistentnonce)
        );
        wallet.approveTransaction(nonExistentnonce);
    }

     function test_approveTransaction_RevertsIfAlreadyApproved() public {
        uint256 valueToSend = 1 ether;
        vm.prank(owner1);
        uint256 nonce = wallet.proposeTransaction(recipient, valueToSend);
        
        // owner1 approves the transaction first
        vm.startPrank(owner1);
        wallet.approveTransaction(nonce);
        assertTrue(wallet.hasApproved(nonce, owner1), "Owner1 should have approved");

        // owner1 tries to approve again
        vm.expectEmit(true, true, true, true);
        emit MultisigWallet.AlreadyApprovedTransaction(nonce, owner1);
        wallet.approveTransaction(nonce);
    }
}