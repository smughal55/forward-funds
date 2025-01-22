// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

using SafeERC20 for IERC20;

contract Distributor is AccessControl, ReentrancyGuard {
    error Distributor__AddressZero();
    error Distributor__NoRecipients();
    error Distributor__AmountZero();
    error Distributor__InsufficientFunds();
    error Distributor__InvalidSplits();
    error Distributor__InvalidSplitAmounts();
    error Distributor__CallerNotAuthorized(address caller);

    event Deposited(address indexed operator, uint256 amount);
    event ForwardedFunds(
        address indexed forwarder,
        uint256 totalAmount,
        uint256[] splits
    );
    event RecipientsUpdated(address indexed operator, address[] newRecipients);

    // Create a new role identifier for the FORWARDER role
    bytes32 public constant FORWARDER_ROLE = keccak256("FORWARDER_ROLE");
    // Create a new role identifier for the OPERATOR role
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    IERC20 private immutable underlyingAsset;
    address[] private recipients;

    modifier validSplitAmounts(uint256[] memory splits) {
        uint256 sum;
        for (uint256 i = 0; i < splits.length; ) {
            sum += splits[i];
            if (sum > 100) revert Distributor__InvalidSplitAmounts();
            unchecked {
                ++i;
            }
        }
        if (sum != 100) {
            revert Distributor__InvalidSplitAmounts();
        }
        _;
    }

    modifier validRecipients(address[] memory _recipients) {
        for (uint256 i = 0; i < _recipients.length; ) {
            if (_recipients[i] == address(0)) {
                revert Distributor__AddressZero();
            }
            unchecked {
                ++i;
            }
        }
        _;
    }

    constructor(
        address _forwarder,
        address _operator,
        address _underlyingAsset,
        address[] memory _recipients
    ) validRecipients(_recipients) {
        if (_underlyingAsset == address(0)) {
            revert Distributor__AddressZero();
        }
        if (_recipients.length == 0) {
            revert Distributor__NoRecipients();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, _operator);
        _grantRole(FORWARDER_ROLE, _forwarder);
        underlyingAsset = IERC20(_underlyingAsset);
        recipients = _recipients;
    }

    function deposit(uint256 amount) external {
        // Check that the calling account has the operator role
        if (!hasRole(OPERATOR_ROLE, msg.sender)) {
            revert Distributor__CallerNotAuthorized(msg.sender);
        }
        if (amount == 0) {
            revert Distributor__AmountZero();
        }
        underlyingAsset.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount);
    }

    function forward_funds(
        uint256 totalAmount,
        uint256[] calldata splits
    ) external validSplitAmounts(splits) nonReentrant {
        // Check that the calling account has the forwarder role
        if (!hasRole(FORWARDER_ROLE, msg.sender)) {
            revert Distributor__CallerNotAuthorized(msg.sender);
        }
        if (totalAmount == 0) {
            revert Distributor__AmountZero();
        }
        if (underlyingAsset.balanceOf(address(this)) < totalAmount) {
            revert Distributor__InsufficientFunds();
        }
        if (splits.length != recipients.length) {
            revert Distributor__InvalidSplits();
        }

        // cache the recipients to avoid multiple storage reads
        address[] memory _recipients = recipients;

        for (uint256 i = 0; i < _recipients.length; i++) {
            //skip if the split is 0
            if (splits[i] == 0) {
                continue;
            }
            underlyingAsset.safeTransfer(
                _recipients[i],
                (totalAmount * splits[i]) / 100
            );
        }

        emit ForwardedFunds(msg.sender, totalAmount, splits);
    }

    function recoverFunds(address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) {
            revert Distributor__AddressZero();
        }
        uint256 balance = underlyingAsset.balanceOf(address(this));
        if (balance > 0) {
            underlyingAsset.safeTransfer(to, balance);
        }
    }

    function updateReceipients(address[] calldata _recipients) external {
        // Check that the calling account has the operator role
        if (!hasRole(OPERATOR_ROLE, msg.sender)) {
            revert Distributor__CallerNotAuthorized(msg.sender);
        }
        if (_recipients.length == 0) {
            revert Distributor__NoRecipients();
        }
        recipients = _recipients;

        emit RecipientsUpdated(msg.sender, _recipients);
    }

    function getUnderlyingAsset() external view returns (address) {
        return address(underlyingAsset);
    }

    function getRecipients() external view returns (address[] memory) {
        return recipients;
    }
}
