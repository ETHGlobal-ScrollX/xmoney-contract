// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "../src/ScrollXID-Controller.sol";
import "../src/ScrollXID.sol";

// forge script script/MintNFTWithSignature.s.sol --broadcast --rpc-url customNetwork

contract MintNFTWithSignatureScript is Script, Nonces {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address xidControllerAddress = vm.envAddress("XID_CONTROLLER_ADDRESS");
        ScrollXIDController xidController = ScrollXIDController(xidControllerAddress);

        address user = 0xd015fE70Fd9010Fa727f756CE730975Dd6145F62;
        uint256 nonce = _useNonce(user);
        MintParams memory params = getMintParams(nonce);
        bytes32 messageHash = getMessageHash(params);
        bytes memory signature = getSignature(deployerPrivateKey, messageHash);

        uint256 totalFee = getTotalFee(xidController, params.registrationYears);

        xidController.mint{value: totalFee}(
            params.githubUsername,
            params.user,
            params.expireAt,
            params.chainId,
            params.isFree,
            signature
        );

        vm.stopBroadcast();
        console.log("NFT minted for user:", params.user);
    }

    struct MintParams {
        string githubUsername;
        address user;
        uint256 expireAt;
        uint256 chainId;
        uint256 nonce;
        uint8 isFree;
        uint256 registrationYears;
    }

    function getMintParams(
        uint256 nonce
    ) internal view returns (MintParams memory) {
        return
            MintParams({
                githubUsername: "elonmusk",
                user: 0xd015fE70Fd9010Fa727f756CE730975Dd6145F62,
                expireAt: block.timestamp + 1 days,
                chainId: 534351,
                nonce: nonce,
                isFree: 1,
                registrationYears: 1
            });
    }

    function getMessageHash(
        MintParams memory params
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    params.githubUsername,
                    params.user,
                    params.expireAt,
                    params.chainId,
                    params.nonce,
                    params.isFree
                )
            ).toEthSignedMessageHash();
    }

    function getSignature(
        uint256 privateKey,
        bytes32 messageHash
    ) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        return abi.encodePacked(r, s, v);
    }

    function getTotalFee(
        ScrollXIDController xidController,
        uint256 registrationYears
    ) internal view returns (uint256) {
        // Implement your logic to calculate the total fee based on registrationYears
        // For example, you can use xidController.getTotalFee(registrationYears)
        // to get the total fee for the given registrationYears
        return 0;
    }

}
