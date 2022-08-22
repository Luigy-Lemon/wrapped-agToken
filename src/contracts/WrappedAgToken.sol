// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "./utils/ERC20.sol";
import {ConditionalSwapperAdapter} from "./utils/ConditionalSwapperAdapter.sol";
import {IAgToken} from "./interfaces/IAgToken.sol";
import {DataTypes} from  "./types/DataTypes.sol";
import {ICoordinator} from "./interfaces/ICoordinator.sol";
import {IUserProxy} from "./interfaces/ICoordinator.sol";

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

    address immutable factory;
    address public manager;
    address public interestCollector;
    address public swapper;
    address public immutable reserveAsset;
    IAgToken public immutable underlyingAgToken;

    uint256 public FeeRate;
    uint256 private FeeDecimalPrecision = 10000;
    uint256 private hasActiveLoan = 1;
    mapping (address => uint256) loanedAmount;
    uint256 private constant _not_loaning = 1;
    uint256 private constant _loaning = 2;
    
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
    reserveAsset = underlyingAgToken.UNDERLYING_ASSET_ADDRESS();
    manager = governanceAddress;
    swapper = conditionalSwapper;
    factory = msg.sender;
  }

    /*//////////////////////////////////////////////////////////////
                        AUTH LOGIC
    //////////////////////////////////////////////////////////////*/

    modifier isManager {
        require(msg.sender == manager ||msg.sender == factory, "UNAUTHORIZED");
        _;
    }

    modifier hasLoan {
        require(hasActiveLoan == _not_loaning, "ReentrancyGuard: Can't loan twice!");
        // Any calls to hasLoan after this point will fail
        hasActiveLoan = _loaning;
        _;
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        hasActiveLoan = _not_loaning;
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

    function deposit(uint256 amount) public{

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
                        FLASHLOAN LOGIC
    //////////////////////////////////////////////////////////////*/

    function flashLoanOpen(address _receiver, uint256 _amount) external hasLoan() {
        address caller = ICoordinator(swapper).proxyOwnerAddress(msg.sender); 
        require(caller != address(0) && validateFlashLoan(), "Not allowed");
        loanedAmount[caller] = _amount + ((_amount * FeeRate) / FeeDecimalPrecision);
        _mint(_receiver, _amount);
    }

    function flashLoanClose() external {
        address caller = ICoordinator(swapper).proxyOwnerAddress(msg.sender);
        require(caller != address(0) && loanedAmount[caller] > 0, "Not allowed");
        _burn(caller, loanedAmount[caller]);
        loanedAmount[caller] = 0;
    }

    function checkLoanedAmount(address caller) external view returns(uint256){
        return loanedAmount[caller];
    }

    function validateFlashLoan() internal returns(bool) {
        return IUserProxy(msg.sender).openFlashloanLoan(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                        TREASURY LOGIC
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

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE LOGIC
    //////////////////////////////////////////////////////////////*/

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

    function setFeeRate(uint256 newFee) external isManager(){
        require(newFee < FeeDecimalPrecision);
        FeeRate = newFee;  
    }

    receive() external payable {
        revert("Contract can only handle ERC20 tokens");
    }
}
