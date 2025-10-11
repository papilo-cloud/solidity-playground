// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract StackClub {
    address[] public members;

    constructor() {
        members.push(msg.sender);
    }

    function isMember(address _member) public view returns(bool) {
        for(uint i = 0; i < members.length; i++) {
            if(_member == members[i]){
                return true;
            }
        }
        return false;
    }
    function addMember(address _member) external {
        require(isMember(msg.sender));
        members.push(_member);
    }
    
    function removeLastMember() public {
        require(isMember(msg.sender));
        members.pop();
    }
}