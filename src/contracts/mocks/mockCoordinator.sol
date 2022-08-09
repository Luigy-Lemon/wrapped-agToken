// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract mockCoordinator {

    address public GPv2Settlement = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    mapping (address => address) public proxy;
    mapping (address => address) public account;

    function userProxyAddress(address userAddress) external view returns (address){
        return proxy[userAddress];
    }

    function proxyOwnerAddress(address proxyAddress) external view returns (address){
        return account[proxyAddress];
    }

    function createAccount() external {
        account[msg.sender] = address(1);
        proxy[account[msg.sender]] = msg.sender;
    }

}