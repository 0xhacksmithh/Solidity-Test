pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
    using SafeMath for uint256;

    // ------------------------------------------ //
    // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
    // ------------------------------------------ //
    uint256 public totalSupply;
    uint256 public decimals = 18;
    string public name = "Test token";
    string public symbol = "TEST";
    mapping(address => uint256) public balanceOf;
    // ------------------------------------------ //
    // ----- END: DO NOT EDIT THIS SECTION ------ //
    // ------------------------------------------ //

    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => uint256) private _withdrawableDividends;

    address[] private holders;

    mapping(address => bool) private isHolder;

    mapping(address => uint256) private holderIndex;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    // ============================================================
    // Internal holder management
    // ============================================================

    function _addHolder(address account) internal {
        if (!isHolder[account] && balanceOf[account] > 0) {
            holders.push(account);

            isHolder[account] = true;

            // store index + 1
            holderIndex[account] = holders.length;
        }
    }

    function _removeHolder(address account) internal {
        if (!isHolder[account]) {
            return;
        }

        uint256 index = holderIndex[account] - 1;
        uint256 lastIndex = holders.length - 1;

        if (index != lastIndex) {
            address lastHolder = holders[lastIndex];

            holders[index] = lastHolder;
            holderIndex[lastHolder] = index + 1;
        }

        holders.pop();

        delete holderIndex[account];
        isHolder[account] = false;
    }

    function _updateHolder(address account) internal {
        if (balanceOf[account] > 0) {
            _addHolder(account);
        } else {
            _removeHolder(account);
        }
    }

    // ============================================================
    // ERC20
    // ============================================================

    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function transfer(address to, uint256 value)
        external
        override
        returns (bool)
    {
        require(balanceOf[msg.sender] >= value, "insufficient balance");

        balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
        balanceOf[to] = balanceOf[to].add(value);

        _updateHolder(msg.sender);
        _updateHolder(to);

        emit Transfer(msg.sender, to, value);

        return true;
    }

    function approve(address spender, uint256 value)
        external
        override
        returns (bool)
    {
        _allowances[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    )
        external
        override
        returns (bool)
    {
        require(balanceOf[from] >= value, "insufficient balance");
        require(
            _allowances[from][msg.sender] >= value,
            "insufficient allowance"
        );

        _allowances[from][msg.sender] =
            _allowances[from][msg.sender].sub(value);

        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);

        _updateHolder(from);
        _updateHolder(to);

        emit Transfer(from, to, value);

        return true;
    }

    // ============================================================
    // Mintable Token
    // ============================================================

    function mint() external payable override {
        require(msg.value > 0, "zero mint");

        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
        totalSupply = totalSupply.add(msg.value);

        _updateHolder(msg.sender);

        emit Transfer(address(0), msg.sender, msg.value);
    }

    function burn(address payable dest) external override {
        uint256 amount = balanceOf[msg.sender];

        require(amount > 0, "nothing to burn");

        balanceOf[msg.sender] = 0;
        totalSupply = totalSupply.sub(amount);

        _updateHolder(msg.sender);

        emit Transfer(msg.sender, address(0), amount);

        (bool success, ) = dest.call{value: amount}("");
        require(success, "eth transfer failed");
    }

    // ============================================================
    // Dividends
    // ============================================================

    function getNumTokenHolders()
        external
        view
        override
        returns (uint256)
    {
        return holders.length;
    }

    function getTokenHolder(uint256 index)
        external
        view
        override
        returns (address)
    {
        require(index > 0, "1-based index");
        require(index <= holders.length, "out of bounds");

        return holders[index - 1];
    }

    function recordDividend() external payable override {
        require(msg.value > 0, "empty dividend");
        require(totalSupply > 0, "no supply");

        uint256 holderCount = holders.length;

        for (uint256 i = 0; i < holderCount; i++) {
            address holder = holders[i];

            uint256 payout =
                msg.value.mul(balanceOf[holder]).div(totalSupply);

            _withdrawableDividends[holder] =
                _withdrawableDividends[holder].add(payout);
        }
    }

    function getWithdrawableDividend(address payee)
        external
        view
        override
        returns (uint256)
    {
        return _withdrawableDividends[payee];
    }

    function withdrawDividend(address payable dest)
        external
        override
    {
        uint256 amount = _withdrawableDividends[msg.sender];

        require(amount > 0, "nothing to withdraw");

        _withdrawableDividends[msg.sender] = 0;

        (bool success, ) = dest.call{value: amount}("");
        require(success, "withdraw failed");
    }

    receive() external payable {}
}