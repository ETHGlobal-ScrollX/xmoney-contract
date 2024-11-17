// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ScrollXMoney {
    using SafeERC20 for IERC20;

    /**
     * @notice Batch transfer ERC20 tokens
     * @param token ERC20 token address
     * @param total Total transfer amount
     * @param recipients Array of recipient addresses
     * @param amounts Array of corresponding transfer amounts
     */
    function batchTransferERC20(
        address token,
        uint256 total,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        require(recipients.length == amounts.length, "Length mismatch");
        
        // 1. First transfer tokens from sender to contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), total);
        
        // 2. Distribute from contract to each recipient
        for (uint256 i = 0; i < recipients.length; i++) {
            IERC20(token).safeTransfer(recipients[i], amounts[i]);
        }
    }

    /**
     * @notice Batch transfer ETH
     * @param recipients Array of recipient addresses
     * @param amounts Array of corresponding transfer amounts
     */
    function batchTransferETH(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external payable {
        require(recipients.length == amounts.length, "Length mismatch");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            (bool success, ) = recipients[i].call{value: amounts[i]}("");
            require(success, "ETH transfer failed");
        }
    }
}
