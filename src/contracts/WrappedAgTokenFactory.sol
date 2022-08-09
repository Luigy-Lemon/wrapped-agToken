// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "./WrappedAgToken.sol";
import "./interfaces/IAgaveProtocolDataProvider.sol";

/// @title Wrapped AgToken factory
/// @notice Deploys WrappedAgTokens and manages ownership and control over the interest collection.
contract WrappedAgTokenFactory {
    address public Collector;
    address public Governance;
    address public immutable Provider;
    address public Swapper;

    mapping(address => address) public unwrapped;

    /// @notice Emitted when the Governance of the factory is changed
    /// @param newGovernance The Governance after the Governance was changed
    event GovernanceChanged(address indexed newGovernance);

    /// @notice Emitted when the Collector of the factory is changed
    /// @param newCollector The Collector after the Collector was changed
    event CollectorChanged(address indexed newCollector);

    /// @notice Emitted when a new wrapper is created
    /// @param wrappedAgToken The address of the created wrapper
    /// @param name The name of the wrapper
    /// @param symbol The symbol of the wrapper
    /// @param decimals The decimals of the wrapper
    /// @param agToken The address of the agToken being wrapped
    event WrappedAgTokenCreated(
        address wrappedAgToken,
        string name,
        string symbol,
        uint8 decimals,
        address agToken
    );

    constructor(
        address dataProvider,
        address governanceAddress,
        address collectorAddress,
        address conditionalSwapper
    ) {
        Provider = dataProvider;
        Governance = governanceAddress;
        Collector = collectorAddress;
        Swapper = conditionalSwapper;
    }

    modifier isGovernance() {
        require(msg.sender == Governance, "UNAUTHORIZED");
        _;
    }

    /// @dev Deploys a wrapper with the given parameters
    /// @param name The name of the wrapper
    /// @param symbol The symbol of the wrapper
    /// @param decimals The decimals of the wrapper
    /// @param agTokenAddress The address of the agToken being wrapped
    function deploy(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address agTokenAddress
    ) internal returns (address newToken) {
        newToken = address(
            new WrappedAgToken{
                salt: keccak256(abi.encode(agTokenAddress, address(this)))
            }(
                name,
                symbol,
                decimals,
                agTokenAddress,
                Collector,
                Governance,
                Swapper
            )
        );
        unwrapped[newToken] = agTokenAddress;
        emit WrappedAgTokenCreated(
            newToken,
            name,
            symbol,
            decimals,
            agTokenAddress
        );
        return newToken;
    }

    function checkIfWrapperAlreadyExists(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address agTokenAddress
    ) public view returns (bool) {
        address predictedAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            keccak256(
                                abi.encode(agTokenAddress, address(this))
                            ),
                            keccak256(
                                abi.encodePacked(
                                    type(WrappedAgToken).creationCode,
                                    abi.encode(
                                        name,
                                        symbol,
                                        decimals,
                                        agTokenAddress,
                                        Collector,
                                        Governance,
                                        Swapper
                                    )
                                )
                            )
                        )
                    )
                )
            )
        );
        uint256 size;
        assembly {
            size := extcodesize(predictedAddress)
        }
        return (size > 0);
    }

    function deployWrappedAgTokens(uint256 limitDeployments)
        external
        returns (address[] memory deployedWrappers)
    {
        TokenData[] memory agTokens = IAgaveProtocolDataProvider(Provider)
            .getAllATokens();
        uint256 n = 0;
        uint256 d = 0;
        address[] memory deployed = new address[](limitDeployments);
        while (d < limitDeployments && n < agTokens.length) {
            // n = 0, limit = 2, agTokens.length = 5
            // type WrappedAgToken has the ERC20 methods required
            WrappedAgToken asset = WrappedAgToken(
                payable(agTokens[n].tokenAddress)
            );
            string memory assetName = string.concat("Wrapped ", asset.name());
            string memory assetSymbol = string.concat("w", asset.symbol());
            uint8 assetDecimals = asset.decimals();
            address assetAddress = agTokens[n].tokenAddress;
            if (
                checkIfWrapperAlreadyExists(
                    assetName,
                    assetSymbol,
                    assetDecimals,
                    assetAddress
                )
            ) {
                n++;
                continue;
            }
            address newWrapper = deploy(
                assetName,
                assetSymbol,
                assetDecimals,
                assetAddress
            );
            deployed[d] = newWrapper;
            n++;
            d++;
        }
        return deployed;
    }

    function getWrappedAgToken(address agTokenAddress)
        external
        view
        returns (address)
    {
        WrappedAgToken asset = WrappedAgToken(payable(agTokenAddress));
        string memory assetName = string.concat("Wrapped ", asset.name());
        string memory assetSymbol = string.concat("w", asset.symbol());
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                keccak256(
                                    abi.encode(agTokenAddress, address(this))
                                ),
                                keccak256(
                                    abi.encodePacked(
                                        type(WrappedAgToken).creationCode,
                                        abi.encode(
                                            assetName,
                                            assetSymbol,
                                            asset.decimals(),
                                            agTokenAddress,
                                            Collector,
                                            Governance,
                                            Swapper
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            );
    }

    function setNewGovernance(address governanceAddress) external isGovernance {
        Governance = governanceAddress;
        emit GovernanceChanged(governanceAddress);
    }

    function setNewCollector(address collectorAddress) external isGovernance {
        Collector = collectorAddress;
        emit CollectorChanged(collectorAddress);
    }

    function setNewSwapper(address swapperAddress) external isGovernance {
        Swapper = swapperAddress;
        emit CollectorChanged(swapperAddress);
    }

    function delegateNewManager(
        address[] calldata wrappedAgTokens,
        address newManager
    ) external isGovernance {
        require(wrappedAgTokens.length > 0, "Provide addresses");
        for (uint256 i = 0; i < wrappedAgTokens.length; i++) {
            require(
                unwrapped[wrappedAgTokens[i]] != address(0),
                "token does not exist"
            );
            WrappedAgToken(payable(wrappedAgTokens[i])).setManager(newManager);
        }
    }

    function delegateNewCollector(
        address[] calldata wrappedAgTokens,
        address newCollector
    ) external isGovernance {
        require(wrappedAgTokens.length > 0, "Provide addresses");
        for (uint256 i = 0; i < wrappedAgTokens.length; i++) {
            require(
                unwrapped[wrappedAgTokens[i]] != address(0),
                "token does not exist"
            );
            WrappedAgToken(payable(wrappedAgTokens[i])).setInterestCollector(
                newCollector
            );
        }
    }

    function delegateNewSwapper(
        address[] calldata wrappedAgTokens,
        address newSwapper
    ) external isGovernance {
        require(wrappedAgTokens.length > 0, "Provide addresses");
        for (uint256 i = 0; i < wrappedAgTokens.length; i++) {
            require(
                unwrapped[wrappedAgTokens[i]] != address(0),
                "token does not exist"
            );
            WrappedAgToken(payable(wrappedAgTokens[i])).setConditionalSwapper(
                newSwapper
            );
        }
    }

    receive() external payable {
        revert("Contract can only handle ERC20 tokens");
    }
}
