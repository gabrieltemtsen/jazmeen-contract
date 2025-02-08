// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./JazmeenToken.sol";

contract JazmeenFactory {
    address public jazmeenDeployer;

    struct TokenInfo {
        address tokenAddress;
        string name;
        string symbol;
        string imageUrl;
        address creator;
    }

    TokenInfo[] public tokens;

    event TokenDeployed(address indexed creator, address tokenAddress, string name, string symbol);

    constructor(address _jazmeenDeployer) {
        jazmeenDeployer = _jazmeenDeployer;
    }

    function deployToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        string memory imageUrl
    ) external {
        JazmeenToken newToken = new JazmeenToken(
            name,
            symbol,
            initialSupply,
            msg.sender,
            imageUrl
        );

        tokens.push(TokenInfo(address(newToken), name, symbol, imageUrl, msg.sender));

        emit TokenDeployed(msg.sender, address(newToken), name, symbol);
    }

    function getTokens() external view returns (TokenInfo[] memory) {
        return tokens;
    }
}
