// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DAO {
    error DAO__NotTheOwner();
    error DAO__InvalidToken();
    error DAO__InsufficientProposalThreshold();
    error DAO__InvalidProposal();
    error DAO__VotingNotStartedOrEnded();
    error DAO__AlreadyVoted();
    error DAO__AlreadyExecuted();
    error DAO__TooEarlyToExecute();
    error DAO__QuorumNotReached();
    error DAO__NotEnoughVotes();
    error DAO__ExecutionFailed();
    error DAO__NoVotingPower();

    struct Proposal {
        uint256 id;
        string description;
        address targetContract;
        address proposer;
        bytes data;
        uint256 startTime;
        uint256 endTime;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    IERC20 public govToken;
    address public owner;
    uint256 public proposalCount;
    uint256 public votingPeriod = 3 days;
    uint256 public constant PROPOSAL_THRESHOLD = 10e18;
    uint256 public constant QUORUM_PERCENTAGE = 4; // 4%

    mapping(uint256 => Proposal) public proposals;
    mapping(address => address) public delegates;

    event ProposalCreated(uint256 indexed proposalId, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event Delegated(address indexed delegator, address indexed delegatee);

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert DAO__NotTheOwner();
        }
        _;
    }

    constructor(address _token) {
        if (_token == address(0)) {
            revert DAO__InvalidToken();
        }
        govToken = IERC20(_token);
        owner = msg.sender;
    }

    function createProposal(
        string memory _description,
        address _targetContract,
        bytes memory _data
    ) external {
        if (govToken.balanceOf(msg.sender) < PROPOSAL_THRESHOLD) {
            revert DAO__InsufficientProposalThreshold();
        }
        
        uint256 proposalId = proposalCount;
        proposalCount++;

        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalCount;
        proposal.description = _description;
        proposal.proposer = msg.sender;
        proposal.targetContract = _targetContract;
        proposal.data = _data;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + votingPeriod;

        emit ProposalCreated(proposalCount, _description);
    }

    function vote(uint256 _proposalId, bool _support) external {
        if (_proposalId >= proposalCount) {
            revert DAO__InvalidProposal();
        }

        Proposal storage proposal = proposals[_proposalId];

        if (block.timestamp < proposal.startTime || block.timestamp > proposal.endTime) {
            revert DAO__VotingNotStartedOrEnded();
        }
        if (proposal.hasVoted[msg.sender]) {
            revert DAO__AlreadyVoted();
        }

        uint256 votingPower = getVotingPower(msg.sender);
        if  (votingPower == 0) {
            revert DAO__NoVotingPower();
        }

        proposal.hasVoted[msg.sender] = true;

        if (_support) {
            proposal.votesFor += votingPower;
        } else {
            proposal.votesAgainst += votingPower;
        }

        emit VoteCast(_proposalId, msg.sender, _support);
    }

    function executeProposal(uint256 _proposalId) external onlyOwner {
        if (_proposalId >= proposalCount) {
            revert DAO__InvalidProposal();
        }

        Proposal storage proposal = proposals[_proposalId];

        if (proposal.executed) {
            revert DAO__AlreadyExecuted();
        }
        if (block.timestamp < proposal.endTime) {
            revert DAO__TooEarlyToExecute();
        }

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 totalSupply = govToken.totalSupply();
        uint256 quorum = (totalSupply * QUORUM_PERCENTAGE) / 100; // 4% quorum

        if (totalVotes < quorum) {
            revert DAO__QuorumNotReached();
        }

        if (proposal.votesFor <= proposal.votesAgainst) {
            revert DAO__NotEnoughVotes();
        }

        proposal.executed = true;

        (bool success, ) = proposal.targetContract.call(proposal.data);
        if (!success) {
            revert DAO__ExecutionFailed();
        }

        emit ProposalExecuted(_proposalId);

    }

    function delegate(address _delegatee) external {
        if (govToken.balanceOf(msg.sender) < 0) {
            revert DAO__NoVotingPower();
        }
        delegates[msg.sender] = _delegatee;

        emit Delegated(msg.sender, _delegatee);
    }

    function getVotingPower(address _voter) public view returns (uint256) {
        uint256 power = govToken.balanceOf(_voter);

        // If a user has already delegated their vote, ot should return 0.
        if (delegates[_voter] != address(0)) {
            return 0;
        }
        return power;
    }

    function getProposal (uint256 _proposalId) public view returns (
        uint256 id,
        address proposer,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        bool executed
    ) {
        if (_proposalId >= proposalCount) {
            revert DAO__InvalidProposal();
        }
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.executed
        );
    }
}