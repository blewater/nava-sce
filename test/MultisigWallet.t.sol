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

    function setUp() public {
        wallet = new MultisigWallet(owners, TwoOfThree);
        vm.deal(address(wallet), 10 ether);
    }

    function testMultisigWallet() public {
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
}