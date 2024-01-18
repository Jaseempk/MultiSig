// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MSig.sol";

contract MSigTest is Test {
    MSig private multiSigWallet;
    address[] private owners;

    function setUp() public {
        owners.push(address(0xAAA)); // Dummy addresses
        owners.push(address(0xBBB));
        owners.push(address(0xCCC));
        multiSigWallet = new MSig(owners, 2); // 2 signatures required
        // Transfer ownership of MSig contract to a dummy address for testing
        multiSigWallet.transferOwnership(address(0xDDD));
    }

    function testInitialSetup() public {
        // Test initial setup
        for (uint i = 0; i < owners.length; i++) {
            assertTrue(multiSigWallet.isOwner(owners[i]));
        }
        assertEq(multiSigWallet.i_required(), 2);
    }

    function testAddOwner() public {
        address newOwner = address(0xEEE);
        vm.prank(address(0xDDD)); // Simulate call from contract owner
        multiSigWallet.addOwner(newOwner);

        assertTrue(multiSigWallet.isOwner(newOwner));
    }


    function testFailToAddExistingOwner() public {
        bytes4 customError=bytes4(keccak256("MSig__OwnerAlreadyExists()"));
        vm.startPrank(address(0xDDD)); 
        vm.expectRevert(customError); //expects next transaction to revert
        multiSigWallet.addOwner(address(0xAAA)); // Existing owner
        vm.stopPrank();
    }

    function testRemoveOwner() public {
        vm.prank(address(0xDDD)); 
        multiSigWallet.removeOwner(address(0xAAA));

        assertFalse(multiSigWallet.isOwner(address(0xAAA))); //checking whether address(0xAAA) was removed
    }

    function testReplaceOwner() public {
        address newOwner = address(0xFFF);
        vm.prank(address(0xDDD)); 
        multiSigWallet.replaceOwner(address(0xAAA), newOwner); //replacing 0xAAA's ownership with newOwner

        assertFalse(multiSigWallet.isOwner(address(0xAAA))); //it should assert to false after switching the ownership
        assertTrue(multiSigWallet.isOwner(newOwner));
    }

    // Test submission of a transaction
    function testSubmitTransaction() public {
        address to = address(0x111);
        uint value = 1 ether;
        bytes memory data = "";

        vm.prank(address(0xAAA)); 
        multiSigWallet.submitTransaction(to, value, data);

        // Check the state of the submitted transaction
        (address dest, uint val, bytes memory dat, bool executed, uint256 count) = multiSigWallet.transactions(0); //accessing each member of Transaction struct stored in transactions array
        assertEq(dest, to);
        assertEq(val, value);
        assertEq(dat, data);
        assertFalse(executed);
        assertEq(count, 0);
    }

    // Test approval of a transaction
    function testApproveTransaction() public {
        testSubmitTransaction(); // First submit a transaction

        vm.prank(address(0xAAA)); 
        multiSigWallet.approveTransaction(0);

        (, , , , uint256 count) = multiSigWallet.transactions(0);
        assertEq(count, 1);
    }

    // Test execution of a transaction
    /**
     * 
    function testExecuteTransaction() public {
        testApproveTransaction(); // First approve a transaction

        // Approve from another owner
        vm.prank(address(0xBBB)); 
        multiSigWallet.approveTransaction(0);

        vm.prank(address(0xAAA)); 
        multiSigWallet.executeTransaction(0, new bytes[](0)); // Empty signatures for simplicity

        (, , , bool executed, ) = multiSigWallet.transactions(0);
        assertTrue(executed);
    }
     */

    // Add more tests here for revokeApproval, changeRequirement, edge cases, and failure modes
}
