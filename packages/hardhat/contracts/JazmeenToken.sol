// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JazmeenToken is ERC20 {
    uint256 public initiatorFid; // FID of the Farcaster user who initiated
    string public imageUrl;      // Token image URL
    address public owner; // Agent who received the tokens

    event MetadataUpdated(string newImageUrl);

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address agent,        // Bot/agent receives tokens
        uint256 _initiatorFid, // FID of the user who requested it
        string memory _imageUrl
    ) ERC20(name, symbol) {
        _mint(agent, totalSupply * 10**18);
        initiatorFid = _initiatorFid;
        imageUrl = _imageUrl;
        owner = agent;
    }

    function updateImageUrl(string memory newImageUrl) external {
        require(msg.sender == owner, "Only agent can update image URL");
        imageUrl = newImageUrl;
        emit MetadataUpdated(newImageUrl);
    }
}