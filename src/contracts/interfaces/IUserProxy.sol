// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IUserProxy {

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function proxyOwner() external view returns (address);

    /**
     * @dev Starts coordinator after an order has been executed.
     */
    function afterSettlement(address token,uint256 amount) external;

    /**
     * @dev Starts coordinator before an order has been executed.
     */
    function beforeSettlement(address token, uint256 amount) external;

    function initialize(address _owner) external;

    function openFlashloanLoan(address asset) external view returns(bool);

}