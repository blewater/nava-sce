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
    
}