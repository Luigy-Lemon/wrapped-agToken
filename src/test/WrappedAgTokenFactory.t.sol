// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {IAgToken} from "../contracts/interfaces/IAgToken.sol";
import {WrappedAgToken} from "../contracts/WrappedAgToken.sol";
import {IWrappedAgToken} from "../contracts/interfaces/IWrappedAgToken.sol";
import {WrappedAgTokenFactory} from "../contracts/WrappedAgTokenFactory.sol";
import {TokenData, IAgaveProtocolDataProvider} from "../contracts/interfaces/IAgaveProtocolDataProvider.sol";

contract WrappedAgTokenTest is Test {
    WrappedAgTokenFactory token;

    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    function setUp() public {
        vm.startPrank(0xb4c575308221CAA398e0DD2cDEB6B2f10d7b000A);
        token = new WrappedAgTokenFactory(
            0x24dCbd376Db23e4771375092344f5CbEA3541FC0, // Provider
            0xb4c575308221CAA398e0DD2cDEB6B2f10d7b000A, // Governance
            0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe // Collector
        );
        vm.stopPrank();
    }

    function invariantMetadata() public {
        assertEq(
            address(token.Provider()),
            0x24dCbd376Db23e4771375092344f5CbEA3541FC0
        );
        assertEq(
            token.Governance(),
            0xb4c575308221CAA398e0DD2cDEB6B2f10d7b000A
        );
        assertEq(token.Collector(), 0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
    }

    function testIsGovernance() public {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        assertEq(
            0xb4c575308221CAA398e0DD2cDEB6B2f10d7b000A,
            token.Governance()
        );
        vm.stopPrank();
    }

    function testReceive(uint256 amount) public {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        vm.deal(msg.sender, amount);
        (bool success, ) = address(token).call(abi.encodeWithSignature(""));
        assertFalse(success);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    function testDeployWrappedAgTokens() public {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        uint256 limitDeployments;
        uint256(bound(limitDeployments, 1, 128));
        token.deployWrappedAgTokens(limitDeployments);
        vm.stopPrank();
    }

    function testCheckIfWrapperAlreadyExistsEmpty() external {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        TokenData[] memory agTokens = IAgaveProtocolDataProvider(
            token.Provider()
        ).getAllATokens();

        // Create wrapper token
        IWrappedAgToken asset = IWrappedAgToken(
            payable(agTokens[0].tokenAddress)
        );
        string memory assetName = string.concat("Wrapped ", asset.name());
        string memory assetSymbol = string.concat("w", asset.symbol());
        uint8 assetDecimals = asset.decimals();
        address assetAddress = address(asset);
        bool exists = token.checkIfWrapperAlreadyExists(
            assetName,
            assetSymbol,
            assetDecimals,
            assetAddress
        );
        assertFalse(exists);
        vm.stopPrank();
    }

    function testCheckIfWrapperAlreadyExists_PopulatedButNoMatch() external {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        TokenData[] memory agTokens = IAgaveProtocolDataProvider(
            token.Provider()
        ).getAllATokens();

        token.deployWrappedAgTokens(2);

        // Create wrapper token
        IWrappedAgToken asset = IWrappedAgToken(
            payable(agTokens[3].tokenAddress)
        );
        string memory assetName = string.concat("Wrapped ", asset.name());
        string memory assetSymbol = string.concat("w", asset.symbol());
        uint8 assetDecimals = asset.decimals();
        address assetAddress = address(asset);

        bool exists = token.checkIfWrapperAlreadyExists(
            assetName,
            assetSymbol,
            assetDecimals,
            assetAddress
        );
        assertFalse(exists);

        vm.stopPrank();
    }

    function testCheckIfWrapperAlreadyExists_PopulatedWithMatch() external {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        TokenData[] memory agTokens = IAgaveProtocolDataProvider(
            token.Provider()
        ).getAllATokens();

        address[] memory deployed = token.deployWrappedAgTokens(3);

        // Test existence of wrapper tokens
        for (uint256 i = 0; i < deployed.length; i++) {
            IWrappedAgToken asset = IWrappedAgToken(
                payable(agTokens[i].tokenAddress)
            );
            string memory assetName = string.concat("Wrapped ", asset.name());
            string memory assetSymbol = string.concat("w", asset.symbol());
            uint8 assetDecimals = asset.decimals();
            address assetAddress = address(asset);
            bool exists = token.checkIfWrapperAlreadyExists(
                assetName,
                assetSymbol,
                assetDecimals,
                assetAddress
            );
            assertFalse(!exists);
        }
        vm.stopPrank();
    }

    function testPredictedAddress() external {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        TokenData[] memory agTokens = IAgaveProtocolDataProvider(
            token.Provider()
        ).getAllATokens();

        address[] memory deployed = token.deployWrappedAgTokens(3);

        for (uint256 i = 0; i < deployed.length; i++) {
            IWrappedAgToken asset = IWrappedAgToken(
                payable(agTokens[i].tokenAddress)
            );
            string memory assetName = string.concat("Wrapped ", asset.name());
            string memory assetSymbol = string.concat("w", asset.symbol());
            uint8 assetDecimals = asset.decimals();
            address assetAddress = address(asset);
            address predictedAddress = address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(token),
                                keccak256(
                                    abi.encode(assetAddress, address(token))
                                ),
                                keccak256(
                                    abi.encodePacked(
                                        type(WrappedAgToken).creationCode,
                                        abi.encode(
                                            assetName,
                                            assetSymbol,
                                            assetDecimals,
                                            assetAddress,
                                            token.Collector(),
                                            token.Governance()
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            );
            assertEq(deployed[i], predictedAddress);
        }
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE LOGIC
    //////////////////////////////////////////////////////////////*/

    function testSetNewCollector(address newCollector) external {
        address Governance = token.Governance();
        vm.startPrank(Governance);
        token.setNewCollector(newCollector);
        assertEq(newCollector, token.Collector());
        vm.stopPrank();
    }

    function testFailSetNewCollector(address newCollector) external {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        token.setNewCollector(newCollector);
        assertEq(newCollector, token.Collector());
        vm.stopPrank();
    }

    function testSetNewGovernance(address newGovernance) external {
        address Governance = token.Governance();
        vm.startPrank(Governance);
        token.setNewGovernance(newGovernance);
        assertEq(newGovernance, token.Governance());
        vm.stopPrank();
    }

    function testFailSetNewGovernance(address newGovernance) external {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        token.setNewGovernance(newGovernance);
        assertEq(newGovernance, token.Governance());
        vm.stopPrank();
    }

    function testDelegateNewManager(address newManager) external {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        address[] memory deployed = token.deployWrappedAgTokens(2);
        vm.stopPrank();
        address Governance = token.Governance();
        vm.startPrank(Governance);
        token.delegateNewManager(deployed, newManager);
        assertEq(newManager, IWrappedAgToken(payable(deployed[0])).manager());
        assertEq(newManager, IWrappedAgToken(payable(deployed[1])).manager());
        vm.stopPrank();
    }

    function testDelegateNewCollector(address newCollector) external {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        address[] memory deployed = token.deployWrappedAgTokens(2);
        vm.stopPrank();
        address Governance = token.Governance();
        vm.startPrank(Governance);
        token.delegateNewCollector(deployed, newCollector);
        assertEq(
            newCollector,
            IWrappedAgToken(payable(deployed[0])).interestCollector()
        );
        assertEq(
            newCollector,
            IWrappedAgToken(payable(deployed[1])).interestCollector()
        );
        vm.stopPrank();
    }

    function testFailDelegateNewManager_NotGovernance(address newManager) external {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        address[] memory deployed = token.deployWrappedAgTokens(2);
        vm.stopPrank();
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        token.delegateNewManager(deployed, newManager);
        assertEq(newManager, IWrappedAgToken(payable(deployed[0])).manager());
        assertEq(newManager, IWrappedAgToken(payable(deployed[1])).manager());
        vm.stopPrank();
    }

    function testFailDelegateNewManager_NotDeployed(address newManager) external {
        address[] memory deployed = new address[](2);
        deployed[0] = 0x1beEEEeEEEeEEeeeEEeeeeeeEeEEEeeeeeeeEeE1;
        deployed[1] = 0x1beeEEeeEEEEEEEEeEeEeEeeEEeEEEeeEEEEeEE2;
        address Governance = token.Governance();
        vm.startPrank(Governance);
        token.delegateNewManager(deployed, newManager);
        assertEq(newManager, IWrappedAgToken(deployed[0] ).manager());
        assertEq(newManager, IWrappedAgToken(deployed[1]).manager());
        vm.stopPrank();
    }

    function testFailDelegateNewCollector(address newCollector) external {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        address[] memory deployed = token.deployWrappedAgTokens(2);
        vm.stopPrank();
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        token.delegateNewManager(deployed, newCollector);
        assertEq(
            newCollector, 
            IWrappedAgToken(payable(deployed[0])).interestCollector()
        );
        assertEq(
            newCollector,
            IWrappedAgToken(payable(deployed[1])).interestCollector()
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function testGetWrappedAgToken() public {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        TokenData[] memory agTokens = IAgaveProtocolDataProvider(
            token.Provider()
        ).getAllATokens();
        address[] memory deployed = token.deployWrappedAgTokens(3);
        vm.stopPrank();
        address wrappedAg0 = token.getWrappedAgToken(agTokens[0].tokenAddress);
        address wrappedAg1 = token.getWrappedAgToken(agTokens[1].tokenAddress);
        address wrappedAg2 = token.getWrappedAgToken(agTokens[2].tokenAddress);
        assertEq(deployed[0], wrappedAg0);
        assertEq(deployed[1], wrappedAg1);
        assertEq(deployed[2], wrappedAg2);
    }
}
