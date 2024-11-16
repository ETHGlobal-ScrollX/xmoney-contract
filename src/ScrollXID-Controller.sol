// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "./ScrollX.sol";

/**
 * @title XIDController
 * @dev A controller contract for managing XID NFTs. This contract handles the minting and renewal of XID NFTs.
 * It uses signatures to verify the authenticity of mint and renew requests.
 */
contract XIDController is Ownable, Nonces {
    using ECDSA for bytes32;

    // Reference to the XID contract
    ScrollX public xID;
    
    // Address of the signer who is authorized to sign minting and renewal messages
    address public signer;

    // Minting fee
    uint256 public mintFee;

    // Renewal fee per year
    uint256 public renewalFeePerYear;

    // Cache the chain ID for checking during minting and renewal
    uint256 private immutable _cachedChainId;

    // Events

    /**
     * @dev Emitted when the signer address is changed
     * @param oldSigner The previous signer address
     * @param newSigner The new signer address
     */
    event SignerChanged(address indexed oldSigner, address indexed newSigner);

    /**
     * @dev Emitted when the minting fee is changed
     * @param oldFee The previous minting fee
     * @param newFee The new minting fee
     */
    event MintFeeChanged(uint256 oldFee, uint256 newFee);

    /**
     * @dev Emitted when the renewal fee per year is changed
     * @param oldFee The previous renewal fee per year
     * @param newFee The new renewal fee per year
     */
    event RenewalFeePerYearChanged(uint256 oldFee, uint256 newFee);

    /**
     * @dev Constructor sets the XID contract address and the initial signer address.
     * @param XIDAddress The address of the XID contract.
     * @param signerAddress The initial signer address.
     * @param price The initial minting fee.
     * @param renewPricePerYear The initial renewal fee per year.
     */
    constructor(
        address XIDAddress,
        address signerAddress,
        uint256 price,
        uint256 renewPricePerYear
    ) Ownable(msg.sender) {
        xID = ScrollX(XIDAddress);
        signer = signerAddress;
        mintFee = price;
        renewalFeePerYear = renewPricePerYear;
        _cachedChainId = block.chainid;
    }

    /**
     * @dev Verifies the signature for a given hash.
     * @param hash The hash of the message.
     * @param signature The signature to verify.
     * @return True if the signature is valid, false otherwise.
     */
    function verify(
        bytes32 hash,
        bytes memory signature
    ) public view returns (bool) {
        return ECDSA.recover(hash, signature) == signer;
    }

    /**
     * @dev Mints a new XID NFT if the provided signature is valid.
     * @param githubUsername The GitHub username to be associated with the XID NFT.
     * @param user The address of the user who will receive the XID NFT.
     * @param expireAt The expiration time of the signature.
     * @param chainId The chain ID.
     * @param isFree Indicates if the minting is free (1 for free, 0 otherwise).
     * @param registrationYears The number of years to register the XID for.
     * @param signature The signature to verify the mint request.
     */
    function mint(
        string memory githubUsername,
        address user,
        uint256 expireAt,
        uint256 chainId,
        uint8 isFree,
        uint256 registrationYears,
        bytes memory signature
    ) external payable {
        require(chainId == _cachedChainId, "Invalid ChainId");
        require(registrationYears >= 1, "Registration years must be at least 1");
        // Get message hash for minting
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                githubUsername,
                user,
                expireAt,
                chainId,
                _useNonce(user),
                isFree,
                registrationYears
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );

        require(expireAt >= block.timestamp, "Expired signature");
        require(verify(ethSignedMessageHash, signature), "Invalid signature");

        // Check if the user is minting for the first time
        if (isFree == 0) {
            uint256 totalFee = mintFee;
            if (xID.registrationCheckEnabled()) {
                totalFee += renewalFeePerYear * (registrationYears - 1);
            }
            require(msg.value >= totalFee, "Insufficient mint fee");
        }

        xID.mint(user, githubUsername, registrationYears);
    }

    /**
     * @dev Renews an existing XID NFT if the provided signature is valid.
     * @param githubUsername The GitHub username associated with the XID NFT.
     * @param user The address of the user who owns the XID NFT.
     * @param expireAt The expiration time of the signature.
     * @param chainId The chain ID.
     * @param renewalYears The number of years to renew the XID for.
     * @param signature The signature to verify the renewal request.
     */
    function renew(
        string memory githubUsername,
        address user,
        uint256 expireAt,
        uint256 chainId,
        uint256 renewalYears,
        bytes memory signature
    ) external payable {
        require(chainId == _cachedChainId, "Invalid ChainId");
        require(renewalYears >= 1, "Renewal years must be greater than 1");
        // Get message hash for renewal
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                githubUsername,
                user,
                expireAt,
                chainId,
                _useNonce(user),
                renewalYears
            )
        );
        // Get eth signed message hash
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );
    
        require(expireAt >= block.timestamp, "Expired signature");
        require(verify(ethSignedMessageHash, signature), "Invalid signature");

        uint256 tokenId = xID.getTokenIdByUsername(githubUsername);
        require(xID.ownerOf(tokenId) == user, "User does not own this XID");

        uint256 totalFee = renewalFeePerYear * renewalYears;
        require(msg.value >= totalFee, "Insufficient renewal fee");

        xID.renew(tokenId, renewalYears);
    }

    /**
     * @dev Sets a new signer address. Only callable by the owner.
     * @param newSigner The new signer address.
     */
    function setSigner(address newSigner) external onlyOwner {
        address oldSigner = signer;
        signer = newSigner;
        emit SignerChanged(oldSigner, newSigner);
    }

    /**
     * @dev Sets a new mint fee. Only callable by the owner.
     * @param newFee The new mint fee.
     */
    function setMintFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = mintFee;
        mintFee = newFee;
        emit MintFeeChanged(oldFee, newFee);
    }

    /**
     * @dev Sets a new renewal fee per year. Only callable by the owner.
     * @param newFee The new renewal fee per year.
     */
    function setRenewalFeePerYear(uint256 newFee) external onlyOwner {
        uint256 oldFee = renewalFeePerYear;
        renewalFeePerYear = newFee;
        emit RenewalFeePerYearChanged(oldFee, newFee);
    }

    /**
     * @dev Withdraws the contract balance to the owner's address.
     * Can only be called by the owner.
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}