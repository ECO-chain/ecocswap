pragma solidity 0.4.21;

/**
 * @dev Interface of the cross chain contract for *RC20 standards, permissionless
 */
interface ICC20User {
    /**
     * @dev locks ECRC20
     * @notice token holder must approve() first to this smart contract the amount of token
     * @notice the user must also send to contract an equal amount (or more) of ECOC thet gets by calling getGasCost()
     * @param tokenAddr - the token's ECRC20 smart contract address
     * @param beneficiarAddr is the public address on the target chain
     * @param networkId - the network Id according to https://chainlist.org/
     * @param amount - quantity of tokens
     */
    function lockECRC20(
        address tokenAddr,
        address beneficiarAddr,
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
    function lockECOC(address beneficiarAddr, uint256 networkId)
        external
        payable;

    /**
     * @dev returns the admin fee rate
     * @param tokenAddr - the token's ECRC20 smart contract address
     * @param networkId - the network Id according to https://chainlist.org/
     * @return feeRate - 2 decimal places. It can be zero
     */
    function getFeeRate(address tokenAddr, uint256 networkId)
        external
        view
        returns (uint8 adminFee);

    /**
     * @dev returns the gas cost. It is the same for all assets at a specific time and different for each chain
     * @notice Use this return value to send ECOC when locking assets on ecochain
     * @param networkId - the network Id according to https://chainlist.org/
     * @return uint256 - The gas cost in ECOC. It is used to pay to oracle the expenses (tx cost) when locking
     */
    function getGasCost(uint256 networkId)
        external
        view
        returns (uint256 gasCost);

    /**
     * @dev gets all requests for a specific public address of a chain (all assets)
     * @dev if networkId is zero then it returns all requests  of all chains
     * @param userAddr is the ecoc public address of the user
     * @param networkId - the network Id according to https://chainlist.org/
     * @return uint256[] - Returns an array of locked ids for all locked assets of a user
     */
    function getAllRequests(address userAddr, uint256 networkId)
        external
        view
        returns (uint256[] requestId);

    /**
     * @dev returns  only the pending requsts for a specific public address of a chain (all assets)
     * @dev if networkId is zero then it returns all pending requests of all chains
     * @param _userAddr is the ecoc public address of the user
     * @param networkId - the network Id according to https://chainlist.org/
     * @return uint256[] - Returns an array of of locked ids of pending only locks for all assets of an owner
     */
    function getPendingRequests(address _userAddr, uint256 networkId)
        external
        view
        returns (uint256[] requestId);

    /**
     * @notice returns statistics for an asset
     * @dev use zero addresss for ECOC
     * @param _assetAddr is the ECRC20 address
     * @return uint256 - locked amount
     * @return uint256 - pending amount
     * @return uint256 - totally locked
     * @return uint256 - totally ulocked
     * @return uint256 - admin fees in total
     */
    function getAssetInfo(address _assetAddr)
        external
        view
        returns (
            uint256 lockedAmount,
            uint256 pendingAmount,
            uint256 totalLocked,
            uint256 totalUnlocked,
            uint256 totalFees
        );

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

    /**
     * @notice checks if the specific address belongs to an oracle
     * @param oracle - address in question
     * @param networkId - the network Id according to https://chainlist.org/
     * @return bool - true if it is an oracle for the target chain
     */
    function isOracle(address oracle, uint256 networkId)
        external
        view
        returns (bool auth);

    /**
     * @notice returns information about a request
     * @param requestId - the request id
     * @return uint256 - the network id
     * @return address - creator's address of request
     * @return uint256 - beneficiar on target chain (address in hex)
     * @return address - the ECRC20 asset
     * @return uint256 - amount
     * @return uint256 - gas cost
     * @return uint256 - admin fee
     * @return uint256 - txid on target chain. Zero is returns if pending
     * @return bool - true on pending
     * @return bool - true on completed
     */
    function getRequestInfo(uint256 requestId)
        external
        view
        returns (
            uint256 networkId,
            address requester,
            uint256 beneficiar,
            address asset,
            uint256 amount,
            uint256 gasCosts,
            uint256 txid,
            bool pending,
            bool completed
        );

    /**
     * @notice returns information about a request
     * @param releaseId - the release id
     * @return uint256 - txid on target chain. Zero is returns if pending
     * @return uint256 - the network id
     * @return address - oracle address that carried out the unlocking
     * @return address - beneficiar public address
     * @return address - the ECRC20 asset
     * @return uint256 - amount
     */
    function getReleaseInfo(uint256 releaseId)
        external
        view
        returns (
            uint256 networkId,
            uint256 txid,
            address oracle,
            address beneficiar,
            address asset,
            uint256 amount
        );

    /* Events */
    event LockERC20Event(
        address tokenAddr,
        address beneficiarAddr,
        uint256 networkId,
        uint256 amount
    );
    event LockECOCEvent(
        address beneficiarAddr,
        uint256 networkId,
        uint256 amount
    );
}
