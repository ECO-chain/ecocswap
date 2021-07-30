/* License: GPL-3.0 https://www.gnu.org/licenses/gpl-3.0.en.html */

pragma solidity 0.4.21;

contract ECRC20 {
    function totalSupply() public constant returns (uint256);

    function balanceOf(address tokenOwner)
        public
        constant
        returns (uint256 balance);

    function allowance(address tokenOwner, address spender)
        public
        constant
        returns (uint256 remaining);

    function transfer(address to, uint256 tokens) public returns (bool success);

    function approve(address spender, uint256 tokens)
        public
        returns (bool success);

    function transferFrom(
        address from,
        address to,
        uint256 tokens
    ) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint256 tokens);
    event Approval(
        address indexed tokenOwner,
        address indexed spender,
        uint256 tokens
    );
}

contract CCB {
    uint8 constant maxAdminFee = 100; /* set max admin fee to 1% */
    address private adminAddr;
    address private adminWallet;
    uint256 nextRequestId = 1;

    function CCB(address _adminWallet) public {
        adminAddr = msg.sender;
        adminWallet = _adminWallet;
    }

    struct Request {
        address requester;
        address asset;
        uint256 amount;
        uint256 gasCost;
        uint256 adminFee;
        bool pending;
        bool completed;
    }
    mapping(uint256 => Request) private requests;

    struct Asset {
        /* statistics */
        uint256 lockedAmount;
        uint256 pendingAmount;
        uint256 totalLocked;
        uint256 totalUnlocked;
    }
    mapping(address => Asset) private assets;

    struct Oracle {
        bool[] network; /* is authorized for a chain. Index is the chain id */
        uint256 availableAmount; /* accumulated gas costs, can be withdrawn */
        uint256 unsettledAmount; /* accumulated gas costs, must be settled first on target chain */
    }
    mapping(address => Oracle) private oracles;

    mapping(address => mapping(uint256 => uint8)) private adminFeeRates; /* token address and network id */
    mapping(address => uint256) private adminFees; /* token address */

    /* events*/
    event SetAdminFeeEvent(address tokenAddr, uint256 networkId, uint8 feeRate);
    event AddOracleEvent(address oracle, uint256 networkId);
    event RemoveOracleEvent(address oracle, uint256 networkId);
    event AddAssetEvent(address tokenAddr, uint256 networkId, uint8 feeRate);
    event RetrieveFeesEvent(address tokenAddr, uint256 amount);
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

    modifier adminOnly() {
        require(adminAddr == msg.sender);
        _;
    }

    modifier oracleOnly(uint256 networkId) {
        Oracle memory oracle = oracles[msg.sender];
        require(oracle.network == networkId);
        _;
    }

    /////////////// admin ///////////////////////
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

    ////////////////////////////////////////////////

    /////////////// oracles ///////////////////////
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

    ////////////////////////////////////////////////

    /////////////// users ///////////////////////
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
    ////////////////////////////////////////////////
}
