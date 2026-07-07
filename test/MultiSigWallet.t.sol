// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.24;

import {MultiSigWallet} from "../src/MultiSigWallet.sol";
import {Test} from "forge-std/Test.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;

    function setUp() public {
        address[] memory owners = new address[](3);
        address alice = makeAddr("ALICE");
        address bob = makeAddr("BOB");
        address carry = makeAddr("CARRY");
        uint256 threshold = 2;

        wallet = new MultiSigWallet(owners, threshold);
    }

}