// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ERC20Token is ERC20Upgradeable, OwnableUpgradeable {
    uint256 public maxTotalSupply;

    function initialize(
        string memory name_,
        string memory symbol_,
        address _owner,
        uint256 _maxTotalSupply
    ) external initializer {
        __ERC20_init(name_, symbol_);
        _transferOwnership(_owner);
        maxTotalSupply = _maxTotalSupply;
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
        require(totalSupply() <= maxTotalSupply, "exceed maxTotalSupply");
    }

    function burn(uint256 _amount) external onlyOwner {
        _burn(msg.sender, _amount);
    }
}
