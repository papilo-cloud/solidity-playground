// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Contract {
    function filterEven(uint[] memory _arr) external pure returns(uint[] memory) {
        uint elem;
        for(uint i = 0; i < _arr.length; i++) {
            if(_arr[i]%2 == 0){
                elem += 1;
            }
        }

        uint[] memory evenNum = new uint[](elem);
        uint index = 0;

        for(uint i = 0; i < _arr.length; i++) {
            if(_arr[i]%2 == 0){
                evenNum[index] = _arr[i];
                index++;
            }
        }
        return evenNum;
    }
}