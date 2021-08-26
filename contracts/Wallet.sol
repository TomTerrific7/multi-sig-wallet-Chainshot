// SPDX-License-Identifier: MIT
pragma solidity ^0.7.5;

import "hardhat/console.sol";

contract MultiSig {
    address[] public owners;
    uint public required;
    uint public transactionCount;

    struct Transaction {
        address destination;
        uint value;
        bool executed;
        bytes data; // accept calldata
    }

    mapping(uint => Transaction) public transactions;
    mapping(uint => mapping(address => bool)) public confirmations;

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length != 0);
        require(0 < _required && _required <= _owners.length);    
        owners = _owners;
        required = _required;  
    }

    

    receive() external payable {}
    
    function addTransaction(address _destination, uint _value, bytes memory _data) internal returns(uint) {
        uint idTx = transactionCount;
        transactions[idTx].destination = _destination;
        transactions[idTx].value = _value;
        transactions[idTx].executed = false;
        transactions[idTx].data = _data;
        transactionCount++;
        return idTx;
    }

    // pending - this transaction has not be executed 
    // executed - this transaction has been executed 

    // how many transactions are both pending and executed 
    // getTransactionCount(true, true) -> all transaction count
    // getTransactionCount(true, false) -> non-executed transaction count
    // getTransactionCount(false, true) -> executed transaction count
    function getTransactionCount(bool pending, bool executed) view public returns(uint count) {
        for(uint i = 0; i < transactionCount; i++) {
            if(pending && !transactions[i].executed) count++;
            if(executed && transactions[i].executed) count++;
        }
    }

    function getOwners() view external returns(address[] memory) {
        return owners;
    }

    // getTransactionCount(true, true) -> [all transaction ids]
    // getTransactionCount(true, false) -> [non-executed transaction ids] 
    // getTransactionCount(false, true) -> [executed transaction ids]
    function getTransactionIds(bool pending, bool executed) view external returns(uint[] memory) {
        uint[] memory transactionIds = new uint[](getTransactionCount(pending, executed));

        uint slot;

        for(uint i = 0; i < transactionCount; i++) {
            if(pending && !transactions[i].executed || executed && transactions[i].executed) {
                transactionIds[slot] = i;
                slot++;
            }
        }
        
        return transactionIds;
    }

    function submitTransaction(address _destination, uint _value, bytes memory _data) external {
        confirmTransaction(addTransaction(_destination, _value, _data));
        // confirm the transaction 
    }

    function getConfirmationsCount(uint transactionId) public view returns(uint confirmsCount) {
        for (uint i = 0; i < owners.length; i++) {
            if ( confirmations[transactionId][owners[i]] == true ){
                confirmsCount++;
            } 
        }
    }

    function getConfirmations(uint transactionId) external view returns(address[] memory) {
        address[] memory confirmed = new address[](getConfirmationsCount(transactionId));
        uint k = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]){
                confirmed[k] = owners[i];
                k++;
            }
        }
        return confirmed;
    }

    function isConfirmed(uint transactionId) public view returns(bool) {
        return getConfirmationsCount(transactionId) >= required;
    }

    function confirmTransaction(uint transactionId) public onlyOwners {
        confirmations[transactionId][msg.sender] = true;
        if (isConfirmed(transactionId)) {
            executeTransaction(transactionId);
        }
    }

    function executeTransaction(uint transactionId) public  {
        require(isConfirmed(transactionId));

        Transaction storage _tx = transactions[transactionId];
        
        // being able to send ether AND pass call data 
        (bool success, ) = _tx.destination.call{ value: _tx.value }(_tx.data);
        require(success);

        transactions[transactionId].executed = true;
    }
    
    modifier onlyOwners {
        bool isFound;
        for(uint i = 0; i < owners.length; i++) {
            if(owners[i] == msg.sender) {
                isFound = true;
            }
        }
        require(isFound);
        _;
    }

}
