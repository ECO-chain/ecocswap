/* SPDX-License-Identifier: GPL-3.0 https://www.gnu.org/licenses/gpl-3.0.en.html */

pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./interfaces/ICC20.sol";

contract CCExampleToken is IERC20, ICC20 {
    address private admin;
    mapping(address => bool) private oracles;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    uint256 private totalSupply_;
    string private name_;
    string private symbol_;
    string private originalSymbol_; /* symbol of token on ECOCHAIN*/
    uint8 private decimals_; /* should be equal to the decimal places of the original token */
    address private originalAddress_; /* smart contract token address on ECOCHAIN */

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _originalSymbol,
        address _originalAddress,
        uint8 _decimals
    ) {
        admin = msg.sender;
        name_ = _name;
        symbol_ = _symbol;
        originalSymbol_ = _originalSymbol;
        originalAddress_ = _originalAddress;
        decimals_ = _decimals;
        /* Initial total supply is zero */
    }

    modifier adminOnly() {
        require(admin == msg.sender);
        _;
    }

    modifier oracleOnly() {
        require(oracles[msg.sender]);
        _;
    }

    /**
     * @dev Returns the name of the token.
     * @return string - name of token
     */

    function name() external view override returns (string memory) {
        return name_;
    }

    /**
     * @dev Returns the symbol of the token.
     * @return string - symbol of token
     */

    function symbol() external view override returns (string memory) {
        return symbol_;
    }

    /**
     * @dev Returns the decimals places of the token.
     * @return uint8 - decimals
     */

    function decimals() external view override returns (uint8) {
        return decimals_;
    }

    /**
     * @dev Returns the original symbol of the token on ECOCHAIN
     * @return string - original symbol of the token on ecochain
     */

    function originalSymbol() external view override returns (string memory) {
        return originalSymbol_;
    }

    /**
     * @dev Returns the smart contract address of the token on ECOCHAIN
     * @dev Returns the zero address for WECOC token
     * @return string - smart contract ECRC20 address
     */

    function originalAddress() external view override returns (address) {
        return originalAddress_;
    }

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view override returns (uint256) {
        return totalSupply_;
    }

    ////////////////////////////// IERC20 ////////////////////////////////
    /**
     * @dev Returns the amount of tokens owned by address
     * @param _account - address of owner
     * @return uint256 - current balance of the owner
     */
    function balanceOf(address _account)
        external
        view
        override
        returns (uint256)
    {
        return balances[_account];
    }

    /**
     * @dev Moves tokens from the caller's account to beneficiar
     * @notice Returns a boolean value indicating whether the operation succeeded (ERC20 standard demands this)
     * @param _beneficiar - target public address
     * @param _amount - amount to be transfered
     * @return bool - on successful transfer returns true
     * Emits a {Transfer} event
     */
    function transfer(address _beneficiar, uint256 _amount)
        external
        override
        returns (bool)
    {
        _transfer(msg.sender, _beneficiar, _amount);
        return true;
    }

    /**
     * @dev Moves amount tokens from _sender to _benefeciar using the
     * allowance mechanism. _amount is then deducted from sender's
     * allowance.
     * @param _sender - sender's public address
     * @param _beneficiar - beneficiar's public address
     * @param _amount - amount to be transferred
     * @return bool - true on success
     * Emits a {Transfer} event
     */

    function transferFrom(
        address _sender,
        address _beneficiar,
        uint256 _amount
    ) public override returns (bool) {
        _transfer(_sender, _beneficiar, _amount);

        uint256 currentAllowance = allowances[_sender][msg.sender];
        require(
            currentAllowance >= _amount,
            "ERC20: transfer amount exceeds allowance"
        );
        unchecked {
            _approve(_sender, msg.sender, currentAllowance - _amount);
        }

        return true;
    }

    /**
     * @notice Internal function, to be called by transfer() and transferFrom()
     * @param _sender - the sender's public address
     * @param _beneficiar - target public address
     * @param _amount - amount to be transfered
     * Emits a {Transfer} event
     */
    function _transfer(
        address _sender,
        address _beneficiar,
        uint256 _amount
    ) internal {
        require(_sender != address(0), "ERC20: transfer from the zero address");
        require(
            _beneficiar != address(0),
            "ERC20: transfer to the zero address"
        );

        uint256 senderBalance = balances[_sender];
        require(
            senderBalance >= _amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            balances[_sender] = senderBalance - _amount;
        }
        balances[_beneficiar] += _amount;

        emit Transfer(_sender, _beneficiar, _amount);
    }

    /**
     * @dev Returns the remaining number of tokens that spender will be
     * allowed to spend on behalf of the real owner through {transferFrom}
     * @dev This is zero by default.
     * @dev It is decreased when transferFrom() is triggered succesfully
     * @dev It can be set by approve(). ALso can be increased or decreased by
     * @dev increaseAllowance() or decreaseAllowance()
     * @param _owner -owner's public address
     * @param _spender - spender's public address
     * @return uint256 - maximum allowed amount to be transfered
     */
    function allowance(address _owner, address _spender)
        external
        view
        override
        returns (uint256)
    {
        return allowances[_owner][_spender];
    }

    /**
     * @dev Sets amount as the allowance of spender over the caller's tokens.
     * @dev Returns a boolean value indicating whether the operation succeeded.
     * @dev IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * @param _spender - spender's public address
     * @param _amount - maximum amount of allowed tokens
     * @return bool - true on success (it fails on zero address)
     * Emits an {Approval} event
     */
    function approve(address _spender, uint256 _amount)
        external
        override
        returns (bool)
    {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @dev Internal function. Used by approve(), transferFrom(), increaseAllowance() and decreaseAllowance()
     * @dev It reverts on zero addreses (owner or spender)
     * @param _owner - owner's public address
     * @param _spender - spender's public address
     * @param _amount - maximum amount of allowed tokens
     * Emits an {Approval} event
     */

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    //////////////////////////// ICC20 ////////////////////////////////////

    /**
     * @dev Authorize an oracle,which has the privelege to issue tokens
     * @dev triggered only by admin
     * @param _oracle - address of oracle
     * Emits an {AuthOracleEvent} event
     */
    function authOracle(address _oracle) external override adminOnly {
        /* emit the event only if _orcle isn't already authorized */
        if (!oracles[_oracle]) {
            oracles[_oracle] = true;
            emit AuthOracleEvent(_oracle, true);
        }
    }

    /**
     * @dev Revoke the authority of an oracle
     * @dev triggered only by admin
     * @param _oracle - address of oracle
     * Emits an {AuthOracleEvent} event
     */
    function unauthOracle(address _oracle) external override adminOnly {
        /* emit the event only if _orcle is already authorized */
        if (oracles[_oracle]) {
            oracles[_oracle] = false;
            emit AuthOracleEvent(_oracle, false);
        }
    }

    /**
     * @dev Creates tokens for a user. Should be triggered after the original tokens are locked
     * @dev triggered only by an oracle
     * @param _requestId - the request id of locked tokens on ECOCHAIN
     * @param _beneficiar - ethereum public address to which the new tokens will be issued
     * @param _amount - amount of tokens
     * @return bool - true on success
     */
    function issue(
        uint256 _requestId,
        address _beneficiar,
        uint256 _amount
    ) external override oracleOnly returns (bool) {
        require(
            _beneficiar != address(0),
            "ERC20: Issuing to zero address is forbidden"
        );

        totalSupply_ += _amount;
        balances[_beneficiar] += _amount;

        emit IssueEvent(msg.sender, _beneficiar, _amount, _requestId);
        return true;
    }

    /**
     * @notice Can be triggered by owners of the token
     * @dev Burns tokens of a user. It is a prerequest to unlock an equal amount of tokens (or ECOC) on ECOCHAIN
     * @dev triggered only by the owner of the tokens
     * @param _ecocAddr - hex of the ecochain's (not ethereum) beneficiar's public address
     * to which the original tokens will be unlocked
     * @param _amount - amount of tokens. Should be equal or less of owner's balance
     * @return bool - true on success
     * Emits an {BurnEvent} event
     */
    function burn(address _ecocAddr, uint256 _amount)
        external
        override
        returns (bool)
    {
        require(
            _ecocAddr != address(0),
            "ECRC20: cross chain transfering to the zero address is forbidden"
        );

        uint256 ownerBalance = balances[msg.sender];
        require(
            ownerBalance >= _amount,
            "ERC20: requsted for burning amount exceeds balance"
        );
        unchecked {
            balances[msg.sender] = ownerBalance - _amount;
        }

        totalSupply_ -= _amount;

        emit BurnEvent(msg.sender, _ecocAddr, _amount);
        return true;
    }

    ////////////////////////// non-interface functions ///////////////////////////

    /**
     * @dev checks if an address belongs to an oracle
     * @param _oracle - address to be checked
     * @return bool - true if it is an oracle, else false
     */
    function isOracle(address _oracle) external view returns (bool) {
        return oracles[_oracle];
    }

    /**
     * @dev Atomically increases the allowance granted to spender by the caller
     * @dev _aprove() restrictions apply
     * @param _spender - spender's public address
     * @param _addedValue - amount of increasing allowance
     * @return bool - true if increase is succesful
     * Emits an {Approval} event indicating the updated allowance
     */
    function increaseAllowance(address _spender, uint256 _addedValue)
        public
        returns (bool)
    {
        _approve(
            msg.sender,
            _spender,
            allowances[msg.sender][_spender] + _addedValue
        );
        return true;
    }

    /**
     * @dev Atomically decrease the allowance granted to spender by the caller
     * @dev _aprove() restrictions apply
     * @param _spender - spender's public address
     * @param _subtractedValue - amount of decreasing allowance
     * @return bool - true if decrease is succesful
     * Emits an {Approval} event indicating the updated allowance
     */
    function decreaseAllowance(address _spender, uint256 _subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = allowances[msg.sender][_spender];
        require(
            currentAllowance >= _subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(msg.sender, _spender, currentAllowance - _subtractedValue);
        }

        return true;
    }
}
