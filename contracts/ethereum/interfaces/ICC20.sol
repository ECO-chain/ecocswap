// SPDX-License-Identifier: GPL-3.0+
/*
 */

pragma solidity ^0.8.0;

/**
 * @dev Extra functions for cross chain tokens
 * contains extra functions for normal ERC20 tokens as well: name(),symbol() and decimals()
 */
interface ICC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the original symbol of the token on ECOCHAIN
     */
    function originalSymbol() external view returns (string memory);

    /**
     * @dev Returns the smart contract address of the token on ECOCHAIN
     / @dev Returns the zero address for WECOC token
     */
    function originalAddress() external view returns (address);

    /**
     * @dev Authorize an oracle,which has the privelege to issue tokens
     * @dev triggered only by admin
     * @param oracle - address of oracle
     */
    function authOracle(address oracle) external;

    /**
     * @dev Revoke the authority of an oracle
     * @dev triggered only by admin
     * @param oracle - address of oracle
     */
    function unauthOracle(address oracle) external;

    /**
     * @dev Creates tokens for a user. Should be triggered after the original tokens are locked
     * @dev triggered only by an oracle
     * @param requestId - the request id of locked tokens on ECOCHAIN
     * @param beneficiar - ethereum public address to which the new tokens will be issued
     * @param amount - amount of tokens
     * @return bool - true on success
     */
    function issue(
        uint256 requestId,
        address beneficiar,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice Can be triggered by owners of the token
     * @dev Burns tokens of a user. It is a prerequest to unlock an equal amount of tokens (or ECOC) on ECOCHAIN
     * @dev triggered only by the owner of the tokens
     * @param beneficiar - hex of the ecochain's (not ethereum) public address to which the original tokens will be unlocked
     * @param amount - amount of tokens. Should be equal or less of owner's balance
     * @return bool - true on success
     */
    function burn(address beneficiar, uint256 amount) external returns (bool);

    /* Events */
    event AuthOracleEvent(address oracle, bool authorized);
    event IssueEvent(
        address oracle,
        address beneficiar,
        uint256 amount,
        uint256 requestId
    );
    event BurnEvent(address burner, address beneficiar, uint256 amount);
}
