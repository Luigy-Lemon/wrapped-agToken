// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";

import {IAgToken} from "./interfaces/IAgToken.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {DataTypes} from  "./types/DataTypes.sol";

/// @notice Wrapped AgToken (ERC-20) implementation.
/// @author Luigy-Lemon (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/WETH.sol)
/// @author Inspired by Solmate WETH (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/WETH.sol)
contract WrappedAgToken is ERC20 {

    event Deposit(address indexed from, uint256 amount);

    event Withdrawal(address indexed to, uint256 amount);

    event Claimed(uint256 amount);

    uint256 constant ACTIVE_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;

    uint256 userDeposits = 0;
    address public manager;
    address public interestCollector;
    address public reserveAsset;
    IAgToken public immutable underlyingAgToken;
    ILendingPool public immutable POOL;


    constructor(
    string memory tokenName,
    string memory tokenSymbol,
    uint8 tokenDecimals,
    address _underlyingAgToken,
    address _interestCollector,
    address governanceAddress
  ) ERC20(tokenName, tokenSymbol, tokenDecimals) {
    interestCollector = _interestCollector;
    underlyingAgToken = IAgToken(_underlyingAgToken);
    POOL = ILendingPool(underlyingAgToken.POOL());
    reserveAsset = underlyingAgToken.UNDERLYING_ASSET_ADDRESS();
    manager = governanceAddress;
  }

    /*//////////////////////////////////////////////////////////////
                        AUTH LOGIC
    //////////////////////////////////////////////////////////////*/

    modifier isManager {
        require(msg.sender == manager, "UNAUTHORIZED");

        _;
    }

    modifier isActive {
        DataTypes.ReserveConfigurationMap memory config = POOL.getConfiguration(reserveAsset);
        
        require((config.data & ~ACTIVE_MASK) != 0, "Underlying Asset is not active");
        _;
    }

    
    /*//////////////////////////////////////////////////////////////
                        WRAPPER LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 amount) public isActive() {

        underlyingAgToken.transferFrom(msg.sender, address(this), amount);

        _mint(msg.sender, amount);

        userDeposits += amount;

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) public {
        userDeposits -= amount;
        
        _burn(msg.sender, amount);


        underlyingAgToken.transfer(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }


    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE LOGIC
    //////////////////////////////////////////////////////////////*/

    function claim() public {
        uint256 claimable = totalSupply - userDeposits;

        underlyingAgToken.transfer(interestCollector, claimable);

        emit Claimed(claimable);
    }


    function setInterestCollector(address newCollector) external isManager() {
        interestCollector = newCollector;
    }

    function setManager(address newManager) external isManager() {
        manager = newManager;
    }

    receive() external payable {
        require(msg.value < 0, "Contract can only handle ERC20 tokens");
    }
}