// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    Transaction[] public transactions;

    error MultiSigWallet__EmptyOwnersArray();
    error MultiSigWallet__DuplicateOwner();
    error MultiSigWallet__ZeroThreshold();
    error MultiSigWallet__ThresholdTooHigh();

    constructor(address[] memory _owners, uint256 _threshold) {
        // Zero owners check
        if (_owners.length == 0) {
            revert MultiSigWallet__EmptyOwnersArray();
        }

        // Duplicate owner check
        for (uint256 i; i < _owners.length; i++) {
            if (isOwner[_owners[i]]) {
                revert MultiSigWallet__DuplicateOwner();
            } else {
                owners.push(_owners[i]);
                isOwner[_owners[i]] = true;
            }
        }
        // Threshold zero check
        if (_threshold == 0) {
            revert MultiSigWallet__ZeroThreshold();
        }
        // Threshold too high check
        if (_threshold > _owners.length) {
            revert MultiSigWallet__ThresholdTooHigh();
        }
        threshold = _threshold;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    function submitTransaction(address _to, uint256 _value, bytes calldata _data) external onlyOwner {}
}
