pragma solidity 0.4.21;

/**
 * @dev Interface of the cross chain contract for *RC20 standards, permissionless
 */
interface ICC20User {
    /**
     * @dev locks ERC20
     * @notice token holder must approve() first to this smart contract the amount of token
     * @notice the user must also send to contract an equal amount (or more) of ECOC thet gets by calling getGasCost()
     * @param tokenAddr - the token's ECRC20 smart contract address
     * @param beneficiarAddr is the public address on the target chain
     * @param networkId - the network Id according to https://chainlist.org/
     * @param amount - quantity of tokens
     */
    function lockERC20(
        address tokenAddr,
        uint256 beneficiarAddr,
        uint256 networkId,
        uint256 amount
    ) external payable;

    /**
     * @dev locks ECOC
     * @notice an equal amount of ECOC of the value getGasCost() will be automatically kept to pay gas costs on the target chain
     * @notice if ECOC sent are less than or equal of getGasCost() the transaction will revert
     * @param beneficiarAddr is the public address on the target chain
     * @param networkId - the network Id according to https://chainlist.org/
     */
    function lockECOC(uint256 beneficiarAddr, uint256 networkId)
        external
        payable;

    /**
     * @dev returns the admin fee rate
     * @param tokenAddr - the token's ECRC20 smart contract address
     * @param networkId - the network Id according to https://chainlist.org/
     * @return feeRate - 2 decimal places. It can be zero
     */
    function getAdminFee(address tokenAddr, uint256 networkId)
        external
        view
        returns (uint8 adminFee);

    /**
     * @dev returns the gas cost. It is the same for all assets at a specific time and different for each chain
     * @notice Use this return value to send ECOC when locking assets on ecochain
     * @param networkId - the network Id according to https://chainlist.org/
     * @return gasCost - The gas cost in ECOC. It is used to pay the oracle expenses when locking
     */
    function getGasCost(uint256 networkId)
        external
        view
        returns (uint256 gasCost);

    /**
     * @dev gets all requests for a specific public address of a chain (all assets)
     * @param beneficiarAddr is the public address on the target chain
     * @param networkId - the network Id according to https://chainlist.org/
     * @return requestId - Returns an array of locked ids for all locked assets of an owner
     */
    function getAllRequests(uint256 beneficiarAddr, uint256 networkId)
        external
        view
        returns (uint256[] requestId);

    /**
     * @dev returns  only the pending requsts for a specific public address of a chain (all assets)
     * @param beneficiarAddr is the public address on the target chain
     * @param networkId - the network Id according to https://chainlist.org/
     * @return requestId - Returns an array of of locked ids of pending only locks for all assets of an owner
     */
    function getPendingRequests(uint256 beneficiarAddr, uint256 networkId)
        external
        view
        returns (uint256[] requestId);

    /**
     * @dev checks if the txid of burned assets has been comleted (assets unlocked)
     * @param requestId - the id of the locked request
     * @return completed - Return a boolean(true if the wrapped asset is issued on the target chain)
     */
    function getTransferStatus(uint256 requestId)
        external
        view
        returns (bool completed);

    /**
     * @notice returns the total locked amount of an asset (token or ECOC).
     * @notice Oracle fees and admin fees are excluded
     * @dev pass the zero address if the asset is the ECOC
     * @param tokenAddr - ERC20 smart contract address or the zero address for ECOC
     * @return amount - total locked amount of the asset
     */
    function getLockedAssets(address tokenAddr)
        external
        view
        returns (uint256 amount);

    /**
     * @notice Gas costs in ECOC for the oracle which haven't already retrieved
     * @dev balance is topped up after an oracle triggers issued()
     * @param oracle - the oracle's address
     * @return amount - total ECOC as gas cost that hasn't been retrieved yet by oracle
     */
    function getOracleBalace(address oracle)
        external
        view
        returns (uint256 amount);

    /**
     * @dev balance of a token accumulated by admin fees and reduced with retrieveFees()
     * @param tokenAddr - ERC20 smart contract address
     * @return amount - total balance of the token
     */
    function getAdminBalace(address tokenAddr)
        external
        view
        returns (uint256 amount);

    /**
     * @dev total token accumulated by admin fees (includes allready withdrawn)
     * @param tokenAddr - ERC20 smart contract address
     * @return amount - total fees of the token
     */
    function getTotalAdminFee(address tokenAddr)
        external
        view
        returns (uint256 amount);

    /* Events */
    event LockERC20Event(
        address tokenAddr,
        uint256 beneficiarAddr,
        uint256 networkId,
        uint256 amount
    );
    event LockECOCEvent(
        uint256 beneficiarAddr,
        uint256 networkId,
        uint256 amount
    );
}
