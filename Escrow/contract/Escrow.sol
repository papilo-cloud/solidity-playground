// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Escrow {
    
    enum Status {
        Pending,
        Complete,
        Refunded
    }

    Status public status;

    struct EscrowTransaction{
        uint256 escrowId;
        address depositor;
        address beneficiary;
        uint256 amount;
        Status status;
    }

    address public owner;
    mapping(uint256 => EscrowTransaction) public escrowtransaction;
    uint256 public escrowCount;

    event EscrowCreated(
        address indexed depositor,
        address indexed beneficiary,
        uint256 indexed escrowId,
        uint256 amount
    );
    event EscrowReleased(
        address indexed depositor,
        address indexed beneficiary,
        uint256 indexed escrowId,
        uint256 amount
    );
    event EscrowRefunded(
        address indexed depositor,
        uint256 indexed escrowId,
        uint256 amount
    );

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    modifier onlyDepositor(uint256 _id) {
        EscrowTransaction storage escrow = escrowtransaction[_id];
        require(msg.sender == escrow.depositor, "Not the depositor");
        _;
    }

    modifier checkIfEscrowExists(uint256 _id) {
        require(_id < escrowCount, "Escrow does not exist");
        _;
    }

    function createEscrow(
        address _beneficiary
    )
        external
        payable
    {
        require(msg.value > 0, "Must send ETH");
        require(_beneficiary > address(0), "Invalid beneficiary address");
        require(_beneficiary != msg.sender, "Depositor cannot be beneficiary");

        uint256 escrowId = escrowCount;
        escrowtransaction[escrowId] = EscrowTransaction({
            escrowId: escrowId,
            depositor: msg.sender,
            beneficiary: _beneficiary,
            amount: msg.value,
            status: Status.Pending
        });

        emit EscrowCreated(msg.sender, _beneficiary, escrowId, msg.value);
        escrowCount++;
    }

    function approveEscrow(uint256 _escrowId) external onlyDepositor(_escrowId) checkIfEscrowExists(_escrowId) {
        EscrowTransaction storage escrow = escrowtransaction[_escrowId];
        require(escrow.status == Status.Pending, "Escrow not pending");

        escrow.status = Status.Complete;
        
        (bool success, ) = payable(escrow.beneficiary).call{value: escrow.amount}("");
        require(success, "Not sent");

        emit EscrowReleased(msg.sender, escrow.beneficiary, _escrowId, escrow.amount);
    }
    
    function refundEscrow(uint256 _escrowId) external onlyDepositor(_escrowId) checkIfEscrowExists(_escrowId) {
        EscrowTransaction storage escrow = escrowtransaction[_escrowId];
        require(escrow.status == Status.Pending, "Escrow not pendind");

        escrow.status = Status.Refunded;

        (bool success, ) = payable(escrow.depositor).call{value: escrow.amount}("");
        require(success, "Refund to buyer falied");

        emit EscrowRefunded(msg.sender, _escrowId, escrow.amount);
    }

    function withdrawContractBalance() external {
        require(msg.sender == owner, "Only owner can withdraw");
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }
    
    function getStatus(uint256 _escrowId)
    external
    view
    checkIfEscrowExists(_escrowId)
    returns (Status)
    {
        return escrowtransaction[_escrowId].status;
    }
    
    function getEscrow(uint256 _escrowId)
        external
        view
        checkIfEscrowExists(_escrowId)
        returns (
            uint256 escrowId,
            address depositor,
            address beneficiary,
            uint256 amount,
            Status
        )
    {
        EscrowTransaction storage escrow = escrowtransaction[_escrowId];
        return (
            escrow.escrowId,
            escrow.depositor,
            escrow.beneficiary,
            escrow.amount,
            escrow.status
        );
    }

    function getDepositorEscrows(address _depositor) external view returns (uint256[] memory) {
        uint256 count = 0;

        for (uint256 i = 0; i < escrowCount; i++) {
            if (escrowtransaction[i].depositor == _depositor) {
                count++;
            }
        }

        uint256[] memory depositorEscrows = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < escrowCount; i++) {
            if(escrowtransaction[i].depositor == _depositor) {
                depositorEscrows[index] = i;
                index++;
            }
        }

        return depositorEscrows;
    }
    
    function getBeneficiaryEscrows(address _beneficiary) external view returns (uint256[] memory) {
        uint256 count = 0;

        for (uint256 i = 0; i < escrowCount; i++) {
            if (escrowtransaction[i].beneficiary == _beneficiary) {
                count++;
            }
        }

        uint256 index = 0;
        uint256[] memory beneficiaryEscrows = new uint256[](count);

        for (uint256 i = 0; i < escrowCount; i++) {
            if (escrowtransaction[i].beneficiary == _beneficiary) {
                beneficiaryEscrows[index] = i;
                index++;
            }
        }

        return beneficiaryEscrows;
    }
    
    function getTotalEscrows() external view returns (uint256) {
        return escrowCount;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}