// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/ScrollXMoney.sol";

/// @title Script to deploy ScrollXMoney contract
/// @notice This script deploys the ScrollXMoney contract
contract DeployScrollXMoney is Script {
    function run() external {
        // Read the deployer's private key from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy ScrollXMoney contract
        ScrollXMoney xmoney = new ScrollXMoney();

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Output deployed contract address
        console.log("ScrollXMoney deployed at:", address(xmoney));
    }
} 