// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.0;

import {IERC20} from "./IERC20.sol";
import {IScaledBalanceToken} from "./IScaledBalanceToken.sol";
import {ILendingPool} from "./ILendingPool.sol";

interface IAgToken is IERC20, IScaledBalanceToken {
    /**
     * @dev Emitted after the mint action
     * @param from The address performing the mint
     * @param value The amount being
     * @param index The new liquidity index of the reserve
     *
     */
    event Mint(address indexed from, uint256 value, uint256 index);


    function POOL() external returns (ILendingPool);

    function UNDERLYING_ASSET_ADDRESS() external returns (address);

    /**
     * @dev Mints `amount` agTokens to `user`
     * @param user The address receiving the minted tokens
     * @param amount The amount of tokens getting minted
     * @param index The new liquidity index of the reserve
     * @return `true` if the the previous balance of the user was 0
     */
    function mint(address user, uint256 amount, uint256 index)
        external
        returns (bool);

    /**
     * @dev Emitted after agTokens are burned
     * @param from The owner of the agTokens, getting them burned
     * @param target The address that will receive the underlying
     * @param value The amount being burned
     * @param index The new liquidity index of the reserve
     *
     */
    event Burn(
        address indexed from,
        address indexed target,
        uint256 value,
        uint256 index
    );

    /**
     * @dev Emitted during the transfer action
     * @param from The user whose tokens are being transferred
     * @param to The recipient
     * @param value The amount being transferred
     * @param index The new liquidity index of the reserve
     *
     */
    event BalanceTransfer(
        address indexed from,
        address indexed to,
        uint256 value,
        uint256 index
    );

    /**
     * @dev Burns agTokens from `user` and sends the equivalent amount of underlying to `receiverOfUnderlying`
     * @param user The owner of the agTokens, getting them burned
     * @param receiverOfUnderlying The address that will receive the underlying
     * @param amount The amount being burned
     * @param index The new liquidity index of the reserve
     *
     */
    function burn(
        address user,
        address receiverOfUnderlying,
        uint256 amount,
        uint256 index
    )
        external;

    /**
     * @dev Mints agTokens to the reserve treasury
     * @param amount The amount of tokens getting minted
     * @param index The new liquidity index of the reserve
     */
    function mintToTreasury(uint256 amount, uint256 index) external;

    /**
     * @dev Transfers agTokens in the event of a borrow being liquidated, in case the liquidators reclaims the agToken
     * @param from The address getting liquidated, current owner of the agTokens
     * @param to The recipient
     * @param value The amount of tokens getting transferred
     *
     */
    function transferOnLiquidation(address from, address to, uint256 value)
        external;

    /**
     * @dev Transfers the underlying asset to `target`. Used by the LendingPool to transfer
     * assets in borrow(), withdraw() and flashLoan()
     * @param user The recipient of the agTokens
     * @param amount The amount getting transferred
     * @return The amount transferred
     *
     */
    function transferUnderlyingTo(address user, uint256 amount)
        external
        returns (uint256);
}
