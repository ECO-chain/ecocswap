pragma solidity 0.4.21;

/**
 * @dev Interface of the cross chain contract for *RC20 standards, oracles only
 */
interface ICC20Oracle {
    /**
     * @dev unlocks ECRC20 tokens after detecting that tokens are burned on target chain
     * gas is paid by oracle
     * if admin fee is non-zero, keep the fee; by default is zero
     * networkId specifies the blockchain of burned tokens
     * txid is the transaction ID of the burned assets
     */
    function unlockERC20(
        address tokenAddr,
        address beneficiar,
        uint16 networkId,
        uint256 txid,
        uint256 amount
    ) external;

    /**
     * @dev unlocks ECOC after detecting that WECOC is burned on target chain
     * gas is paid by oracle
     * There is no admin fee for ECOC for any chain
     * txid is the transaction ID of the burned assets
     */
    function unlockECOC(
        uint256 beneficiarAddr,
        uint16 networkId,
        uint256 txid
    ) external payable;

    /**
     * @dev This function should be called often; It sets the gas cost of the target chain
     * This cost is the same for anny asset(including ECOC) for a specific chain. ECOC is
     * a wrapped token on other chains (*RC20) so the transfer cost is the same
     */
    function setGasFee(uint256 fee, uint16 networkId) external;

    /* Events */
    event UnlockERC20Event(
        address tokenAddr,
        address beneficiar,
        uint16 networkId,
        uint256 amount
    );
    event UnlockECOCEvent(
        address beneficiar,
        uint16 networkId,
        uint256 amount,
        uint256 txid
    );
    event SetGasFeeEvent(uint256 fee, uint16 networkId, uint256 txid);
}
