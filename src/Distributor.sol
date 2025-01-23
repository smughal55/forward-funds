// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

using SafeERC20 for IERC20;

/**
 * @title Distributor Contract
 * @notice This contract facilitates the distribution of ERC20 tokens to multiple recipients
 *         based on predefined splits, with support for batched processing.
 */
contract Distributor is AccessControl, ReentrancyGuard {
    /// @dev Error thrown when a zero address is provided.
    error Distributor__AddressZero();

    /// @dev Error thrown when there are no recipients.
    error Distributor__NoRecipients();

    /// @dev Error thrown when the provided amount is zero.
    error Distributor__AmountZero();

    /// @dev Error thrown when there are insufficient funds in the contract.
    error Distributor__InsufficientFunds();

    /// @dev Error thrown when the provided splits are invalid.
    error Distributor__InvalidSplits();

    /// @dev Error thrown when the split amounts do not sum to 100%.
    error Distributor__InvalidSplitAmounts();

    /// @dev Error thrown when the batch size is set to zero.
    error Distributor__BatchSizeZero();

    /// @dev Error thrown when an unauthorized caller attempts an operation.
    error Distributor__CallerNotAuthorized(address caller);

    /// @notice Emitted when tokens are deposited into the contract.
    /// @param operator The address of the operator depositing the tokens.
    /// @param amount The amount of tokens deposited.
    event Deposited(address indexed operator, uint256 amount);

    /// @notice Emitted when funds are forwarded to recipients.
    /// @param forwarder The address of the forwarder.
    /// @param totalAmount The total amount distributed.
    /// @param splits The array of split percentages for the distribution.
    /// @param lastIndex The index of the last recipient processed in the batch.
    event ForwardedFunds(
        address indexed forwarder,
        uint256 totalAmount,
        uint256[] splits,
        uint256 lastIndex
    );

    /// @notice Emitted when recipients are updated.
    /// @param operator The address of the operator updating the recipients.
    /// @param newRecipients The updated list of recipients.
    event RecipientsUpdated(address indexed operator, address[] newRecipients);

    /// @notice Emitted when the batch size is updated.
    /// @param operator The address of the operator updating the batch size.
    /// @param newBatchSize The new batch size.
    event BatchSizeUpdated(address indexed operator, uint256 newBatchSize);

    /// @dev Role identifier for forwarders.
    bytes32 public constant FORWARDER_ROLE = keccak256("FORWARDER_ROLE");

    /// @dev Role identifier for operators.
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice The ERC20 token distributed by the contract.
    IERC20 private immutable underlyingAsset;

    /// @notice The list of recipients to receive token distributions.
    address[] private recipients;

    /// @notice The maximum number of recipients processed per batch.
    uint256 public batchSize = 100;

    /**
     * @notice Ensures that the provided split amounts are valid and sum to 100%.
     * @param splits The array of split percentages.
     */
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

    /**
     * @notice Ensures that the provided recipients are valid (non-zero addresses).
     * @param _recipients The array of recipient addresses.
     */
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

    /**
     * @notice Constructor to initialize the Distributor contract.
     * @param _forwarder The address of the forwarder role.
     * @param _operator The address of the operator role.
     * @param _underlyingAsset The address of the ERC20 token to distribute.
     */
    constructor(
        address _forwarder,
        address _operator,
        address _underlyingAsset
    ) {
        if (_underlyingAsset == address(0)) {
            revert Distributor__AddressZero();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, _operator);
        _grantRole(FORWARDER_ROLE, _forwarder);
        underlyingAsset = IERC20(_underlyingAsset);
    }

    /**
     * @notice Deposits tokens into the contract.
     * @param amount The amount of tokens to deposit.
     */
    function deposit(uint256 amount) external {
        if (!hasRole(OPERATOR_ROLE, msg.sender)) {
            revert Distributor__CallerNotAuthorized(msg.sender);
        }
        if (amount == 0) {
            revert Distributor__AmountZero();
        }
        underlyingAsset.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice Forwards funds to recipients in batches.
     * @param totalAmount The total amount to distribute.
     * @param splits The array of split percentages.
     * @param startIndex The starting index for the batch.
     */
    function forward_funds(
        uint256 totalAmount,
        uint256[] calldata splits,
        uint256 startIndex
    ) external validSplitAmounts(splits) nonReentrant {
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

        address[] memory _recipients = recipients;
        uint256 endIndex = startIndex + batchSize > _recipients.length
            ? _recipients.length
            : startIndex + batchSize;

        for (uint256 i = startIndex; i < endIndex; i++) {
            if (splits[i] == 0) continue;
            uint256 amount = (totalAmount * splits[i]) / 100;
            underlyingAsset.safeTransfer(_recipients[i], amount);
        }

        emit ForwardedFunds(msg.sender, totalAmount, splits, endIndex - 1);
    }

    /**
     * @notice Updates the batch size for processing recipients.
     * @param newBatchSize The new batch size.
     */
    function updateBatchSize(uint256 newBatchSize) external {
        if (!hasRole(OPERATOR_ROLE, msg.sender)) {
            revert Distributor__CallerNotAuthorized(msg.sender);
        }
        if (newBatchSize == 0) {
            revert Distributor__BatchSizeZero();
        }
        batchSize = newBatchSize;
        emit BatchSizeUpdated(msg.sender, newBatchSize);
    }

    /**
     * @notice Recovers all funds in the contract and transfers them to a specified address.
     * @param to The address to receive the funds.
     */
    function recoverFunds(address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) {
            revert Distributor__AddressZero();
        }
        uint256 balance = underlyingAsset.balanceOf(address(this));
        if (balance > 0) {
            underlyingAsset.safeTransfer(to, balance);
        }
    }

    /**
     * @notice Updates the list of recipients.
     * @param _recipients The new list of recipients.
     */
    function updateReceipients(
        address[] calldata _recipients
    ) external validRecipients(_recipients) {
        if (!hasRole(OPERATOR_ROLE, msg.sender)) {
            revert Distributor__CallerNotAuthorized(msg.sender);
        }
        if (_recipients.length == 0) {
            revert Distributor__NoRecipients();
        }
        recipients = _recipients;
        emit RecipientsUpdated(msg.sender, _recipients);
    }

    /**
     * @notice Returns the address of the underlying ERC20 token.
     * @return The address of the underlying token.
     */
    function getUnderlyingAsset() external view returns (address) {
        return address(underlyingAsset);
    }

    /**
     * @notice Returns the list of recipients.
     * @return The list of recipient addresses.
     */
    function getRecipients() external view returns (address[] memory) {
        return recipients;
    }
}
