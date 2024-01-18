// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions



// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


//Errors
error MSig__InsufficientSignatureCount();
error MSig__SigManipulationDetected();
error MSig__InsufficientValidSignatureCount();
error MSig__OnlyWalletOwnersCanAccess();
error MSig__OwnerAlreadyExists();
error MSig__OwnerDoesntExist();
error MSig__InvalidTransaction();
error MSig__TransactionAlreadyApproved();
error MSig__TransactionAlreadyExecuted();
error MSig__TransactionNotApproved();


contract MSig is Ownable {
    using ECDSA for bytes32;

    mapping(address => bool) public isOwner;
    mapping(uint => mapping(address => bool)) public approved;
    mapping(uint256 => Transaction) public transactionss;

    uint public immutable i_required;


    Transaction[] public transactions;
    address[] public owners;

    struct Transaction {
        address destination;
        uint value;
        bytes data;
        bool executed;
        uint256 approvalsCount;
    }


    //Events
    event Deposit(address indexed sender, uint amount);
    event TransactionSubmitted(uint indexed txIndex,address destination,uint value,bytes data,bool executed,uint256 approvalsCount);
    event TransactionApproval(address indexed owner, uint indexed txIndex);
    event Revocation(address indexed owner, uint indexed txIndex);
    event TransactionExecuted(uint indexed txIndex,uint256 value,bytes data);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint required);


    //Modifiers
    modifier onlyWalletOwner() {
        if(!isOwner[msg.sender]) revert MSig__OnlyWalletOwnersCanAccess();
        _;
    }
    modifier ownerShouldntExist(address owner) {
        if(isOwner[owner]) revert MSig__OwnerAlreadyExists();
        _;
    }

    modifier ownerExists(address owner) {
        if(!isOwner[owner]) revert MSig__OwnerDoesntExist();
        _;
    }

    modifier txExists(uint _txIndex) {
        if(_txIndex > transactions.length) revert MSig__InvalidTransaction();
        _;
    }

    modifier notApproved(uint _txIndex) {
        if(approved[_txIndex][msg.sender]) revert MSig__TransactionAlreadyApproved();
        _;
    }

    modifier notExecuted(uint _txIndex) {
        if(transactions[_txIndex].executed) revert MSig__TransactionAlreadyExecuted();
        _;
    }

    constructor(address[] memory _owners, uint _required)Ownable(msg.sender) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid number of required approvals");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        i_required = _required;
    }


    function addOwner(address owner)
        public
        onlyOwner
        ownerShouldntExist(owner)
    {
        isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAddition(owner);
    }

    function removeOwner(address owner)
        public
        onlyOwner
        ownerExists(owner)
    {
        isOwner[owner] = false;
        for (uint i = 0; i < owners.length - 1; i++)
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        owners.pop();
        emit OwnerRemoval(owner);
    }

    function replaceOwner(address oldOwner, address newOwner)
        public
        onlyOwner
        ownerExists(oldOwner)
        ownerShouldntExist(newOwner)
    {
        for (uint i = 0; i < owners.length; i++)
            if (owners[i] == oldOwner) {
                owners[i] = newOwner;
                break;
            }
        isOwner[oldOwner] = false;
        isOwner[newOwner] = true;
        emit OwnerRemoval(oldOwner);
        emit OwnerAddition(newOwner);
    }

    /**
     * 
    function changeRequirement(uint _required)
        public
        onlyOwner
    {
        require(_required > 0 && _required <= owners.length, "Invalid required number of owners");
        i_required = _required;
        emit RequirementChange(_required);
    }

     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address _destination, uint _value, bytes memory _data)
        public
        onlyWalletOwner
    {
        uint txIndex = transactions.length;

        transactions.push(Transaction({
            destination: _destination,
            value: _value,
            data: _data,
            executed: false,
            approvalsCount: 0
        }));

        emit TransactionSubmitted(txIndex,_destination,_value,_data,false,0);
    }

    function approveTransaction(uint _txIndex)
        public
        onlyWalletOwner
        txExists(_txIndex)
        notApproved(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        approved[_txIndex][msg.sender] = true;        
        transaction.approvalsCount += 1;

        emit TransactionApproval(msg.sender, _txIndex);
    }

    function executeTransaction(uint _txIndex,bytes[] memory signatures)
        public
        onlyWalletOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.approvalsCount >= i_required, "Insufficient approvals");
        if(signatures.length< i_required) revert MSig__InsufficientSignatureCount();

        bytes32 txHash=getTransactionHash(_txIndex);

        address lastSigner=address(0);
        uint8 validSignatures=0;

        for(uint i=0;i<signatures.length;i++){
            address recovered=txHash.recover(signatures[i]);
            if(recovered==lastSigner) revert MSig__SigManipulationDetected();
            recovered=lastSigner;

            if(isOwner[recovered] && !approved[_txIndex][recovered]){
                approved[_txIndex][recovered]=true;
                validSignatures+=1;
            }
        }

        if(validSignatures<i_required) revert MSig__InsufficientValidSignatureCount();

        transaction.executed = true;
        (bool success, ) = transaction.destination.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit TransactionExecuted(_txIndex,transaction.value,transaction.data);
    }

    function revokeApproval(uint _txIndex)
        public
        onlyWalletOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        if(!approved[_txIndex][msg.sender]) revert MSig__TransactionNotApproved();
        Transaction storage transaction = transactions[_txIndex];
        approved[_txIndex][msg.sender] = false;
        transaction.approvalsCount -= 1;

        emit Revocation(msg.sender, _txIndex);
    }

    //View functions
    function getTransactionHash(uint _txIndex)public view returns(bytes32){
        Transaction storage transaction=transactions[_txIndex];
        bytes32 txHash=keccak256(abi.encodePacked(address(this),transaction.data,transaction.destination));
        return txHash;
    }


}
