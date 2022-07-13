// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import {ERC20} from "./tokens/ERC20.sol";

import {SafeTransferLib} from "./utils/SafeTransferLib.sol";

import {IAgToken} from "./interfaces/IAgToken.sol";

/// @notice Wrapped AgToken (ERC-20) implementation.
/// @author Luigy-Lemon (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/WETH.sol)
/// @author Inspired by Solmate WETH (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/WETH.sol)
contract WrappedAgToken is ERC20 {
    using SafeTransferLib for address;

    event Deposit(address indexed from, uint256 amount);

    event Withdrawal(address indexed to, uint256 amount);

    event Claimed(uint256 amount);

    uint256 userDeposits = 0;
    address public feeCollector;
    address public reserveAsset;
    IAgToken public immutable underlyingAgToken;
    ILendingPool public immutable POOL;


    constructor(
    ILendingPool pool,
    IAgToken _underlyingAgToken,
    address _feeCollector,
    string memory tokenName,
    string memory tokenSymbol,
  ) public ERC20(tokenName, tokenSymbol, 18) {
    POOL = pool;
    feeCollector = _feeCollector;
    underlyingAgToken = _underlyingAgToken;
    reserveAsset = underlyingAgToken.UNDERLYING_ASSET_ADDRESS;
  }

    modifier isActive {
        DataTypes.ReserveData memory reserveData = POOL.getReserveData(reserveAsset);
        require(reserveData.isActive, "Underlying Asset is not active");
        _;
    }

    function deposit(uint256 amount) public {
        safeTransferFrom(msg.sender, address(this), amount);

        _mint(msg.sender, msg.value);

        userDeposits += amount;

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        _burn(msg.sender, amount);

        userDeposits -= amount;

        safeTransfer(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }

    function claim() public {
        uint256 claimable = totalSupply - userDeposits;

        underlyingAgToken.transfer(feeCollector, claimable);

        emit Claimed(claimable);
    }

    function setFeeCollector(address newCollector){
        feeCollector = newCollector;
    }

    receive() external payable {
        require(msg.value < 0, "Contract can only handle ERC20 tokens");
    }
}