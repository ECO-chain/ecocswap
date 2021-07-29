pragma solidity 0.4.21;

/**
 * @dev Interface of the cross chain contract for *RC20 standards, oracles only
 */
interface ICC20Oracle {
    /**
     * @dev unlocks ECRC20 tokens after detecting that tokens are burned on target chain
     * @notice gas is paid by oracle
     * @notice if admin fee is non-zero, keep the fee; by default is zero
     * @param tokenAddr - the token's ECRC20 smart contract address
     * @param beneficiar - adress to where the tokens to be sent
     * @param networkId - the network Id according to https://chainlist.org/
     * @param txid - the transaction id of the burned tokens.
     * @param amount - quantity of tokens
     */
    function unlockERC20(
        address tokenAddr,
        address beneficiar,
        uint256 networkId,
        uint256 txid,
        uint256 amount
    ) external;

    /**
     * @dev unlocks ECOC after detecting that WECOC is burned on target chain
     * @notice gas is paid by oracle
     * @notice There is no admin fee for ECOC for any chain
     * @param beneficiar - adress to where the ECOC to be sent
     * @param networkId - the network Id according to https://chainlist.org/
     * @param txid - the transaction id of the burned tokens
     */
    function unlockECOC(
        uint256 beneficiarAddr,
        uint256 networkId,
        uint256 txid
    ) external payable;

    /**
     * @dev informs teh smart contract that the wrapped token has been issued on target chain
     * must be triggered by the oracle after the issue() on target chain is confirmed
     * @param requestId - the request id of locking
     * @param txid - the transaction id of the issued tokens on the target chain
     */
    function issued(uint256 requestId, uint256 txid) external;

    /**
     * @dev This function should be called often; It sets the gas cost of the target chain
     * @notice This cost is the same for any asset(including ECOC) for a specific chain. ECOC is
     * a wrapped token on other chains (*RC20) so the transfer cost is the same
     * @param fee - cost in ECOC of the issue() of wrapped tokens. It can't be zero
     * @param networkId - the network Id according to https://chainlist.org/
     */
    function setGasCost(uint256 fee, uint256 networkId) external;

    /**
     * @dev retrieves (withdraws) accumulated gasCost (the whole balance of an oracle)
     * @dev it fails on zero balance
     */
    function retrieveGasCosts() external payable;

    /* Events */
    event UnlockERC20Event(
        address tokenAddr,
        address beneficiar,
        uint256 networkId,
        uint256 amount
    );
    event UnlockECOCEvent(
        address beneficiar,
        uint256 networkId,
        uint256 amount,
        uint256 txid
    );
    event IssuedEvent(address oracle, uint256 requestId, uint256 txid);
    event SetGasCostEvent(uint256 fee, uint256 networkId, uint256 txid);
    event RetrieveGasCostEvent(address oracle, uint256 amount);
}
