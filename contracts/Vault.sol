// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITicket.sol";
import "./Initializable.sol";
import "hardhat/console.sol";

contract Vault is IERC1155Receiver, Initializable, Ownable {
    using SafeERC20 for IERC20;
    uint8 private constant CONFIRM_RESULT = 1;
    uint8 private constant WITHDRAW = 2;
    uint8 private constant CANCEL_EVENT = 3;
    enum Status {
        GUARANTEED,
        ENDED,
        CANCELLED
    }
    struct EventInfo {
        bytes32 underlyingHash;
        address issuer;
        uint256 ticketId;
        uint256 creditMargin;
        bool isStakeNFT;
        address baseToken;
        Status status;
        uint8 result;
        uint256[2] date;
    }
    mapping(uint256 => EventInfo) private _events;
    mapping(address => uint256) public creditAmount;
    address public signer;
    mapping(address => uint256) public nonce;
    uint256 private id;
    uint256 public minLockTime;
    ITicket private ticket;
    event Issue(uint256 eventId);
    event Cancelled(uint256 eventId);
    event Confirmed(uint256 eventId);
    event UserDeposit(address user, address token, uint256 amount);
    event UserWithdraw(address user, address token, uint256 amount);
    event UpdateSigner(address signer);
    event SetAllowToken(address token, uint256 creditAmount);

    function initialize(
        address _ticket,
        address _signer,
        address _owner
    ) external initializer {
        ticket = ITicket(_ticket);
        signer = _signer;
        _transferOwnership(_owner);
    }

    /**
     * _date 0:closeDate 1:maturityDate
     * */
    function issue(
        address _baseToken,
        uint256 _tokenId,
        bytes32 _underlyingHash,
        bool _isStakeNFT,
        uint256[2] calldata _date
    ) external {
        require(
            block.timestamp <= _date[0] && _date[1] >= _date[0],
            "invalid date"
        );
        require(creditAmount[_baseToken] > 0, "not allow baseToken");
        if (_isStakeNFT) {
            ticket.freeze(_tokenId, msg.sender);
        } else {
            ticket.use(msg.sender, _tokenId, _date[1] + minLockTime);
            IERC20(_baseToken).safeTransferFrom(
                msg.sender,
                address(this),
                creditAmount[_baseToken]
            );
        }
        id++;
        _events[id] = EventInfo({
            underlyingHash: _underlyingHash,
            issuer: msg.sender,
            ticketId: _tokenId,
            creditMargin: _isStakeNFT ? uint256(0) : creditAmount[_baseToken],
            isStakeNFT: _isStakeNFT,
            baseToken: _baseToken,
            status: Status.GUARANTEED,
            result: 0,
            date: _date
        });
        emit Issue(id);
    }

    function cancelEvent(
        uint256 _eventId,
        uint256 _expired,
        bytes calldata _signture
    ) external {
        EventInfo storage _event = _events[_eventId];
        require(_event.issuer == msg.sender, "caller error");
        require(_event.status == Status.GUARANTEED, "status error");
        require(
            _expired >= block.timestamp &&
                _expired <= block.timestamp + 10 minutes,
            "invalid expired"
        );
        address _signer = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(
                abi.encode(CANCEL_EVENT, block.chainid, _expired, _eventId)
            ),
            _signture
        );
        require(_signer == signer, "signer error");
        _event.status = Status.CANCELLED;
        if (_event.isStakeNFT) {
            ticket.unfreeze(_event.ticketId);
        } else {
            ticket.recover(_event.issuer, _event.ticketId);
            IERC20(_event.baseToken).safeTransfer(
                _event.issuer,
                _event.creditMargin
            );
        }
        emit Cancelled(_eventId);
    }

    function confirmResult(
        uint256 _eventId,
        uint8 _result,
        bytes calldata _signture
    ) external {
        EventInfo storage _event = _events[_eventId];
        require(_event.status == Status.GUARANTEED, "status error");
        address _signer = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(
                abi.encode(CONFIRM_RESULT, block.chainid, _eventId, _result)
            ),
            _signture
        );
        require(_signer == signer, "signer error");
        _event.status = Status.ENDED;
        _event.result = _result;
        if (_event.isStakeNFT) {
            ticket.unfreeze(_event.ticketId);
        } else {
            ticket.recover(_event.issuer, _event.ticketId);
            IERC20(_event.baseToken).safeTransfer(
                _event.issuer,
                _event.creditMargin
            );
        }
        emit Confirmed(_eventId);
    }

    function withdraw(
        address _token,
        uint256 _amount,
        uint256 _expired,
        bytes calldata _signature
    ) external {
        require(creditAmount[_token] > 0, "not allow token");
        console.log("%s", block.timestamp);
        require(
            _expired >= block.timestamp &&
                _expired <= block.timestamp + 10 minutes,
            "invalid expired"
        );
        address _signer = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(
                abi.encode(
                    WITHDRAW,
                    block.chainid,
                    msg.sender,
                    nonce[msg.sender],
                    _token,
                    _amount,
                    _expired
                )
            ),
            _signature
        );
        require(_signer == signer, "signer error");
        nonce[msg.sender]++;
        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit UserWithdraw(msg.sender, _token, _amount);
    }

    function deposit(address _token, uint256 _amount) external {
        require(creditAmount[_token] > 0, "not allow token");
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit UserDeposit(msg.sender, _token, _amount);
    }

    function setAllowToken(
        address _token,
        uint256 _creditAmount
    ) external onlyOwner {
        creditAmount[_token] = _creditAmount;
        emit SetAllowToken(_token, _creditAmount);
    }

    function updateSigner(address _signer) external onlyOwner {
        signer = _signer;
        emit UpdateSigner(_signer);
    }

    function events(uint256 _eventId) external view returns (EventInfo memory) {
        return _events[_eventId];
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
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
}
