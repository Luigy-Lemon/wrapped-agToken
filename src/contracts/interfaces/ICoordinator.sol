// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICoordinator {

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function accounts(address proxy) external view returns (address);

    function userProxyAddress(address user) external view returns (address);

    function GPv2Settlement() external view returns (address);

    function allowedAddresses(address contractAddress) external view returns (bool);

    function proxyOwnerAddress(address proxy) external view returns (address);

}