// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// An EIP-1967 proxy, verified on purpose. Everything a holder depends on lives behind it, in an
/// implementation whose source was never published, so this file alone cannot clear the token.
contract OpenProxy {
    bytes32 private constant SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    event Upgraded(address indexed implementation);

    constructor(address implementation, bytes memory init) {
        assembly { sstore(SLOT, implementation) }
        emit Upgraded(implementation);
        (bool ok, ) = implementation.delegatecall(init);
        require(ok, "init");
    }

    fallback() external payable {
        assembly {
            let target := sload(SLOT)
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), target, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}
