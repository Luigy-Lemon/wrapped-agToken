// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {IAgToken} from "../contracts/interfaces/IAgToken.sol";
import {DataTypes} from "../contracts/types/DataTypes.sol";
import {WrappedAgToken} from "../contracts/WrappedAgToken.sol";
import {ILendingPool} from "../contracts/interfaces/ILendingPool.sol";

contract WrappedAgTokenTest is Test {
    WrappedAgToken token;

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        vm.startPrank(0xb4c575308221CAA398e0DD2cDEB6B2f10d7b000A);
        token = new WrappedAgToken(
            "Wrapped agUSDC", 
            "WagUSDC", 
            6,  
            0x291B5957c9CBe9Ca6f0b98281594b4eB495F4ec1, //agUSDC
            0xbad2BEE000000000000000000000000000000000,
            0xb4c575308221CAA398e0DD2cDEB6B2f10d7b000A // Agave Treasury
        );
        IAgToken(0x291B5957c9CBe9Ca6f0b98281594b4eB495F4ec1).transfer(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe, 100e6);
        vm.stopPrank();
    }

    function invariantMetadata() public {
        assertEq(token.name(), "Wrapped agUSDC");
        assertEq(token.symbol(), "WagUSDC");
        assertEq(token.decimals(), 6);
        assertEq(address(token.underlyingAgToken()), 0x291B5957c9CBe9Ca6f0b98281594b4eB495F4ec1);
        assertEq(token.interestCollector(), 0xbad2BEE000000000000000000000000000000000);
        assertEq(token.manager(), 0xb4c575308221CAA398e0DD2cDEB6B2f10d7b000A);
    }


    function testIsActive() public {
        uint256 ACTIVE_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        address reserve = token.reserveAsset();
        ILendingPool pool = token.POOL();
        console2.log(reserve, address(pool) );
        DataTypes.ReserveConfigurationMap memory config = pool.getConfiguration(reserve);
        console2.log(config.data , ~ACTIVE_MASK );
        assertGt((config.data & ~ACTIVE_MASK) , 0);

        vm.stopPrank();
    
    }

    function testIsManager() public {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        assertEq(0xb4c575308221CAA398e0DD2cDEB6B2f10d7b000A, token.manager());
        vm.stopPrank();
    }

    function testDeposit() public {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        
        uint256 balance = token.underlyingAgToken().balanceOf(msg.sender);
        console2.log("agToken balance:", balance);

        IAgToken undToken = token.underlyingAgToken();
        bool success = undToken.approve(address(token), type(uint256).max);
        assertTrue(success);

        token.deposit(100e6);
        assertEq(token.totalSupply(), 100e6);
        assertEq(token.balanceOf(msg.sender), 100e6);
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);

        // TESTED DEPOSIT LOGIC
        IAgToken undToken = token.underlyingAgToken();
        bool success = undToken.approve(address(token), type(uint256).max);
        assertTrue(success);
        token.deposit(100e6);

        // WITHDRAW LOGIC
        token.withdraw( 90e6);
        assertEq(token.totalSupply(), 100e6 - 90e6);
        assertEq(token.balanceOf(msg.sender), 10e6);
        vm.stopPrank();
    }

    function testApprove() public {
        assertTrue(token.approve(address(0xBEEF), 100e6));

        assertEq(token.allowance(address(this), address(0xBEEF)), 100e6);
    }

    function testTransfer() public {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);

        
        // TESTED DEPOSIT LOGIC
        IAgToken undToken = token.underlyingAgToken();
        bool success = undToken.approve(address(token), type(uint256).max);
        assertTrue(success);
        token.deposit(100e6);

        // TRANSFER LOGIC
        assertTrue(token.transfer(address(0xBEEF), 100e6));
        assertEq(token.totalSupply(), 100e6);

        assertEq(token.balanceOf(address(msg.sender)), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 100e6);

        vm.stopPrank();
    }

    function testTransferFrom() public {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        
        // TESTED DEPOSIT LOGIC
        IAgToken undToken = token.underlyingAgToken();
        bool success = undToken.approve(address(token), type(uint256).max);
        assertTrue(success);
        token.deposit(100e6);

        // TRANSFER LOGIC
        address from = address(0xABCD);
        assertTrue(token.transfer(from, 100e6));
        vm.stopPrank();
        vm.prank(from);
        token.approve(address(this), 100e6);

        assertTrue(token.transferFrom(from, address(0xBEEF), 100e6));
        assertEq(token.totalSupply(), 100e6);

        assertEq(token.allowance(from, address(this)), 0);

        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 100e6);
    }
    function testInfiniteApproveTransferFrom() public {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);

        // TESTED DEPOSIT LOGIC
        IAgToken undToken = token.underlyingAgToken();
        bool success = undToken.approve(address(token), type(uint256).max);
        assertTrue(success);
        token.deposit(100e6);

        // TRANSFER LOGIC
        address from = address(0xABCD);
        assertTrue(token.transfer(from, 100e6));
        vm.stopPrank();

        vm.prank(from);
        token.approve(address(this), type(uint256).max);

        assertTrue(token.transferFrom(from, address(0xBEEF), 100e6));
        assertEq(token.totalSupply(), 100e6);

        assertEq(token.allowance(from, address(this)), type(uint256).max);

        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 100e6);
    }

    function testPermit() public {

        // PERMIT LOGIC
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 100e6, 0, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 100e6, block.timestamp, v, r, s);

        assertEq(token.allowance(owner, address(0xCAFE)), 100e6);
        assertEq(token.nonces(owner), 1);
    }

    function testFailTransferInsufficientBalance() public {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        
        // TESTED DEPOSIT LOGIC
        IAgToken undToken = token.underlyingAgToken();
        bool success = undToken.approve(address(token), type(uint256).max);
        assertTrue(success);
        token.deposit(90e6);
        token.transfer(address(0xBEEF), 100e6);

        vm.stopPrank();
    }

    function testFailTransferFromInsufficientAllowance() public {
        address from = address(0xABCD);

        token.deposit( 100e6);

        vm.prank(from);
        token.approve(address(this), 90e6);

        token.transferFrom(from, address(0xBEEF), 100e6);
    }

    function testFailTransferFromInsufficientBalance() public {
        address from = address(0xABCD);

        token.deposit( 90e6);

        vm.prank(from);
        token.approve(address(this), 100e6);

        token.transferFrom(from, address(0xBEEF), 100e6);
    }

    function testFailPermitBadNonce() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 100e6, 1, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 100e6, block.timestamp, v, r, s);
    }

    function testFailPermitBadDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 100e6, 0, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 100e6, block.timestamp + 1, v, r, s);
    }

    function testFailPermitPastDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 100e6, 0, block.timestamp - 1))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 100e6, block.timestamp - 1, v, r, s);
    }

    function testFailPermitReplay() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 100e6, 0, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 100e6, block.timestamp, v, r, s);
        token.permit(owner, address(0xCAFE), 100e6, block.timestamp, v, r, s);
    }

    function testFailWithdrawInsufficientBalance(
        uint256 depositAmount,
        uint256 withdrawAmount
    ) public {
        withdrawAmount = bound(withdrawAmount, depositAmount + 1, type(uint256).max);

        token.deposit( depositAmount);
        token.withdraw( withdrawAmount);
    }

    function testFailTransferInsufficientBalance(
        address to,
        uint256 depositAmount,
        uint256 sendAmount
    ) public {
        sendAmount = bound(sendAmount, depositAmount + 1, type(uint256).max);

        token.deposit( depositAmount);
        token.transfer(to, sendAmount);
    }

    function testFailTransferFromInsufficientAllowance(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        amount = bound(amount, approval + 1, type(uint256).max);

        address from = address(0xABCD);

        token.deposit( amount);

        vm.prank(from);
        token.approve(address(this), approval);

        token.transferFrom(from, to, amount);
    }

    function testFailTransferFromInsufficientBalance(
        address to,
        uint256 depositAmount,
        uint256 sendAmount
    ) public {
        sendAmount = bound(sendAmount, depositAmount + 1, type(uint256).max);

        address from = address(0xABCD);

        token.deposit( depositAmount);

        vm.prank(from);
        token.approve(address(this), sendAmount);

        token.transferFrom(from, to, sendAmount);
    }

    function testFailPermitBadNonce(
        uint256 privateKey,
        address to,
        uint256 amount,
        uint256 deadline,
        uint256 nonce
    ) public {
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;
        if (nonce == 0) nonce = 1;

        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, nonce, deadline))
                )
            )
        );

        token.permit(owner, to, amount, deadline, v, r, s);
    }

    function testFailPermitBadDeadline(
        uint256 privateKey,
        address to,
        uint256 amount,
        uint256 deadline
    ) public {
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;

        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        token.permit(owner, to, amount, deadline + 1, v, r, s);
    }

    function testFailPermitPastDeadline(
        uint256 privateKey,
        address to,
        uint256 amount,
        uint256 deadline
    ) public {
        deadline = bound(deadline, 0, block.timestamp - 1);
        if (privateKey == 0) privateKey = 1;

        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        token.permit(owner, to, amount, deadline, v, r, s);
    }

    function testFailPermitReplay(
        uint256 privateKey,
        address to,
        uint256 amount,
        uint256 deadline
    ) public {
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;

        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        token.permit(owner, to, amount, deadline, v, r, s);
        token.permit(owner, to, amount, deadline, v, r, s);
    }

    function testReceive(uint256 amount) public{
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        vm.deal(msg.sender, amount);
        (bool success,) = address(token).call(
            abi.encodeWithSignature("")
        );
        assertFalse(success);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE LOGIC
    //////////////////////////////////////////////////////////////*/

    function testClaim() public {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
                // TESTED DEPOSIT LOGIC
        IAgToken undToken = token.underlyingAgToken();
        bool success = undToken.approve(address(token), type(uint256).max);
        assertTrue(success);
        token.deposit(10e6);
        skip(1000);
        uint256 collectorBalance = undToken.balanceOf(token.interestCollector());
        uint256 claimable = undToken.balanceOf(address(token)) - token.totalSupply();
        assertGt(claimable, 0);
        token.claim();
        assertEq(claimable, undToken.balanceOf(token.interestCollector()) - collectorBalance);
        vm.stopPrank();
    }


    function testSetInterestCollector(address newCollector) external  {
        address manager = token.manager();
        vm.startPrank(manager);
        token.setInterestCollector(newCollector);
        assertEq(newCollector, token.interestCollector());
        vm.stopPrank();
    }

    function testSetManager(address newManager) external{
        address manager = token.manager();
        vm.startPrank(manager);
        token.setManager(newManager);
        assertEq(newManager, token.manager());
        vm.stopPrank();
    }
}

