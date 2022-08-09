// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ICoordinator} from "../interfaces/ICoordinator.sol";
import {IUserProxy} from "../interfaces/IUserProxy.sol";

/// @notice ERC20 Token transfer hook adapter for the agave ConditionalSwapper.
/// @author Luigy-Lemon
/// @dev Requires ERC20 token where this adapter is imported to have the _Transfer() function with support for _beforeTokenTransfer and _afterTokenTransfer.
abstract contract ConditionalSwapperAdapter {
    ICoordinator ConditionalSwapper;
    address GPv2Settlement;

    constructor(address registryAddress) {
        ConditionalSwapper = ICoordinator(registryAddress);
        GPv2Settlement = ConditionalSwapper.GPv2Settlement();
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSFER HOOKS
    //////////////////////////////////////////////////////////////*/

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        // check if receiver is the GPv2Settlement contract to determine if there's a chance the Agave Swapper is being used
        if (to == GPv2Settlement) {
            //check if sender is a user associated with a registered proxy account
            address userProxyAddress = ConditionalSwapper.userProxyAddress(from);
            if (userProxyAddress != address(0)) {
                //initiates interaction with user proxy before settlement with the the token being sold and the amount being sent which is relevant for identifying a orderUId by iterating the "filledAmount[orderUId]"
                IUserProxy(userProxyAddress).beforeSettlement(
                    address(this),
                    amount
                );
            }
        }
    }

    function _afterTokenTransfer(
				address from,
				address to,
				uint256 amount
		) internal {
			// check if sender is the GPv2Settlement contract to determine if there's a chance the Agave Swapper is being used
			if (from == GPv2Settlement){ 

				//check if receiver is a proxy associated with a registered account
        	address proxyAddress = ConditionalSwapper.proxyOwnerAddress(to);
				if (proxyAddress != address(0)){ 
					//initiates interaction with user proxy after settlement with the token bought and the amount received which is relevant for identifying orderUId by iterating "filledAmount[orderUId]"
					IUserProxy(to).afterSettlement(address(this), amount);				
				}
			}
		}
}
