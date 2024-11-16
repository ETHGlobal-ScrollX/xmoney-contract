// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/ScrollXID.sol";
import "../src/ScrollXID-Controller.sol";

// forge script script/DeployContract.s.sol --broadcast --rpc-url customNetwork

/// @title Script to deploy XID and XIDController contracts
/// @notice This script deploys XID and XIDController contracts and performs necessary initialization
contract DeployContract is Script {
    function run() external {
        // Read the deployer's private key from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // Read the signer's address from environment variables
        // address signerAddress = vm.envAddress("SIGNER_ADDRESS");
        // Read the actual owner's address from environment variables
        // address ownerAddress = vm.envAddress("OWNER_ADDRESS");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy XID contract
        ScrollXID xid = new ScrollXID();

        // Set minting fee to 0.0069 ETH
        uint256 mintFee = 0.0001 ether;
        // Set annual renewal fee to 0.0069 ETH
        // Deploy XIDController contract with necessary parameters
        ScrollXIDController xidController = new ScrollXIDController(
            address(xid),
            // signerAddress,
            vm.addr(deployerPrivateKey),
            mintFee
        );

        // Set the controller address of XID contract to the newly deployed XIDController address
        xid.setController(address(xidController));

        // Transfer ownership of XID and XIDController to the actual owner
        // xid.transferOwnership(ownerAddress);
        // xidController.transferOwnership(ownerAddress);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Output deployed contract addresses for future use
        console.log("XID deployed at:", address(xid));
        console.log("XIDController deployed at:", address(xidController));
        // console.log("Ownership transferred to:", ownerAddress);
    }
}
