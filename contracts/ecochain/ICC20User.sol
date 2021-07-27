pragma solidity 0.4.21;

/**
 * @dev Interface of the cross chain contract for *RC20 standards, permissionless
 */
interface ICC20User {
    /**
     * @dev locks ERC20
     * beneficiarAddr is the public address on the target chain
     * token holder must approve() first to this smart contract the amount
     */
    function lockERC20(
        uint256 beneficiarAddr,
        uint16 networkId,
        uint256 amount
    ) external;

    /**
     * @dev locks ECOC
     * beneficiarAddr is the public address on the target chain
     */
    function lockECOC(uint256 beneficiarAddr, uint16 networkId)
        external
        payable;

    /**
     * @dev returns the admin fee
     */
    function getAdminFee(address tokenAddr, uint16 networkId)
        external
        view
        returns (uint16 adminFee);

    /**
     * @dev returns the gas fee
     */
    function getGasFee(uint16 networkId) external view returns (uint256 gasFee);

    /**
     * @dev gets all requsts for a specific public address of a chain (all assets)
     */
    function getAllRequests(uint256 beneficiarAddr, uint16 networkId)
        external
        view
        returns (uint256[] txid);

    /**
     * @dev returns  only the pending requsts for a specific public address of a chain (all assets)
     */
    function getPendingRequests(uint256 beneficiarAddr, uint16 networkId)
        external
        view
        returns (uint256[] txid);

    /**
     * @dev checks if the txid of burned assets has been comleted (assets unlocked)
     */
    function getTransferStatus(uint256 txid, uint16 networkId)
        external
        view
        returns (bool completed);

    /* Events */
    event LockERC20Event(
        uint256 beneficiarAddr,
        uint16 networkId,
        uint256 amount
    );
    event LockECOCEvent(
        uint256 beneficiarAddr,
        uint16 networkId,
        uint256 amount
    );
}
