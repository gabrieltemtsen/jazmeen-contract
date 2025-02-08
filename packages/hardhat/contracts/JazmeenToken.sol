// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JazmeenToken is ERC20 {
    address public creator;
    string public tokenImageUrl;

    event MetadataUpdated(string newImageUrl);

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address _creator,
        string memory _imageUrl
    ) ERC20(name, symbol) {
        creator = _creator;
        tokenImageUrl = _imageUrl;

        // Mint full initial supply to the creator
        _mint(_creator, initialSupply * (10 ** decimals()));
    }

    function updateMetadata(string memory newImageUrl) external {
        require(msg.sender == creator, "Only the creator can update metadata");
        tokenImageUrl = newImageUrl;
        emit MetadataUpdated(newImageUrl);
    }
}
