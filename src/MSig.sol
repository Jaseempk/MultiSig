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
error MSig__InsufficientNumApprovals();

// MSig is a Multi-Signature Wallet Contract.
// It allows a group of owners to collectively approve transactions before execution.
// Design Choice: The contract leverages the OpenZeppelin ECDSA library for signature verification.
// This provides security and reliability, as the library is well-tested and standard in the Ethereum community.
contract MSig is Ownable {
    using ECDSA for bytes32;

    mapping(address => bool) public isOwner;
    mapping(uint => mapping(address => bool)) public approved;
    mapping(uint256 => Transaction) public transactionss;

    //state variables
    uint public immutable i_required;


    Transaction[] public transactions;
    address[] public owners;

    // Transaction struct: Holds the details of each transaction.
    // Design Choice: A struct is used to group transaction-related data,
    // improving data management and readability.
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

    /// @notice Ensures the function is called by a wallet owner
    modifier onlyWalletOwner() {
        if(!isOwner[msg.sender]) revert MSig__OnlyWalletOwnersCanAccess();
        _;
    }

    /// @notice Ensures the specified owner does not already exist in the wallet
    /// @param owner The address to check
    modifier ownerShouldntExist(address owner) {
        if(isOwner[owner]) revert MSig__OwnerAlreadyExists();
        _;
    }

    /// @notice Ensures the specified owner exists in the wallet
    /// @param owner The address to check
    modifier ownerExists(address owner) {
        if(!isOwner[owner]) revert MSig__OwnerDoesntExist();
        _;
    }

    /// @notice Ensures the transaction at the specified index exists
    /// @param _txIndex The index of the transaction to check
    modifier txExists(uint _txIndex) {
        if(_txIndex >= transactions.length) revert MSig__InvalidTransaction();
        _;
    }

    /// @notice Ensures the transaction at the specified index has not been approved by the sender
    /// @param _txIndex The index of the transaction to check
    modifier notApproved(uint _txIndex) {
        if(approved[_txIndex][msg.sender]) revert MSig__TransactionAlreadyApproved();
        _;
    }

    /// @notice Ensures the transaction at the specified index has not been executed
    /// @param _txIndex The index of the transaction to check
    modifier notExecuted(uint _txIndex) {
        if(transactions[_txIndex].executed) revert MSig__TransactionAlreadyExecuted();
        _;
    }


    // Constructor to initialize the Multi-Signature Wallet.
    // Design Choice: The constructor sets up initial owners and the required number of approvals.
    // This setup is immutable, enhancing security by preventing post-deployment changes.
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

    /// @notice Adds a new owner to the multi-signature wallet
    /// @dev Only the contract owner can add new owners and the new owner must not already be an owner
    /// @param owner The address of the new owner to be added
    /// @custom:modifiers onlyOwner, ownerShouldntExist
    function addOwner(address owner)
        public
        onlyOwner
        ownerShouldntExist(owner)
    {
        isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAddition(owner);
    }

    /// @notice Removes an existing owner from the multi-signature wallet
    /// @dev Only the contract owner can remove owners and the owner to be removed must exist
    /// @param owner The address of the owner to be removed
    /// @custom:modifiers onlyOwner, ownerExists
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

    /// @notice Replaces an existing owner with a new owner
    /// @dev Only the contract owner can replace owners, the old owner must exist and the new owner must not already be an owner
    /// @param oldOwner The address of the owner to be replaced
    /// @param newOwner The address of the new owner to replace the old one
    /// @custom:modifiers onlyOwner, ownerExists, ownerShouldntExist
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

    /// @notice Submits a new transaction to the multi-signature wallet
    /// @dev Can only be called by a wallet owner; transaction is not executed until approved
    /// @param _destination The address to which the transaction will be sent
    /// @param _value The amount of Ether (in wei) to be sent
    /// @param _data The data payload of the transaction
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

    /// @notice Approves a transaction proposed in the multi-signature wallet
    /// @dev Can only be called by a wallet owner; a transaction must exist and not already be executed or approved by the caller
    /// @param _txIndex The index of the transaction in the transactions array to approve
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

    /// @notice Revokes approval for a transaction proposed in the multi-signature wallet
    /// @dev Can only be called by a wallet owner; a transaction must exist, not be executed, and be previously approved by the caller
    /// @param _txIndex The index of the transaction in the transactions array to revoke approval
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

    /// @notice Executes a transaction if it has the required number of approvals
    /// @param _txIndex The index of the transaction in the transactions array
    /// @param signatures An array of signatures from the owners
    /// @dev Design Choice: Requires signatures to be verified before executing the transaction.
    /// This adds an extra layer of security by ensuring that only transactions approved by owners are executed.
    function executeTransaction(uint _txIndex,bytes[] memory signatures)
        public
        onlyWalletOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        if(transaction.approvalsCount < i_required)revert MSig__InsufficientNumApprovals();
        if(signatures.length< i_required) revert MSig__InsufficientSignatureCount();

        bytes32 txHash=getTransactionHash(_txIndex);

        address lastSigner=address(0);
        uint8 validSignatures=0;

        for(uint i=0;i<signatures.length;i++){
            address recovered=txHash.recover(signatures[i]);
            if(recovered==lastSigner) revert MSig__SigManipulationDetected();
            lastSigner=recovered;

            if(isOwner[recovered] && approved[_txIndex][recovered]){
                validSignatures+=1;
            }
        }

        if(validSignatures<i_required) revert MSig__InsufficientValidSignatureCount();

        transaction.executed = true;
        (bool success, ) = transaction.destination.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit TransactionExecuted(_txIndex,transaction.value,transaction.data);
    }



    //View functions

    /// @notice Creates a hash of the transaction details
    /// @dev This function generates a hash used for off-chain signing and on-chain verification
    /// @param _txIndex The index of the transaction in the transactions array
    /// @return The keccak256 hash of the transaction details
    /// @dev Design Choice: The hash includes the contract address, txIndex ,transaction data,transaction value, and destination.
    /// This ensures uniqueness and prevents replay attacks across different contracts or transactions.
    function getTransactionHash(uint _txIndex)public view returns(bytes32){
        Transaction storage transaction=transactions[_txIndex];
        bytes32 txHash=keccak256(abi.encodePacked(address(this),_txIndex,transaction.value,transaction.data,transaction.destination));
        return txHash;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

}
