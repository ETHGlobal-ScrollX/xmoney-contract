// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "./ScrollXID.sol";

contract ScrollXIDController is Ownable, Nonces {
    using ECDSA for bytes32;

    ScrollXID public xID;
    address public signer;
    uint256 public mintFee;
    uint256 private immutable _cachedChainId;

    event SignerChanged(address indexed oldSigner, address indexed newSigner);
    event MintFeeChanged(uint256 oldFee, uint256 newFee);

    constructor(
        address XIDAddress,
        address signerAddress,
        uint256 price
    ) Ownable(msg.sender) {
        xID = ScrollXID(XIDAddress);
        signer = signerAddress;
        mintFee = price;
        _cachedChainId = block.chainid;
    }

    function verify(
        bytes32 hash,
        bytes memory signature
    ) public view returns (bool) {
        return ECDSA.recover(hash, signature) == signer;
    }

    function mint(
        string memory githubUsername,
        address user,
        uint256 expireAt,
        uint256 chainId,
        uint8 isFree,
        bytes memory signature
    ) external payable {
        require(chainId == _cachedChainId, "Invalid ChainId");
        
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                githubUsername,
                user,
                expireAt,
                chainId,
                _useNonce(user),
                isFree
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );

        require(expireAt >= block.timestamp, "Expired signature");
        require(verify(ethSignedMessageHash, signature), "Invalid signature");

        if (isFree == 0) {
            require(msg.value >= mintFee, "Insufficient mint fee");
        }

        xID.mint(user, githubUsername);
    }

    function setSigner(address newSigner) external onlyOwner {
        address oldSigner = signer;
        signer = newSigner;
        emit SignerChanged(oldSigner, newSigner);
    }

    function setMintFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = mintFee;
        mintFee = newFee;
        emit MintFeeChanged(oldFee, newFee);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}