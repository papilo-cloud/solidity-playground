// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Voting {

    struct Proposal {
        uint256 proposalId;
        string description;
        uint256 yesCount;
        uint256 noCount;
        bool isActive;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Proposal) public proposals;

    uint256 public proposalCount;
    address public owner;

    event ProposalCreated(
        uint256 indexed proposalId,
        string description
    );
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool vote
    );
    event ProposalClosed(
        uint256 indexed proposalId,
        uint256 yesCount,
        uint256 noCount
    );

    constructor () {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier doesProposalExists(uint256 _proposalId) {
        require(_proposalId <= proposalCount, "Proposal does not exist");
        _;
    }

    function createProposal(string memory _description ) public onlyOwner {
        require(bytes(_description).length > 0, "Description cannot be empty");
        uint256 proposalId = proposalCount++;
        Proposal storage prop = proposals[proposalId];

        prop.proposalId = proposalId;
        prop.description = _description;
        prop.isActive = true;

        emit ProposalCreated(proposalId, _description);
    }

    function vote(uint256 _proposalId, bool _vote) public doesProposalExists(_proposalId) {
        Proposal storage prop = proposals[_proposalId];
        require(prop.isActive, "Proposal is not active");
        require(!prop.hasVoted[msg.sender], "Already voted");

        prop.hasVoted[msg.sender] = true;

        if (_vote) {
            prop.yesCount++;
        } else {
            prop.noCount++;
        }

        emit Voted(_proposalId, msg.sender, _vote);
    }

    function closeProposal(uint256 _proposalId) public onlyOwner doesProposalExists(_proposalId) {
        Proposal storage prop = proposals[_proposalId];
        require(prop.isActive, "Proposal already closed");

        prop.isActive = false;

        emit ProposalClosed(_proposalId, prop.yesCount, prop.noCount);
    }

    function voteCount(uint256 _proposalId)
        public
        view
        doesProposalExists(_proposalId)
        returns (uint256 yesCount, uint256 noCount)
    {
        Proposal storage prop = proposals[_proposalId];
        return (prop.yesCount, prop.noCount);
    }

    function hasVoted(address _voter, uint256 _proposalId)
        public
        view
        doesProposalExists(_proposalId)
        returns (bool)
    {
        return proposals[_proposalId].hasVoted[_voter];
    }

    function getTotalProposals() public view returns (uint256) {
        return proposalCount;
    }
}