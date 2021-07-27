pragma solidity 0.4.21;

/**
 * @dev Interface of the cross chain contract for *RC20 standards, admin only
 */
interface ICC20Admin {
    /**
     * @dev set admin fee for a token(can be zero)
     * It can't be higher than maxAdminFee (1%)
     * it can be edited at any time. The same restrictions apply (range 0-1%)
     */
    function setAdminFee(
        address tokenAddr,
        uint16 networkId,
        uint16 fee
    ) external;

    /**
     * @dev authorizes an oracle for a specific chain
     */
    function addOracle(address oracle, uint16 networkId) external;

    /**
     * * @dev revokes authorization of an oracle for a specific chain
     */
    function removeOracle(address oracle, uint16 networkId) external;

    /**
     * @dev adds an ECRC20 token for a specific chain
     * fee can be set to zero
     */
    function addAsset(
        address tokenAddr,
        uint16 networkId,
        uint16 fee
    ) external;

    /**
     * @dev retrieves accumilated admin fees of a token or ECOC to cold wallet
     * for ECOC must pass the zero address
     */
    function retrieveFees(address tokenAddr, uint16 amount) external payable;

    /* Events */
    event SetAdminFeeEvent(address tokenAddr, uint16 networkId, uint16 fee);
    event AddOracleEvent(address oracle, uint16 networkId);
    event RemoveOracleEvent(address oracle, uint16 networkId);
    event AddAssetEvent(address tokenAddr, uint16 networkId, uint16 fee);
    event RetrieveFeesEvent(address tokenAddr, uint16 amount);
}
