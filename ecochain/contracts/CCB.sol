/* License: GPL-3.0 https://www.gnu.org/licenses/gpl-3.0.en.html */

pragma solidity ^0.4.20;

import "./libs/SafeMath.sol";

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
    using SafeMath for uint256;

    address constant zeroAddr = address(0x0);
    uint8 constant maxAdminFee = 100; /* set max admin fee to 1% (4 digits) */
    address private adminAddr;
    address private adminWallet;
    uint256 nextRequestId = 1;
    uint256 nextReleaseId = 1;

    function CCB(address _adminWallet) public {
        adminAddr = msg.sender;
        adminWallet = _adminWallet;
    }

    struct Request {
        uint256 networkId;
        address requester;
        address beneficiar;
        address asset;
        uint256 amount;
        uint256 gasCost;
        uint256 adminFee;
        uint256 txid;
        bool pending;
        bool completed;
    }
    mapping(uint256 => Request) private requests;

    struct Release {
        uint256 networkId;
        uint256 txid;
        address oracle;
        address beneficiar;
        address asset;
        uint256 amount;
    }
    mapping(uint256 => Release) private releases;

    struct Asset {
        mapping(uint256 => bool) network;
        /* statistics */
        uint256 lockedAmount;
        uint256 pendingAmount;
        uint256 totalLocked;
        uint256 totalUnlocked;
        uint256 totalFees;
    }
    mapping(address => Asset) private assets;

    struct User {
        uint256[] requests;
        uint256[] releases;
    }
    mapping(address => User) private users;

    struct Oracle {
        mapping(uint256 => bool) network; /* network id to auth flag */
        uint256 availableAmount; /* accumulated gas costs, can be withdrawn */
    }
    mapping(address => Oracle) private oracles;

    mapping(address => mapping(uint256 => uint8)) private adminFeeRates; /* token address and network id */
    mapping(address => uint256) private adminFees; /* token address */
    mapping(uint256 => uint256) private gasCosts; /* network id */

    /* events*/
    event SetAdminFeeEvent(address tokenAddr, uint256 networkId, uint8 feeRate);
    event AddOracleEvent(address oracle, uint256 networkId);
    event RemoveOracleEvent(address oracle, uint256 networkId);
    event AddAssetEvent(address tokenAddr, uint256 networkId, uint8 feeRate);
    event RetrieveFeesEvent(address tokenAddr, uint256 amount);
    event UnlockECRC20Event(
        address oracle,
        address tokenAddr,
        address beneficiar,
        uint256 networkId,
        uint256 amount,
        uint256 releaseId
    );
    event UnlockECOCEvent(
        address oracle,
        address beneficiar,
        uint256 networkId,
        uint256 amount,
        uint256 txid,
        uint256 releaseId
    );
    event IssuedEvent(address oracle, uint256 requestId, uint256 txid);
    event SetGasCostEvent(address oracle, uint256 cost, uint256 networkId);
    event WithdrawGasCostsEvent(address oracle, uint256 amount);
    event LockECRC20Event(
        address tokenAddr,
        address beneficiarAddr,
        uint256 networkId,
        uint256 amount,
        uint256 requestId
    );
    event LockECOCEvent(
        address beneficiarAddr,
        uint256 networkId,
        uint256 amount,
        uint256 requestId
    );

    modifier adminOnly() {
        require(adminAddr == msg.sender);
        _;
    }

    modifier oracleOnly(uint256 _networkId) {
        Oracle storage oracle = oracles[msg.sender];
        require(oracle.network[_networkId]);
        _;
    }

    /**
     * @dev set admin fee for a token(can be zero)
     * It can't be higher than maxAdminFee (1%)
     * it can be edited at any time. The same restrictions apply (range 0-1%)
     * @param _tokenAddr - the token's ECRC20 smart contract address
     * @param _networkId - the network Id according to https://chainlist.org/
     * @param _feeRate - the fee rate has two decimals.
     */
    function setAdminFee(
        address _tokenAddr,
        uint256 _networkId,
        uint8 _feeRate
    ) external adminOnly {
        /* prevent admin setting a high fee */
        require(_feeRate <= maxAdminFee);
        /* disallloe admin to set any admin fees on ECOC */
        require(_tokenAddr != zeroAddr);

        adminFeeRates[_tokenAddr][_networkId] = _feeRate;
        emit SetAdminFeeEvent(_tokenAddr, _networkId, _feeRate);
    }

    /**
     * @dev authorizes an oracle for a specific chain
     * @param _oracle - oracle address for all assets of a chain
     * @param _networkId - the network Id according to https://chainlist.org/
     * Emits {AddOracleEvent}
     */
    function addOracle(address _oracle, uint256 _networkId) external adminOnly {
        Oracle storage oracle = oracles[_oracle];
        if (!oracle.network[_networkId]) {
            oracle.network[_networkId] = true;
            emit AddOracleEvent(_oracle, _networkId);
        }
    }

    /**
     * @dev revokes authorization of an oracle for a specific chain
     * @param _oracle - oracle address for all assets of a chain
     * @param _networkId - the network Id according to https://chainlist.org/
     * Emits {RemoveOracleEvent}
     */
    function removeOracle(address _oracle, uint256 _networkId)
        external
        adminOnly
    {
        Oracle storage oracle = oracles[_oracle];
        if (oracle.network[_networkId]) {
            oracle.network[_networkId] = false;
            emit RemoveOracleEvent(_oracle, _networkId);
        }
    }

    /**
     * @dev adds an ECRC20 token for a specific chain
     * fee rate can be set to zero
     * @param _tokenAddr - the token's ECRC20 smart contract address
     * @param _networkId - the network Id according to https://chainlist.org/
     * @param _feeRate - the fee rate has two decimals.
     */
    function addAsset(
        address _tokenAddr,
        uint256 _networkId,
        uint8 _feeRate
    ) external adminOnly {
        /* if admin fee is higher than maximum revert */
        require(_feeRate <= maxAdminFee);

        /* also forbid admin to set any fees for ECOC for any chain */
        require(!(_tokenAddr == zeroAddr && _feeRate != 0));

        Asset storage asset = assets[_tokenAddr];
        /* if asset already exists for the target chain revert */
        require(!asset.network[_networkId]);

        asset.network[_networkId] = true;
        adminFeeRates[_tokenAddr][_networkId] = _feeRate;

        emit AddAssetEvent(_tokenAddr, _networkId, _feeRate);
    }

    /**
     * @dev retrieves (withdraws) accumulated admin fees of a token
     * @param _tokenAddr - the token's ECRC20 smart contract address
     * @param _amount - If amount is set to zero then the whole balance of the token will be retrieved
     */
    function retrieveFees(address _tokenAddr, uint256 _amount)
        external
        adminOnly
    {
        /* if balance is zero revert*/
        require(adminFees[_tokenAddr] > 0);

        uint256 amount;
        if (_amount == 0 || _amount > adminFees[_tokenAddr]) {
            amount = adminFees[_tokenAddr];
            adminFees[_tokenAddr] = 0;
        } else {
            amount = _amount;
            adminFees[_tokenAddr] = adminFees[_tokenAddr].sub(_amount);
        }

        ECRC20 ecrcToken = ECRC20(_tokenAddr);
        require(ecrcToken.transfer(adminWallet, amount));

        emit RetrieveFeesEvent(_tokenAddr, amount);
    }

    /**
     * @dev unlocks ECRC20 tokens after detecting that tokens are burned on target chain
     * @notice gas is paid by oracle
     * @notice no admin fee for exiting
     * @param _tokenAddr - the token's ECRC20 smart contract address
     * @param _beneficiar - adress to where the tokens to be sent
     * @param _networkId - the network Id according to https://chainlist.org/
     * @param _txid - the transaction id of the burned tokens.
     * @param _amount - quantity of tokens
     */
    function unlockECRC20(
        address _tokenAddr,
        address _beneficiar,
        uint256 _networkId,
        uint256 _txid,
        uint256 _amount
    ) external oracleOnly(_networkId) {
        require(_amount != 0);
        require(_tokenAddr != zeroAddr); /* zero addres is reserved for ecoc*/

        Asset storage a = assets[_tokenAddr];
        /* check if asset is active on target chain */
        require(a.network[_networkId]);

        ECRC20 ecrcToken = ECRC20(_tokenAddr);
        /* Something is very wrong if oracle tries to unlock more than the total locked of the asset
         * punish the oracle
         */
        assert(a.totalLocked.sub(a.totalUnlocked) >= _amount);
        require(ecrcToken.transfer(_beneficiar, _amount));

        Release storage rel = releases[nextReleaseId];
        User storage u = users[_beneficiar];
        u.releases.push(nextReleaseId);
        nextReleaseId++;

        rel.networkId = _networkId;
        rel.txid = _txid;
        rel.oracle = msg.sender;
        rel.beneficiar = _beneficiar;
        rel.asset = _tokenAddr;
        rel.amount = _amount;

        /* update statistics for asset*/
        a.lockedAmount = a.lockedAmount.sub(_amount);
        a.totalUnlocked = a.totalUnlocked.add(_amount);

        emit UnlockECRC20Event(
            msg.sender,
            _tokenAddr,
            _beneficiar,
            _networkId,
            _amount,
            (nextReleaseId - 1)
        );
    }

    /**
     * @dev unlocks ECOC after detecting that WECOC is burned on target chain
     * @notice gas is paid by oracle
     * @notice There is no admin fee for ECOC for exiting
     * @param _beneficiar - adress to where the ECOC must be sent
     * @param _networkId - the network Id according to https://chainlist.org/
     * @param _txid - the transaction id of the burned tokens
     * @param _amount - amount of ECOC to be unlocked
     */
    function unlockECOC(
        address _beneficiar,
        uint256 _networkId,
        uint256 _txid,
        uint256 _amount
    ) external payable oracleOnly(_networkId) {
        require(_amount > 0);

        Asset storage a = assets[zeroAddr];
        /* check if asset is active on target chain */
        require(a.network[_networkId]);

        /* Something is very wrong if oracle tries to unlock more than the total locked of ECOC
         * punish the oracle
         */
        assert(a.totalLocked.sub(a.totalUnlocked) >= _amount);
        _beneficiar.transfer(_amount);

        Release storage rel = releases[nextReleaseId];
        User storage u = users[_beneficiar];
        u.releases.push(nextReleaseId);
        nextReleaseId++;

        rel.networkId = _networkId;
        rel.txid = _txid;
        rel.oracle = msg.sender;
        rel.beneficiar = _beneficiar;
        rel.asset = zeroAddr;
        rel.amount = _amount;

        /* update statistics for asset*/
        a.lockedAmount = a.lockedAmount.sub(_amount);
        a.totalUnlocked = a.totalUnlocked.add(_amount);

        emit UnlockECOCEvent(
            msg.sender,
            _beneficiar,
            _networkId,
            _amount,
            _txid,
            (nextReleaseId - 1)
        );
    }

    /**
     * @dev informs the smart contract that the wrapped token has been issued on target chain
     * @notice must be triggered by the oracle after the issue() on target chain is confirmed
     * @param _requestId - the request id of locking
     * @param _txid - the transaction id of the issued tokens on target chain
     */
    function issued(uint256 _requestId, uint256 _txid) external {
        /* request must exist */
        require(_requestId < nextRequestId);
        Oracle storage oracle = oracles[msg.sender];
        /* oracle must be authorized */
        Request storage r = requests[_requestId];
        require(oracle.network[r.networkId]);

        Asset storage a = assets[r.asset];
        /* check if asset exists */
        require(a.network[r.networkId]);

        require(r.pending);
        r.pending = false;
        r.completed = true;
        r.txid = _txid;

        oracle.availableAmount = oracle.availableAmount.add(r.gasCost);

        /* update statistics for the asset */
        a.pendingAmount = a.pendingAmount.sub(r.amount);

        emit IssuedEvent(msg.sender, _requestId, _txid);
    }

    /**
     * @dev This function should be called often; It sets the gas cost of the target chain
     * @notice This cost is the same for any asset(including ECOC) for a specific chain. ECOC is
     * a wrapped token on other chains (*RC20) so the transfer cost is the same
     * @param _cost - cost in ECOC of the issue() of wrapped tokens. It can't be zero
     * @param _networkId - the network Id according to https://chainlist.org/
     */
    function setGasCost(uint256 _cost, uint256 _networkId)
        external
        oracleOnly(_networkId)
    {
        require(_cost != 0);
        gasCosts[_networkId] = _cost;
        emit SetGasCostEvent(msg.sender, _cost, _networkId);
    }

    /**
     * @dev withdraws accumulated gasCosts (the whole balance of an oracle)
     * @dev it fails on zero balance
     */
    function withdrawGasCosts() external payable {
        Oracle storage oracle = oracles[msg.sender];
        require(oracle.availableAmount > 0);

        uint256 amount = oracle.availableAmount;
        oracle.availableAmount = 0;
        msg.sender.transfer(amount);
    }

    /**
     * @dev locks ECRC20
     * @notice token holder must approve() first to this smart contract the amount of token
     * @notice the user must also send to contract an equal amount (or more) of ECOC thet gets by calling getGasCost()
     * @param _tokenAddr - the token's ECRC20 smart contract address
     * @param _beneficiarAddr is the public address on the target chain
     * @param _networkId - the network Id according to https://chainlist.org/
     * @param _amount - quantity of tokens
     */
    function lockECRC20(
        address _tokenAddr,
        address _beneficiarAddr,
        uint256 _networkId,
        uint256 _amount
    ) external payable {
        uint256 cost = _getGasCost(_networkId);
        require(msg.value >= cost);

        Asset storage a = assets[_tokenAddr];
        /* check if asset is active on target chain */
        require(a.network[_networkId]);

        require(_amount != 0);

        ECRC20 ecrcToken = ECRC20(_tokenAddr);
        /* user must approve() the smart contract first */
        require(ecrcToken.transferFrom(msg.sender, address(this), _amount));

        uint256 amount = _amount;
        uint256 adminFee = computeFee(
            adminFeeRates[_tokenAddr][_networkId],
            _amount
        );
        amount = _amount.sub(adminFee);
        adminFees[_tokenAddr] += adminFee;

        Request storage r = requests[nextRequestId];
        User storage u = users[msg.sender];
        u.requests.push(nextRequestId);
        nextRequestId++;

        r.networkId = _networkId;
        r.requester = msg.sender;
        r.beneficiar = _beneficiarAddr; /* public address in hex for target chain */
        r.asset = _tokenAddr;
        r.amount = amount;
        r.gasCost = msg.value;
        r.adminFee = adminFee;
        r.pending = true;

        /* update statistics for asset*/
        a.lockedAmount = a.lockedAmount.add(amount);
        a.pendingAmount = a.pendingAmount.add(amount);
        a.totalLocked = a.totalLocked.add(amount);
        a.totalFees = a.totalFees.add(adminFee);

        emit LockECRC20Event(_tokenAddr, _beneficiarAddr, _networkId, amount, (nextRequestId - 1));
    }

    /**
     * @dev locks ECOC
     * @notice an equal amount of ECOC of the value getGasCost() will be automatically kept to pay gas costs on the target chain
     * @notice if ECOC sent are less than or equal of getGasCost() the transaction will revert
     * @param _beneficiarAddr is the public address on the target chain
     * @param _networkId - the network Id according to https://chainlist.org/
     */
    function lockECOC(address _beneficiarAddr, uint256 _networkId)
        external
        payable
    {
        uint256 cost = _getGasCost(_networkId);
        require(msg.value > cost);

        /* use zero address for ECOC for mapping */
        Asset storage a = assets[zeroAddr];
        /* check if asset is active on target chain */
        require(a.network[_networkId]);

        uint256 lockedAmount = msg.value.sub(cost);
        User storage u = users[msg.sender];
        u.requests.push(nextRequestId);

        Request storage r = requests[nextRequestId];
        nextRequestId++;

        r.networkId = _networkId;
        r.requester = msg.sender;
        r.beneficiar = _beneficiarAddr; /* public address in hex for target chain */
        r.asset = zeroAddr; /* zero address for ecoc*/
        r.amount = lockedAmount;
        r.gasCost = cost;
        r.pending = true;

        /* update statistics for asset*/
        a.lockedAmount = a.lockedAmount.add(lockedAmount);
        a.pendingAmount = a.pendingAmount.add(lockedAmount);
        a.totalLocked = a.totalLocked.add(lockedAmount);

        emit LockECOCEvent(_beneficiarAddr, _networkId, lockedAmount, (nextRequestId - 1));
    }

    /**
     * @dev returns the admin fee rate
     * @param _tokenAddr - the token's ECRC20 smart contract address
     * @param _networkId - the network Id according to https://chainlist.org/
     * @return uint8 - 2 decimal places. It can be zero
     */
    function getFeeRate(address _tokenAddr, uint256 _networkId)
        external
        view
        returns (uint8 adminFee)
    {
        return adminFeeRates[_tokenAddr][_networkId];
    }

    /**
     * @dev returns the gas cost. It is the same for all assets at a specific time and different for each chain
     * @notice Use this return value to send ECOC when locking assets on ecochain
     * @param _networkId - the network Id according to https://chainlist.org/
     * @return uint256 - The gas cost in ECOC. It is used to pay to oracle the expenses (tx cost) when locking
     */
    function getGasCost(uint256 _networkId)
        external
        view
        returns (uint256 gasCost)
    {
        return _getGasCost(_networkId);
    }

    function _getGasCost(uint256 _networkId)
        internal
        view
        returns (uint256 gasCost)
    {
        return gasCosts[_networkId];
    }

    /**
     * @dev gets all requests for a specific public address of a chain (all assets)
     * @dev if _networkId is zero then it returns all requests  of all chains
     * @param _userAddr is the ecoc public address of the user
     * @param _networkId - the network Id according to https://chainlist.org/
     * @return uint256[] - Returns an array of locked ids for all locked assets of a user
     */
    function getAllRequests(address _userAddr, uint256 _networkId)
        external
        view
        returns (uint256[] requestIds)
    {
        User memory u = users[_userAddr];
        uint256 l = u.requests.length;
        uint256 size = 0;
        Request memory r;

        /* compute length first*/
        for (uint256 i = 0; i < l; i++) {
            r = requests[u.requests[i]];
            if (r.networkId == _networkId || _networkId == 0) {
                size++;
            }
        }

        uint256[] memory userRequests = new uint256[](size);
        uint256 next = 0;
        for (i = 0; i < l; i++) {
            r = requests[u.requests[i]];
            if (r.networkId == _networkId || _networkId == 0) {
                userRequests[next] = u.requests[i];
                next++;
            }
        }

        return userRequests;
    }

    /**
     * @dev returns  only the pending requsts for a specific public address of a chain (all assets)
     * @dev if _networkId is zero then it returns all pending requests of all chains
     * @param _userAddr is the ecoc public address of the user
     * @param _networkId - the network Id according to https://chainlist.org/
     * @return uint256[] - Returns an array of of locked ids of pending only locks for all assets of an owner
     */
    function getPendingRequests(address _userAddr, uint256 _networkId)
        external
        view
        returns (uint256[] requestIds)
    {
        User memory u = users[_userAddr];
        uint256 l = u.requests.length;
        uint256 size = 0;
        Request memory r;

        /* compute length first*/
        for (uint256 i = 0; i < l; i++) {
            r = requests[u.requests[i]];
            if (r.networkId == _networkId || _networkId == 0) {
                if (!r.completed) {
                    size++;
                }
            }
        }

        uint256[] memory pendingRequests = new uint256[](size);
        uint256 next = 0;
        for (i = 0; i < l; i++) {
            r = requests[u.requests[i]];
            if (r.networkId == _networkId || _networkId == 0) {
                if (!r.completed) {
                    pendingRequests[next] = u.requests[i];
                    next++;
                }
            }
        }

        return pendingRequests;
    }

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
        )
    {
        Asset memory a = assets[_assetAddr];

        return (
            a.lockedAmount,
            a.pendingAmount,
            a.totalLocked,
            a.totalUnlocked,
            a.totalFees
        );
    }

    /**
     * @dev checks if the txid of burned assets has been comleted (assets unlocked)
     * @param _requestId - the id of the locked request
     * @return bool - Return a boolean(true if the wrapped asset is issued on the target chain)
     */
    function getTransferStatus(uint256 _requestId)
        external
        view
        returns (bool completed)
    {
        Request memory r = requests[_requestId];
        return r.completed;
    }

    /**
     * @notice returns the total locked amount of an asset (token or ECOC).
     * @notice Oracle fees and admin fees are excluded
     * @dev pass the zero address if the asset is the ECOC
     * @param _tokenAddr - ECRC20 smart contract address or the zero address for ECOC
     * @return uint256 - total locked amount of the asset
     */
    function getLockedAssets(address _tokenAddr)
        external
        view
        returns (uint256 amount)
    {
        Asset memory a = assets[_tokenAddr];
        uint256 locked = a.totalLocked.sub(a.totalUnlocked);
        return locked;
    }

    /**
     * @notice Gas costs in ECOC for the oracle which haven't already retrieved
     * @dev balance is topped up after an oracle triggers issued()
     * @param _oracle - the oracle's address
     * @return uint256 - total ECOC as gas cost that hasn't been retrieved yet by oracle
     */
    function getOracleBalace(address _oracle)
        external
        view
        returns (uint256 amount)
    {
        Oracle memory oracle = oracles[_oracle];
        return oracle.availableAmount;
    }

    /**
     * @dev balance of a token accumulated by admin fees and reduced with retrieveFees()
     * @param _tokenAddr - ECRC20 smart contract address
     * @return uint256 - total balance of the token
     */
    function getAdminBalace(address _tokenAddr)
        external
        view
        returns (uint256 amount)
    {
        return adminFees[_tokenAddr];
    }

    /**
     * @dev total token accumulated by admin fees (includes allready withdrawn)
     * @param _tokenAddr - ECRC20 smart contract address
     * @return uint256 - total fees of the token
     */
    function getTotalAdminFee(address _tokenAddr)
        external
        view
        returns (uint256 amount)
    {
        Asset memory a = assets[_tokenAddr];
        return a.totalFees;
    }

    /**
     * @notice checks if the specific address belongs to an oracle
     * @param _oracle - address in question
     * @param _networkId - the network Id according to https://chainlist.org/
     * @return bool - true if it is an oracle for the target chain
     */
    function isOracle(address _oracle, uint256 _networkId)
        external
        view
        returns (bool auth)
    {
        Oracle storage oracle = oracles[_oracle];
        return oracle.network[_networkId];
    }

    /**
     * @notice returns information about a request
     * @param _requestId - the request id
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
    function getRequestInfo(uint256 _requestId)
        external
        view
        returns (
            uint256 networkId,
            address requester,
            address beneficiar,
            address asset,
            uint256 amount,
            uint256 gasCost,
            uint256 adminFee,
            uint256 txid,
            bool pending,
            bool completed
        )
    {
        Request memory r = requests[_requestId];

        return (
            r.networkId,
            r.requester,
            r.beneficiar,
            r.asset,
            r.amount,
            r.gasCost,
            r.adminFee,
            r.txid,
            r.pending,
            r.completed
        );
    }

    /**
     * @notice returns information about a request
     * @param _releaseId - the release id
     * @return uint256 - txid on target chain. Zero is returns if pending
     * @return uint256 - the network id
     * @return address - oracle address that carried out the unlocking
     * @return address - beneficiar public address
     * @return address - the ECRC20 asset
     * @return uint256 - amount
     */
    function getReleaseInfo(uint256 _releaseId)
        external
        view
        returns (
            uint256 networkId,
            uint256 txid,
            address oracle,
            address beneficiar,
            address asset,
            uint256 amount
        )
    {
        Release memory r = releases[_releaseId];

        return (r.networkId, r.txid, r.oracle, r.beneficiar, r.asset, r.amount);
    }

    /**
     * @notice returns the fee
     * @param _feeRate - fee rate (uint8)
     * @param _amount - amount
     * @return uint256 - fee
     */
    function computeFee(uint8 _feeRate, uint256 _amount)
        internal
        pure
        returns (uint256 fee)
    {
        /* save some gas */
        if (_feeRate == 0 || _amount == 0) {
            return 0;
        }

        fee = (uint256(_feeRate)).mul(_amount);
        fee = fee.div(1e4);
        return fee;
    }
}
