// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

interface IWrappedAgToken {
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Claimed(uint256 amount);
    event CollectorChanged(address indexed newCollector);
    event Deposit(address indexed from, uint256 amount);
    event ManagerChanged(address indexed newManager);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);

    function DOMAIN_SEPARATOR() view external returns (bytes32);
    function POOL() view external returns (address);
    function allowance(address, address) view external returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address) view external returns (uint256);
    function claim() external;
    function decimals() view external returns (uint8);
    function deposit(uint256 amount) external;
    function interestCollector() view external returns (address);
    function manager() view external returns (address);
    function name() view external returns (string memory);
    function nonces(address) view external returns (uint256);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function reserveAsset() view external returns (address);
    function setInterestCollector(address newCollector) external;
    function setManager(address newManager) external;
    function symbol() view external returns (string memory);
    function totalSupply() view external returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function underlyingAgToken() view external returns (address);
    function withdraw(uint256 amount) external;
}