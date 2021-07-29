pragma solidity 0.4.21;

/**
 * @dev Interface of the cross chain contract for *RC20 standards, admin only
 */
interface ICC20Admin {
    /**
     * @dev set admin fee for a token(can be zero)
     * It can't be higher than maxAdminFee (1%)
     * it can be edited at any time. The same restrictions apply (range 0-1%)
     * @param tokenAddr - the token's ECRC20 smart contract address
     * @param networkId - the network Id according to https://chainlist.org/
     * @param feeRate - the fee rate has two decimals.
     */
    function setAdminFee(
        address tokenAddr,
        uint256 networkId,
        uint8 feeRate
    ) external;

    /**
     * @dev authorizes an oracle for a specific chain
     * @param oracle - oracle address for all assets of a chain
     * @param networkId - the network Id according to https://chainlist.org/
     */
    function addOracle(address oracle, uint256 networkId) external;

    /**
     * @dev revokes authorization of an oracle for a specific chain
     * @param oracle - oracle address for all assets of a chain
     * @param networkId - the network Id according to https://chainlist.org/
     */
    function removeOracle(address oracle, uint256 networkId) external;

    /**
     * @dev adds an ECRC20 token for a specific chain
     * fee rate can be set to zero
     * @param tokenAddr - the token's ECRC20 smart contract address
     * @param networkId - the network Id according to https://chainlist.org/
     * @param feeRate - the fee rate has two decimals.
     */
    function addAsset(
        address tokenAddr,
        uint256 networkId,
        uint8 feeRate
    ) external;

    /**
     * @dev retrieves (withdraws) accumulated admin fees of a token or ECOC to cold wallet
     * for ECOC must pass the zero address
     * @param oracle - oracle address for all assets of a chain
     * @param amount - If amount is set to zero then the whole balance of the token will be retrieved
     */
    function retrieveFees(address tokenAddr, uint256 amount) external payable;

    /* Events */
    event SetAdminFeeEvent(address tokenAddr, uint256 networkId, uint8 feeRate);
    event AddOracleEvent(address oracle, uint256 networkId);
    event RemoveOracleEvent(address oracle, uint256 networkId);
    event AddAssetEvent(address tokenAddr, uint256 networkId, uint8 feeRate);
    event RetrieveFeesEvent(address tokenAddr, uint256 amount);
}
