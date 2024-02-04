// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Time {
    uint256 public t;

    function getTime() external view returns (uint256) {
        return block.timestamp;
    }

    function getChainId() external view returns (uint256) {
        return block.chainid;
    }

    function updateT() external {
        t++;
    }
}
