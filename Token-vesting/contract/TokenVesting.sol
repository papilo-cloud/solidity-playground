// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenVesting {
    IERC20 public immutable token;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 cliffDuration; // timestamp
        uint256 vestingDuration; // duration in seconds
        bool initialized;
        bool revocable;
        bool revoked;
    }

    mapping(address => VestingSchedule[]) public schedules;
    mapping(address => uint256) public holdersVestingCount;
    uint256 public vestingSchedulesCount;
    address public owner;

    event VestingScheduleCreated(
        uint256 indexed startTime,
        address indexed beneficiary,
        uint256 totalAmount
    );
    event TokensClaimed(
        uint256 indexed scheduleIndex,
        address indexed beneficiary,
        uint256 amount
    );
    event Revoked(uint256 indexed scheduleIndex);

    constructor(IERC20 _token) {
        require(address(_token) > address(0), "Invalid token");
        token = _token;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Not the owner");
        _;
    }

    modifier isValidSchedule(uint256 scheduleIndex) {
        require(scheduleIndex < schedules[msg.sender].length, "Invalid schedule");
        _;
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        uint256 _totalAmount,
        bool _revocable
    ) 
        external onlyOwner
    {
        require(_beneficiary > address(0), "Invalid beneficiary");
        require(_totalAmount > 0, "Amount must be > 0");
        require(_vestingDuration > 0, "Duration must be > 0");
        require(_cliffDuration <= _vestingDuration, "Cliff > duration");

        require(token.transferFrom(msg.sender, address(this), _totalAmount), "Transfer failed");

        schedules[_beneficiary].push(VestingSchedule({
            totalAmount: _totalAmount,
            claimedAmount: 0,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            initialized :true,
            revocable: _revocable,
            revoked: false
        }));

        emit VestingScheduleCreated(_startTime, _beneficiary, _totalAmount);
    }

    function claim(uint256 _scheduleIndex) external isValidSchedule(_scheduleIndex) {
        VestingSchedule storage schedule = schedules[msg.sender][_scheduleIndex];

        require(schedule.initialized, "Not found");
        require(!schedule.revoked, "Schedule revoked");

        uint256 vestedAmount = getVestedAmount(msg.sender, _scheduleIndex);
        uint256 claimableAmount = vestedAmount - schedule.claimedAmount;

        require(claimableAmount > 0, "Nothing to claim");

        schedule.claimedAmount += claimableAmount;
        require(token.transfer(msg.sender, claimableAmount), "Transfer failed");

        emit TokensClaimed(_scheduleIndex, msg.sender, claimableAmount);
    }

    function getVestedAmount(address _beneficiary, uint256 _scheduleIndex)
        public 
        view
        isValidSchedule(_scheduleIndex)
        returns (uint256)
    {
        VestingSchedule storage schedule = schedules[_beneficiary][_scheduleIndex];

        uint256 currentTime = block.timestamp;
        if (currentTime < schedule.cliffDuration + schedule.startTime) {
            return 0;
        } else if (currentTime >= schedule.vestingDuration + schedule.startTime) {
            return schedule.totalAmount;
        } else {
            uint256 timeVested = currentTime - schedule.startTime - schedule.cliffDuration;
            uint256 vestingTimeRemaining = schedule.vestingDuration - schedule.cliffDuration;

            return (schedule.totalAmount * timeVested) / vestingTimeRemaining;
        }
    }

    function getScheduleCount(address _beneficiary) external view returns (uint256) {
        return schedules[_beneficiary].length;
    }

    function getSchedule(address _beneficiary, uint256 _scheduleIndex)
        external
        view
        isValidSchedule(_scheduleIndex)
        returns (VestingSchedule memory)
    {
        return schedules[_beneficiary][_scheduleIndex];
    }

    function revoke(address _beneficiary, uint256 _scheduleIndex)
        external
        onlyOwner
        isValidSchedule(_scheduleIndex)
    {
        VestingSchedule storage schedule = schedules[_beneficiary][_scheduleIndex];
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");
        require(schedule.initialized, "Not found");

        uint256 vestedAmount = getVestedAmount(_beneficiary, _scheduleIndex);
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;

        schedule.revoked = true;

        if (unvestedAmount > 0) {
            require(token.transfer(owner, unvestedAmount), "Transfer failed");
        }

        emit Revoked(_scheduleIndex);
    }
}