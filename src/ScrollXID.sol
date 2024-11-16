// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ScrollXID is ERC721, Ownable {
    mapping(address => string) private _addressToUsername;
    string private _URI;
    address public controller;

    event Mint(
        address indexed user,
        uint256 indexed tokenId,
        string username
    );

    event Burn(address indexed user, uint256 indexed tokenId, string username);

    constructor() ERC721("XID", "XID") Ownable(msg.sender) {}

    function setController(address controller_) public onlyOwner {
        controller = controller_;
    }

    modifier isController() {
        require(msg.sender == controller, "ScrollXID: Caller is not the controller");
        _;
    }

    function mint(
        address user,
        string memory username
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

        emit Mint(user, tokenId, username);
    }

    function burn(address user) external isController {
        require(
            keccak256(abi.encodePacked(_addressToUsername[user])) !=
                keccak256(abi.encodePacked("")),
            "ScrollXID: No XID to burn"
        );

        _burnXID(user);
    }

    function _burnXID(address user) internal {
        string memory username = _addressToUsername[user];
        uint256 tokenId = getTokenIdByAddress(user);
        delete _addressToUsername[user];
        _burn(tokenId);
        emit Burn(user, tokenId, username);
    }

    function getTokenIdByUsername(
        string memory username
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(".x", username)));
    }

    function getAddressByUsername(
        string memory username
    ) public view returns (address) {
        uint256 tokenId = getTokenIdByUsername(username);
        if (!_exists(tokenId)) {
            revert("ScrollXID: Username is not registered");
        }
        return ownerOf(tokenId);
    }

    function getAddressByTokenId(uint256 tokenId) public view returns (address) {
        return ownerOf(tokenId);
    }

    function getUsernameByAddress(
        address user
    ) public view returns (string memory) {
        string memory username = _addressToUsername[user];
        if (bytes(username).length == 0) {
            revert("ScrollXID: Username is not registered");
        }
        return username;
    }

    function getTokenIdByAddress(address user) public view returns (uint256) {
        string memory username = _addressToUsername[user];
        if (bytes(username).length == 0) {
            revert("ScrollXID: Username is not registered");
        }
        return getTokenIdByUsername(username);
    }

    function getUsernameByTokenId(uint256 tokenId) public view returns (string memory) {
        address owner = ownerOf(tokenId);
        return _addressToUsername[owner];
    }

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

    function _baseURI() internal view override returns (string memory) {
        return _URI;
    }

    function setTokenURI(string memory newURI_) public onlyOwner {
        _URI = newURI_;
    }

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

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
