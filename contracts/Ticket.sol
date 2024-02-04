// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IRental.sol";
import "./PausableV2.sol";

contract Ticket is ERC1155(""), IRental, IERC1155Receiver, PausableV2 {
    using Strings for uint256;
    struct TokenInfo {
        address owner;
        uint256 totalSupply;
        bool froze;
    }
    uint256 private _totalSupply;
    mapping(address => uint256) public ticketCount;
    mapping(uint256 => TokenInfo) private _tokensInfo;
    mapping(uint256 => bool) public greyList;
    /**
    tokenId => address => expires
    * */
    mapping(uint256 => mapping(address => uint256)) public rentExpires;
    bool private _noCheck;
    address public miner;
    address public vault;
    event Mint(address _user, uint256 _tokenId);
    event Burn(uint256 _tokenId);
    event SetMiner(address _miner);
    event SetGreyTokenId(uint256 _tokenId, bool _allow);
    event Used(address _user, uint256 _tokenId);
    event Recovered(address _user, uint256 _tokenId);
    event Froze(uint256 _tokenId);
    event Unfroze(uint256 _tokenId);
    event SetURI(string _newuri);
    event TransferOwner(
        address from,
        address to,
        uint256[] ids,
        uint256[] amounts
    );

    /**
        _address[0] vault
        _address[1] miner
        _address[2] owner
     */
    function initialize(
        string memory newuri,
        address _owner
    ) external initializer {
        _transferOwnership(_owner);
        _setURI(newuri);
    }

    function name() external pure returns (string memory) {
        return "Smooth Fox";
    }

    function symbol() external pure returns (string memory) {
        return "FAIRBET";
    }

    function uri(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(id), id.toString()));
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    modifier onlyVault() {
        require(msg.sender == vault);
        _noCheck = true;
        _;
        _noCheck = false;
    }

    modifier unCheck() {
        _noCheck = true;
        _;
        _noCheck = false;
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
        emit SetURI(newuri);
    }

    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "valult error");
        vault = _vault;
    }

    function setMiner(address _miner) external onlyOwner {
        require(_miner != miner, "repeat operation");
        miner = _miner;
        emit SetMiner(_miner);
    }

    function safeRent(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        uint256 expires
    ) external unCheck {
        require(expires > 0, "expires is zero");
        require(!greyList[tokenId], "in greyList");
        require(rentExpires[tokenId][to] == 0, "rent exists");
        require(
            _tokensInfo[tokenId].owner == from && from != to,
            "token owner error"
        );
        safeTransferFrom(from, to, tokenId, amount, "");
        rentExpires[tokenId][to] = expires;
        emit Rented(tokenId, to, amount, expires);
    }

    function takeBack(address user, uint256 tokenId) external unCheck {
        TokenInfo memory _tokenInfo = _tokensInfo[tokenId];
        uint256 _expires = rentExpires[tokenId][user];
        require(_expires > 0 && block.timestamp >= _expires, "_expires error");
        uint256 _amount = balanceOf(user, tokenId);
        _safeTransferFrom(user, _tokenInfo.owner, tokenId, _amount, "");
        delete rentExpires[tokenId][user];
        emit TakeBack(tokenId, user, _amount);
    }

    function use(
        address user,
        uint256 tokenId,
        uint256 expires
    ) external onlyVault {
        require(
            _tokensInfo[tokenId].owner == user ||
                rentExpires[tokenId][user] >= expires,
            "expired"
        );
        _safeTransferFrom(user, address(this), tokenId, 1, "");
        emit Used(user, tokenId);
    }

    function recover(address user, uint256 tokenId) external onlyVault {
        emit Recovered(user, tokenId);
        if (rentExpires[tokenId][user] == 0) {
            user = _tokensInfo[tokenId].owner;
        }
        _safeTransferFrom(address(this), user, tokenId, 1, "");
    }

    function freeze(uint256 tokenId, address from) external onlyVault {
        TokenInfo storage _tokenInfo = _tokensInfo[tokenId];
        require(!_tokenInfo.froze, "in freezing");
        require(from == _tokenInfo.owner, "token owner error");
        _tokenInfo.froze = true;
        _safeTransferFrom(_tokenInfo.owner, address(this), tokenId, 1, "");
        emit Froze(tokenId);
    }

    function unfreeze(uint256 tokenId) external onlyVault {
        TokenInfo storage _tokenInfo = _tokensInfo[tokenId];
        require(_tokenInfo.froze, "not frozen");
        _safeTransferFrom(address(this), _tokenInfo.owner, tokenId, 1, "");
        _tokenInfo.froze = false;
        emit Unfroze(tokenId);
    }

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) external unCheck {
        require(msg.sender == miner, "caller error");
        TokenInfo storage _tokenInfo = _tokensInfo[tokenId];
        require(_tokenInfo.totalSupply == 0, "token exists");
        _mint(to, tokenId, amount, "");
        _tokenInfo.owner = to;
        _tokenInfo.totalSupply = amount;
        _totalSupply++;
        ticketCount[to]++;
        emit Mint(to, tokenId);
    }

    function burn(uint256 tokenId) external unCheck {
        require(msg.sender == miner, "caller error");
        TokenInfo storage _tokenInfo = _tokensInfo[tokenId];
        require(_tokenInfo.owner == msg.sender, "owner error");
        require(
            balanceOf(msg.sender, tokenId) == _tokenInfo.totalSupply,
            "Insufficient balance"
        );
        _totalSupply--;
        ticketCount[msg.sender]--;
        delete _tokensInfo[tokenId];
        _burn(msg.sender, tokenId, _tokenInfo.totalSupply);
        emit Burn(tokenId);
    }

    function isApprovedForAll(
        address account,
        address operator
    ) public view override returns (bool) {
        return operator == vault || super.isApprovedForAll(account, operator);
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory
    ) internal virtual override {
        if (_noCheck) return;
        uint256 _length = ids.length;
        for (uint256 i = 0; i < _length; ++i) {
            TokenInfo storage _tokenInfo = _tokensInfo[ids[i]];
            require(!greyList[ids[i]], "in greyList");
            require(_tokenInfo.owner == from, "not token owner");
            require(!_tokenInfo.froze, "token is froze");
            require(
                balanceOf(from, ids[i]) == amounts[i],
                "amount equals to balance"
            );
            _tokenInfo.owner = to;
        }
        ticketCount[from] -= _length;
        ticketCount[to] += _length;
        emit TransferOwner(from, to, ids, amounts);
    }

    function setGreyTokenId(uint256 _tokenId, bool _allow) external onlyOwner {
        require(greyList[_tokenId] != _allow, "repeat operation");
        greyList[_tokenId] = _allow;
        emit SetGreyTokenId(_tokenId, _allow);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, IERC165) returns (bool) {
        return
            interfaceId == type(IRental).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function totalSupply(uint256 id) public view returns (uint256) {
        return _tokensInfo[id].totalSupply;
    }

    function propertyRightOf(uint256 id) external view returns (address) {
        return _tokensInfo[id].owner;
    }

    function frozeOf(uint256 id) external view returns (bool) {
        return _tokensInfo[id].froze;
    }

    function exists(uint256 id) external view returns (bool) {
        return totalSupply(id) > 0;
    }
}
