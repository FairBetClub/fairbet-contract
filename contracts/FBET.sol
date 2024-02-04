// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FBET is ERC20, Ownable {
    mapping(address whitelistAddress => bool isWhitelisted)
        public isWhitelisted;
    error AddressIsNotWhitelisted(address);

    error InvalidWhitelistAddress();
    event AddressWhitelisted(
        address indexed addressForWhitelist,
        bool whitelisted
    );

    constructor(
        string memory name_,
        string memory symbol_,
        address _owner
    ) ERC20(name_, symbol_) {
        _transferOwnership(_owner);
    }

    modifier checkWhitelist() {
        if (!isWhitelisted[msg.sender]) {
            revert AddressIsNotWhitelisted(msg.sender);
        }
        _;
    }

    function whitelistAddress(
        address addressForWhitelist,
        bool whitelisted
    ) external onlyOwner {
        if (addressForWhitelist == address(0)) {
            revert InvalidWhitelistAddress();
        }
        isWhitelisted[addressForWhitelist] = whitelisted;

        emit AddressWhitelisted(addressForWhitelist, whitelisted);
    }

    function mint(address account, uint256 amount) external checkWhitelist {
        _mint(account, amount);
    }

    function burn(uint256 _amount) external checkWhitelist {
        _burn(msg.sender, _amount);
    }
}
