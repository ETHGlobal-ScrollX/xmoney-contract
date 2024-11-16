// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title XID
 * @dev A contract for managing XID NFTs. This contract handles the minting, burning, and renewal of XID NFTs.
 * Each XID NFT is associated with a unique X username and has a registration period.
 */
contract ScrollX is ERC721, Ownable {
    // Mapping from user address to X username
    mapping(address => string) private _addressToUsername;

    // Base URI for all tokens
    string private _URI;

    // Address of the controller contract
    address public controller;

    // Registration related variables

    // Mapping from token ID to expiration time
    mapping(uint256 => uint256) private _tokenIdToExpirationTime;

    // Duration of registration period, default is 1 year
    uint256 public registrationDuration = 365 days;

    // Flag to enable/disable registration check
    bool public registrationCheckEnabled = false;

    // Events

    /**
     * @dev Emitted when a new XID is minted
     * @param user Address of the user receiving the XID
     * @param tokenId Token ID of the minted XID
     * @param username X username associated with the XID
     * @param expirationTime Expiration time of the XID registration
     */
    event Mint(
        address indexed user,
        uint256 indexed tokenId,
        string username,
        uint256 expirationTime
    );

    /**
     * @dev Emitted when an XID is burned
     * @param user Address of the user whose XID was burned
     * @param tokenId Token ID of the burned XID
     * @param username X username associated with the burned XID
     */
    event Burn(address indexed user, uint256 indexed tokenId, string username);

    /**
     * @dev Emitted when an XID registration is renewed
     * @param tokenId Token ID of the renewed XID
     * @param newExpirationTime New expiration time after renewal
     * @param renewalYears Number of years the registration was renewed for
     */
    event RegistrationRenewed(
        uint256 indexed tokenId,
        uint256 newExpirationTime,
        uint256 renewalYears
    );

    /**
     * @dev Emitted when the registration check is toggled
     * @param enabled New state of the registration check (true if enabled, false if disabled)
     */
    event RegistrationCheckToggled(bool enabled);

    /**
     * @dev Constructor initializes the ERC721 token with a name and a symbol.
     */
    constructor() ERC721("XID", "XID") Ownable(msg.sender) {}

    /**
     * @dev Sets the controller contract address. Only callable by the owner.
     * @param controller_ The address of the controller contract.
     */
    function setController(address controller_) public onlyOwner {
        controller = controller_;
    }

    /**
     * @dev Modifier to check if the caller is the controller contract.
     */
    modifier isController() {
        require(msg.sender == controller, "ScrollXID: Caller is not the controller");
        _;
    }

    /**
     * @dev Mints a new XID NFT. If the username is taken, it burns the old one first.
     * If the user already has an XID, it burns the old one before minting a new one.
     * @param user The address of the user who will receive the XID NFT.
     * @param username The X username to be associated with the XID NFT.
     * @param registrationYears The number of years to register the XID for.
     */
    function mint(
        address user,
        string memory username,
        uint256 registrationYears
    ) external isController {
        uint256 tokenId = getTokenIdByUsername(username);
        bool isTokenExist = _exists(tokenId);

        if (isTokenExist) {
            address existingUser = ownerOf(tokenId);
            require(
                existingUser != user,
                "ScrollXID: Username already taken by current user"
            );

            if (existingUser != address(0)) {
                _burnXID(existingUser);
            }
        }

        if (bytes(_addressToUsername[user]).length != 0) {
            _burnXID(user);
        }

        _safeMint(user, tokenId);
        _addressToUsername[user] = username;

        uint256 expirationTime = block.timestamp +
            (registrationYears * registrationDuration);
        _tokenIdToExpirationTime[tokenId] = expirationTime;

        emit Mint(user, tokenId, username, expirationTime);
    }

    /**
     * @dev Renews the registration of an existing XID NFT.
     * @param tokenId The ID of the token to renew.
     * @param renewalYears The number of years to renew the registration for.
     */
    function renew(
        uint256 tokenId,
        uint256 renewalYears
    ) external isController {
        require(_exists(tokenId), "ScrollXID: Token does not exist");
        require(
            renewalYears > 0,
            "ScrollXID: Renewal duration must be greater than 0"
        );
        require(
            registrationCheckEnabled,
            "ScrollXID: Registration check is not enabled"
        );

        uint256 currentTime = block.timestamp;
        uint256 extensionDuration = renewalYears * registrationDuration;
        uint256 newExpirationTime;

        if (currentTime > _tokenIdToExpirationTime[tokenId]) {
            newExpirationTime = currentTime + extensionDuration;
        } else {
            newExpirationTime =
                _tokenIdToExpirationTime[tokenId] +
                extensionDuration;
        }

        _tokenIdToExpirationTime[tokenId] = newExpirationTime;
        emit RegistrationRenewed(tokenId, newExpirationTime, renewalYears);
    }

    /**
     * @dev Burns a XID NFT owned by the specified user.
     * @param user The address of the user whose XID NFT will be burned.
     */
    function burn(address user) external isController {
        require(
            keccak256(abi.encodePacked(_addressToUsername[user])) !=
                keccak256(abi.encodePacked("")),
            "ScrollXID: No XID to burn"
        );

        _burnXID(user);
    }

    /**
     * @dev Internal function to burn a XID NFT.
     * @param user The address of the user whose XID NFT will be burned.
     */
    function _burnXID(address user) internal {
        string memory username = _addressToUsername[user];
        uint256 tokenId = getTokenIdByAddress(user);
        delete _addressToUsername[user];
        delete _tokenIdToExpirationTime[tokenId];
        _burn(tokenId);
        emit Burn(user, tokenId, username);
    }

    /**
     * @dev Generates a tokenId based on the X username.
     * @param username The X username.
     * @return The generated tokenId.
     */
    function getTokenIdByUsername(
        string memory username
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(".x", username)));
    }

    /**
     * @dev Retrieves the address of the owner of the XID associated with the given username.
     * @param username The X username.
     * @return The address of the owner.
     */
    function getAddressByUsername(
        string memory username
    ) public view returns (address) {
        uint256 tokenId = getTokenIdByUsername(username);
        if (!_exists(tokenId)) {
            revert("ScrollXID: Username is not registered");
        }
        if (!isRegistrationValid(tokenId)) {
            revert("ScrollXID: Registration expired");
        }
        return ownerOf(tokenId);
    }

    /**
     * @dev Retrieves the address of the owner of the given tokenId.
     * @param tokenId The tokenId of the XID.
     * @return The address of the owner.
     */
    function getAddressByTokenId(uint256 tokenId) public view returns (address) {
        address owner = ownerOf(tokenId);
        if (!isRegistrationValid(tokenId)) {
            revert("ScrollXID: Registration expired");
        }
        return owner;
    }

    /**
     * @dev Retrieves the X username associated with the given address.
     * @param user The address of the user.
     * @return The X username.
     */
    function getUsernameByAddress(
        address user
    ) public view returns (string memory) {
        string memory username = _addressToUsername[user];
        if (bytes(username).length == 0) {
            revert("ScrollXID: Username is not registered");
        }
        uint256 tokenId = getTokenIdByUsername(username);
        if (!isRegistrationValid(tokenId)) {
            revert("ScrollXID: Registration expired");
        }
        return username;
    }

    /**
     * @dev Retrieves the tokenId associated with the given address.
     * @param user The address of the user.
     * @return The tokenId.
     */
    function getTokenIdByAddress(address user) public view returns (uint256) {
        string memory username = _addressToUsername[user];
        if (bytes(username).length == 0) {
            revert("ScrollXID: Username is not registered");
        }
        uint256 tokenId = getTokenIdByUsername(username);
        if (!isRegistrationValid(tokenId)) {
            revert("ScrollXID: Registration expired");
        }
        return tokenId;
    }

    /**
     * @dev Retrieves the X username associated with the given tokenId.
     * @param tokenId The tokenId of the XID.
     * @return The X username.
     */
    function getUsernameByTokenId(uint256 tokenId) public view returns (string memory) {
        address owner = ownerOf(tokenId);
        if (!isRegistrationValid(tokenId)) {
            revert("ScrollXID: Registration expired");
        }
        return _addressToUsername[owner];
    }

    /**
     * @dev Checks if the registration for a given tokenId is valid.
     * @param tokenId The tokenId to check.
     * @return A boolean indicating whether the registration is valid.
     */
    function isRegistrationValid(uint256 tokenId) public view returns (bool) {
        if (!registrationCheckEnabled) {
            return true; // Always return true if registration check is disabled
        }
        return block.timestamp <= _tokenIdToExpirationTime[tokenId];
    }

    /**
     * @dev Sets the registration duration. Only callable by the owner.
     * @param newDuration The new registration duration in seconds.
     */
    function setRegistrationDuration(uint256 newDuration) external onlyOwner {
        registrationDuration = newDuration;
    }

    /**
     * @dev Enables or disables the registration check. Only callable by the owner.
     * @param enabled Boolean to enable or disable the registration check.
     */
    function setRegistrationCheckEnabled(bool enabled) external onlyOwner {
        registrationCheckEnabled = enabled;
        emit RegistrationCheckToggled(enabled);
    }

    /**
     * @dev Retrieves the registration expiration time for a given tokenId.
     * @param tokenId The tokenId to check.
     * @return The expiration time of the registration.
     */
    function getRegistrationExpirationTime(uint256 tokenId) public view returns (uint256) {
        return _tokenIdToExpirationTime[tokenId];
    }

    /**
     * @dev Internal function to handle updates to the token's ownership.
     * Ensures that XID tokens are non-transferable (soulbound).
     * @param to The address to transfer the token to.
     * @param tokenId The ID of the token to transfer.
     * @param auth The address that authorized the transfer.
     * @return The address of the previous owner of the token.
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner != address(0) && to != address(0)) {
            revert("ScrollXID: SoulBound, Transfer failed");
        }

        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Returns the base URI for all token URIs.
     * @return The base URI.
     */
    function _baseURI() internal view override returns (string memory) {
        return _URI;
    }

    /**
     * @dev Sets a new base URI for all tokens. Only callable by the owner.
     * @param newURI_ The new base URI.
     */
    function setTokenURI(string memory newURI_) public onlyOwner {
        _URI = newURI_;
    }

    /**
     * @dev Retrieves the token URI for the given tokenId.
     * @param tokenId The ID of the token to retrieve the URI for.
     * @return The token URI.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireOwned(tokenId);
        string memory username = getUsernameByTokenId(tokenId);
        return
            bytes(_URI).length > 0
                ? string(abi.encodePacked(_URI, username))
                : "";
    }

    /**
     * @dev Checks if a token exists.
     * @param tokenId The token ID to check.
     * @return bool Whether the token exists.
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
