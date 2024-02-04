// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Initializable {
    bool private _initialized;
    modifier initializer() {
        require(!_initialized);
        _initialized = true;
        _;
    }
}
