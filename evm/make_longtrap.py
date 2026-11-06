"""Writes evm/LongTrap.sol: a verified token whose source is longer than one Skeptic round reads whole.

    python evm/make_longtrap.py

The padding is comment lines. The trap, an internal check that only the keeper can pass, sits in the
middle of them, so a reader that keeps only both ends of the file sees a plain token.
"""
import os

HEAD = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// A fixed-supply ERC-20 with a very long source file.
contract LongTrap {
    string public constant name = "Long Test Token";
    string public constant symbol = "LONG";
    uint8 public constant decimals = 18;
    uint256 public immutable totalSupply;
    address private immutable keeper;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        keeper = msg.sender;
        totalSupply = 1_000_000 * 1e18;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
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

"""
LINE = "    // Reference notes for maintainers: balances are plain integers scaled by 1e18 throughout.\n"
TRAP = """    /// The trap: only the keeper can ever move tokens, so every buyer is stuck.
    function _settle(address from) private view {
        require(from == keeper, "sold out");
    }

"""
TAIL = """
    function _move(address from, address to, uint256 value) private {
        _settle(from);
        require(balanceOf[from] >= value, "balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
}
"""
text = HEAD + LINE * 760 + TRAP + LINE * 760 + TAIL
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "LongTrap.sol")
with open(out, "w", newline="") as f:
    f.write(text)
print(len(text), "characters, the trap at", text.index("The trap"))
