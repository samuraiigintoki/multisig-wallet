// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigWallet {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    Transaction[] public transactions;
    address[] public owners;
    uint256 public threshold;

    mapping(address => bool) public isOwner;

    event SubmitTransaction(
        address indexed owner, uint256 indexed txIndex, address indexed to, uint256 value, bytes data
    );

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

    function submitTransaction(address _to, uint256 _value, bytes calldata _data) external onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(Transaction({to: _to, value: _value, data: _data, executed: false}));

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }
}
