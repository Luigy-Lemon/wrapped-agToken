// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "./utils/ERC20.sol";
import {ConditionalSwapperAdapter} from "./utils/ConditionalSwapperAdapter.sol";
import {IAgToken} from "./interfaces/IAgToken.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {DataTypes} from  "./types/DataTypes.sol";

/// @notice Wrapped AgToken (ERC-20) implementation.
/// @author Luigy-Lemon
/// @author Inspired by Solmate WETH (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/WETH.sol)
contract WrappedAgToken is ERC20, ConditionalSwapperAdapter {

    event Deposit(address indexed from, uint256 amount);

    event Withdrawal(address indexed to, uint256 amount);

    event Claimed(uint256 amount);

    event ManagerChanged(address indexed newManager);

    event CollectorChanged(address indexed newCollector);

    event SwapperChanged(address indexed newSwapper);


    uint256 constant ACTIVE_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;

    address immutable factory;
    address public manager;
    address public interestCollector;
    address public swapper;
    address public immutable reserveAsset;
    IAgToken public immutable underlyingAgToken;
    ILendingPool public immutable POOL;

    constructor(
    string memory tokenName,
    string memory tokenSymbol,
    uint8 tokenDecimals,
    address _underlyingAgToken,
    address _interestCollector,
    address governanceAddress,
    address conditionalSwapper
  ) ERC20(tokenName, tokenSymbol, tokenDecimals) ConditionalSwapperAdapter(conditionalSwapper)  {
    interestCollector = _interestCollector;
    underlyingAgToken = IAgToken(_underlyingAgToken);
    POOL = ILendingPool(underlyingAgToken.POOL());
    reserveAsset = underlyingAgToken.UNDERLYING_ASSET_ADDRESS();
    manager = governanceAddress;
    swapper = conditionalSwapper;
    factory = msg.sender;
    underlyingAgToken.approve(address(underlyingAgToken.POOL()), type(uint256).max);
    ERC20(reserveAsset).approve(address(underlyingAgToken.POOL()), type(uint256).max);
  }

    /*//////////////////////////////////////////////////////////////
                        AUTH LOGIC
    //////////////////////////////////////////////////////////////*/

    modifier isManager {
        require(msg.sender == manager ||msg.sender == factory, "UNAUTHORIZED");
        _;
    }

    modifier isActive {
        DataTypes.ReserveConfigurationMap memory config = POOL.getConfiguration(reserveAsset);
        
        require((config.data & ~ACTIVE_MASK) != 0, "Underlying Asset is not active");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    function transfer(address to, uint256 amount) public override returns (bool) {

        _beforeTokenTransfer(msg.sender, to, amount);
        
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        _afterTokenTransfer(msg.sender, to, amount);

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        _beforeTokenTransfer(from, to, amount);

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        _afterTokenTransfer(from, to, amount);

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        WRAPPER LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 amount) public isActive() {

        underlyingAgToken.transferFrom(msg.sender, address(this), amount);

        _mint(msg.sender, amount);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) public {
        
        _burn(msg.sender, amount);

        underlyingAgToken.transfer(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE LOGIC
    //////////////////////////////////////////////////////////////*/

    function claim() public {
        uint256 claimable = underlyingAgToken.balanceOf(address(this)) - totalSupply;

        underlyingAgToken.transfer(interestCollector, claimable);
        
        require(underlyingAgToken.balanceOf(address(this)) == totalSupply, "Validation failed");

        emit Claimed(claimable);
    }

    function transferERC20Token(address token) public returns(bool){
        require(token != address(underlyingAgToken));
        ERC20 asset = ERC20(token);
        uint256 balance = asset.balanceOf(address(this));
        return asset.transfer(interestCollector, balance);
    }


    function setInterestCollector(address newCollector) external isManager() {
        interestCollector = newCollector;
        emit CollectorChanged(newCollector);

    }

    function setManager(address newManager) external isManager() {
        manager = newManager;
        emit ManagerChanged(newManager);

    }

    function setConditionalSwapper(address newSwapper) external isManager() {
        swapper = newSwapper;
        emit SwapperChanged(newSwapper);

    }

    receive() external payable {
        revert("Contract can only handle ERC20 tokens");
    }
}
