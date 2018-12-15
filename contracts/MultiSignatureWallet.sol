pragma solidity ^0.4.15;

contract MultiSignatureWallet {
    event Submission(uint indexed transactionId);
    event Confirmation(address indexed sender, uint indexed transactionId);
    event ConfirmationRevoked(address indexed sender, uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);

    struct Transaction {
        bool executed;
        address destination;
        uint value;
        bytes data;
    }

    address[] public owners;
    uint public required;
    mapping (address => bool) public isOwner;
    uint public transactionCount;
    mapping (uint => Transaction) public transactions;
    mapping (uint => mapping (address => bool)) public confirmations;

    modifier validRequirement(uint ownerCount, uint _required) {
        if ( _required > ownerCount || _required == 0 || ownerCount == 0) {
            revert("Invalid list of owners and/or number of required confirmations");
        }
        _;
    }

    /// @dev Fallback function, which accepts ether when sent to contract
    function() public payable {}

    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(address[] _owners, uint _required) public validRequirement(_owners.length, _required) {
        for (uint i = 0; i < _owners.length; i++) {
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function submitTransaction(address destination, uint value, bytes data) public returns (uint transactionId) {
        require(isOwner[msg.sender] == true);
        transactionId = addTransaction(destination, value, data);
        confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint transactionId) public {
        require(isOwner[msg.sender] == true);
        require(transactions[transactionId].destination != 0);
        require(confirmations[transactionId][msg.sender] == false);
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId) public {
        require(transactions[transactionId].executed == false);
        require(isOwner[msg.sender] == true);
        require(confirmations[transactionId][msg.sender] == true);
        confirmations[transactionId][msg.sender] = false;
        emit ConfirmationRevoked(msg.sender, transactionId);
    }

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId) public {
        require(transactions[transactionId].executed == false);
        if (isConfirmed(transactionId)) {
            Transaction storage trx = transactions[transactionId];
            trx.executed = true;
            if (trx.destination.call.value(trx.value)(trx.data)) {
                emit Execution(transactionId);
            } else {
                emit ExecutionFailure(transactionId);
                trx.executed = false;
            }
        }
        
    }

    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint transactionId) internal constant returns (bool) {
        uint count = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                count += 1;
            }
            if (count == required) {
                return true;
            }
        }
        return false;
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function addTransaction(address destination, uint value, bytes data) internal returns (uint transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false
        });
        transactionCount += 1;
        emit Submission(transactionId);
    }
}
