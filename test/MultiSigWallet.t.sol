// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {MultiSigWallet} from "../src/MultiSigWallet.sol";
import {Test} from "forge-std/Test.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;
    address[] owners;
    address public alice = makeAddr("ALICE");
    address public bob = makeAddr("BOB");
    address public carry = makeAddr("CARRY");
    uint256 public threshold;

    function setUp() public {
        owners = new address[](3);

        threshold = 2;

        owners[0] = alice;
        owners[1] = bob;
        owners[2] = carry;

        wallet = new MultiSigWallet(owners, threshold);
    }

    function test_DeployWithValidOwnersAndThreshold() public view {
        assertEq(wallet.owners(0), alice);
        assertEq(wallet.owners(1), bob);
        assertEq(wallet.owners(2), carry);
        assertEq(wallet.threshold(), threshold);
    }

    function test_RevertOnZeroOwners() public {
        address[] memory noOwners;
        vm.expectRevert(MultiSigWallet.MultiSigWallet__EmptyOwnersArray.selector);
        wallet = new MultiSigWallet(noOwners, threshold);
    }

    function test_RevertOnDuplicateOwner() public {
        address[] memory duplicateOwners = new address[](2);
        duplicateOwners[0] = alice;
        duplicateOwners[1] = alice;
        vm.expectRevert(MultiSigWallet.MultiSigWallet__DuplicateOwner.selector);
        wallet = new MultiSigWallet(duplicateOwners, threshold);
    }

    function test_RevertOnZeroThreshold() public {
        uint256 zeroThreshold = 0;
        vm.expectRevert(MultiSigWallet.MultiSigWallet__ZeroThreshold.selector);
        wallet = new MultiSigWallet(owners, zeroThreshold);
    }

    function test_RevertOnHighThreshold() public {
        uint256 highThreshold = 5;
        vm.expectRevert(MultiSigWallet.MultiSigWallet__ThresholdTooHigh.selector);
        wallet = new MultiSigWallet(owners, highThreshold);
    }

    function test_OwnerCanSubmitTransaction() public {
        address to = makeAddr("RECIEVER");
        uint256 value = 1 ether;
        bytes memory data = "0x";

        vm.prank(alice);
        wallet.submitTransaction(to, value, data);

        (address actualTo, uint256 actualValue, bytes memory actualData, bool actualExecuted) = wallet.transactions(0);

        assertEq(actualTo, to);
        assertEq(actualValue, value);
        assertEq(actualData, data);
        assertEq(actualExecuted, false);
    }

    function test_RevertWhenNonOwnerSubmits() public {
        address nonOwner = makeAddr("NONOWNERADDRESS");
        address to = makeAddr("RECIEVER");
        uint256 value = 1 ether;
        bytes memory data = "0x";

        vm.expectRevert("not owner");

        vm.prank(nonOwner);
        wallet.submitTransaction(to, value, data);
    }

    function test_OwnerConfirmsSubmittedTx() public {
        address to = makeAddr("RECIEVER");
        uint256 value = 1 ether;
        bytes memory data = "0x";

        vm.startPrank(alice);
        wallet.submitTransaction(to, value, data);
        wallet.confirmTransaction(0);
        vm.stopPrank();

        assertEq(wallet.isConfirmed(0, alice), true);
    }

    function test__DuplicateConfirmReverts() public {
        address to = makeAddr("RECIEVER");
        uint256 value = 1 ether;
        bytes memory data = "0x";

        vm.startPrank(alice);
        wallet.submitTransaction(to, value, data);
        wallet.confirmTransaction(0);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__TxAlreadyConfirmed.selector);
        wallet.confirmTransaction(0);
        vm.stopPrank();
    }

    function test_NonOwnerConfirmReverts() public {
        address nonOwner = makeAddr("NONOWNERADDRESS");
        address to = makeAddr("RECIEVER");
        uint256 value = 1 ether;
        bytes memory data = "0x";

        vm.prank(alice);
        wallet.submitTransaction(to, value, data);

        vm.expectRevert("not owner");
        vm.prank(nonOwner);
        wallet.confirmTransaction(0);
    }

    function test_ExecutedTxCannotBeConfirmed() public {
        address to = makeAddr("RECIEVER");
        uint256 value = 1 ether;
        bytes memory data = "0x";

        vm.prank(alice);
        wallet.submitTransaction(to, value, data);

        bytes32 slot = bytes32(uint256(keccak256(abi.encode(uint256(0)))) + 3);

        vm.store(address(wallet), slot, bytes32(uint256(1)));

        vm.expectRevert(MultiSigWallet.MultiSigWallet__TxAlreadyExecuted.selector);
        vm.prank(alice);
        wallet.confirmTransaction(0);
    }

    function test_OwnerCanRevokeAfterConfirming() public {
        address to = makeAddr("RECIEVER");
        uint256 value = 1 ether;
        bytes memory data = "0x";

        vm.startPrank(alice);

        wallet.submitTransaction(to, value, data);
        wallet.confirmTransaction(0);

        assertEq(wallet.isConfirmed(0, alice), true);

        vm.expectEmit(true, true, false, false);
        emit MultiSigWallet.RevokeConfirmation(alice, 0);
        wallet.revokeConfirmation(0);

        assertEq(wallet.isConfirmed(0, alice), false);
        vm.stopPrank();
    }

    function test_NotConfirmedRevokeReverts() public {
        address to = makeAddr("RECIEVER");
        uint256 value = 1 ether;
        bytes memory data = "0x";

        vm.startPrank(alice);
        wallet.submitTransaction(to, value, data);

        vm.expectRevert(MultiSigWallet.MultiSigWallet__TxNotConfirmed.selector);
        wallet.revokeConfirmation(0);
        vm.stopPrank();
    }

    function test_ExecutedTxCannotBeRevoked() public {
        address to = makeAddr("RECIEVER");
        uint256 value = 1 ether;
        bytes memory data = "0x";

        vm.startPrank(alice);
        wallet.submitTransaction(to, value, data);
        wallet.confirmTransaction(0);

        bytes32 slot = bytes32(uint256(keccak256(abi.encode(uint256(0)))) + 3);

        vm.store(address(wallet), slot, bytes32(uint256(1)));

        vm.expectRevert(MultiSigWallet.MultiSigWallet__TxAlreadyExecuted.selector);
        wallet.revokeConfirmation(0);
        vm.stopPrank();
    }

    function test_NonexistentTxRevokeReverts() public {
        vm.expectRevert(MultiSigWallet.MultiSigWallet__TxDoesNotExist.selector);

        vm.prank(alice);
        wallet.revokeConfirmation(0); // Array is empty, index 0 does not exist
    }

    function test_NonOwnerRevokeReverts() public {
        address nonOwner = makeAddr("NONOWNER");
        address to = makeAddr("RECIEVER");
        uint256 value = 1 ether;
        bytes memory data = "0x";

        vm.prank(alice);
        wallet.submitTransaction(to, value, data);

        vm.expectRevert("not owner");
        vm.prank(nonOwner);
        wallet.revokeConfirmation(0);
    }
}
