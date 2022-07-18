// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {IAgToken} from "../contracts/interfaces/IAgToken.sol";


import {WrappedAgToken} from "../contracts/WrappedAgToken.sol";

contract WrappedAgTokenTest is Test {
    WrappedAgToken token;

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        token = new WrappedAgToken(
            "Wrapped agUSDC", 
            "WagUSDC", 
            6,  
            0x291B5957c9CBe9Ca6f0b98281594b4eB495F4ec1,
            0xb4c575308221CAA398e0DD2cDEB6B2f10d7b000A,
            0xb4c575308221CAA398e0DD2cDEB6B2f10d7b000A
        );
    }

    function invariantMetadata() public {
        assertEq(token.name(), "Wrapped agUSDC");
        assertEq(token.symbol(), "WagUSDC");
        assertEq(token.decimals(), 6);
        assertEq(address(token.underlyingAgToken()), 0x291B5957c9CBe9Ca6f0b98281594b4eB495F4ec1);
        assertEq(token.interestCollector(), 0xb4c575308221CAA398e0DD2cDEB6B2f10d7b000A);
        assertEq(token.manager(), 0xb4c575308221CAA398e0DD2cDEB6B2f10d7b000A);
    }


    function testDeposit() public {
        uint256 balance = token.underlyingAgToken().balanceOf(msg.sender);
        console2.log("agToken balance:", balance);
        address undAddress = address(token.underlyingAgToken());
        (bool success,) = undAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(this), type(uint256).max)
    );  
        assertTrue(success);
        console2.log("msg.sender", token.underlyingAgToken().allowance(msg.sender, address(this)));
        console2.log("testContract", token.underlyingAgToken().allowance(address(this), address(this)));
        token.deposit(1e6);

        assertEq(token.totalSupply(), 1e6);
        assertEq(token.balanceOf(msg.sender), 1e6);
    }

    function testWithdraw() public {
        token.deposit( 1e6);
        token.withdraw( 0.9e6);

        assertEq(token.totalSupply(), 1e6 - 0.9e6);
        assertEq(token.balanceOf(address(0xBEEF)), 0.1e6);
    }

    function testApprove() public {
        assertTrue(token.approve(address(0xBEEF), 1e6));

        assertEq(token.allowance(address(this), address(0xBEEF)), 1e6);
    }

    function testTransfer() public {
        token.deposit( 1e6);

        assertTrue(token.transfer(address(0xBEEF), 1e6));
        assertEq(token.totalSupply(), 1e6);

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e6);
    }

    function testTransferFrom() public {
        address from = address(0xABCD);

        token.deposit( 1e6);

        vm.prank(from);
        token.approve(address(this), 1e6);

        assertTrue(token.transferFrom(from, address(0xBEEF), 1e6));
        assertEq(token.totalSupply(), 1e6);

        assertEq(token.allowance(from, address(this)), 0);

        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e6);
    }
    /*
    function testInfiniteApproveTransferFrom() public {
        address from = address(0xABCD);

        token.deposit( 1e6);

        vm.prank(from);
        token.approve(address(this), type(uint256).max);

        assertTrue(token.transferFrom(from, address(0xBEEF), 1e6));
        assertEq(token.totalSupply(), 1e6);

        assertEq(token.allowance(from, address(this)), type(uint256).max);

        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e6);
    }

    function testPermit() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e6, 0, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e6, block.timestamp, v, r, s);

        assertEq(token.allowance(owner, address(0xCAFE)), 1e6);
        assertEq(token.nonces(owner), 1);
    }

    function testFailTransferInsufficientBalance() public {
        token.deposit( 0.9e6);
        token.transfer(address(0xBEEF), 1e6);
    }

    function testFailTransferFromInsufficientAllowance() public {
        address from = address(0xABCD);

        token.deposit( 1e6);

        vm.prank(from);
        token.approve(address(this), 0.9e6);

        token.transferFrom(from, address(0xBEEF), 1e6);
    }

    function testFailTransferFromInsufficientBalance() public {
        address from = address(0xABCD);

        token.deposit( 0.9e6);

        vm.prank(from);
        token.approve(address(this), 1e6);

        token.transferFrom(from, address(0xBEEF), 1e6);
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
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e6, 1, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e6, block.timestamp, v, r, s);
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
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e6, 0, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e6, block.timestamp + 1, v, r, s);
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
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e6, 0, block.timestamp - 1))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e6, block.timestamp - 1, v, r, s);
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
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e6, 0, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e6, block.timestamp, v, r, s);
        token.permit(owner, address(0xCAFE), 1e6, block.timestamp, v, r, s);
    }

    function testMetadata(
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        address underlyingAgToken,
        address interestCollector,
        address manager

    ) public {
        WrappedAgToken tkn = new WrappedAgToken(name, symbol, decimals, underlyingAgToken, interestCollector, manager);
        assertEq(tkn.name(), name);
        assertEq(tkn.symbol(), symbol);
        assertEq(tkn.decimals(), decimals);
        assertEq(address(token.underlyingAgToken()), underlyingAgToken);
        assertEq(token.interestCollector(), interestCollector);
        assertEq(token.manager(), manager);
    }

    function testDeposit(address from, uint256 amount) public {
        token.deposit( amount);

        assertEq(token.totalSupply(), amount);
        assertEq(token.balanceOf(from), amount);
    }

    function testWithdraw(
        address from,
        uint256 depositAmount,
        uint256 withdrawAmount
    ) public {
        withdrawAmount = bound(withdrawAmount, 0, depositAmount);

        token.deposit( depositAmount);
        token.withdraw( withdrawAmount);

        assertEq(token.totalSupply(), depositAmount - withdrawAmount);
        assertEq(token.balanceOf(from), depositAmount - withdrawAmount);
    }

    function testApprove(address to, uint256 amount) public {
        assertTrue(token.approve(to, amount));

        assertEq(token.allowance(address(this), to), amount);
    }

    function testTransfer(address from, uint256 amount) public {
        token.deposit( amount);

        assertTrue(token.transfer(from, amount));
        assertEq(token.totalSupply(), amount);

        if (address(this) == from) {
            assertEq(token.balanceOf(address(this)), amount);
        } else {
            assertEq(token.balanceOf(address(this)), 0);
            assertEq(token.balanceOf(from), amount);
        }
    }

    function testTransferFrom(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        amount = bound(amount, 0, approval);

        address from = address(0xABCD);

        token.deposit( amount);

        vm.prank(from);
        token.approve(address(this), approval);

        assertTrue(token.transferFrom(from, to, amount));
        assertEq(token.totalSupply(), amount);

        uint256 app = from == address(this) || approval == type(uint256).max ? approval : approval - amount;
        assertEq(token.allowance(from, address(this)), app);

        if (from == to) {
            assertEq(token.balanceOf(from), amount);
        } else {
            assertEq(token.balanceOf(from), 0);
            assertEq(token.balanceOf(to), amount);
        }
    }

    function testPermit(
        uint248 privKey,
        address to,
        uint256 amount,
        uint256 deadline
    ) public {
        uint256 privateKey = privKey;
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

        assertEq(token.allowance(owner, to), amount);
        assertEq(token.nonces(owner), 1);
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
    */
}

