# Distributor Contract

The `Distributor` contract is designed to distribute ERC20 tokens to multiple recipients using predefined splits. It features batch processing for large recipient lists and leverages OpenZeppelin's `AccessControl` for role-based permissions.

---

## Features

- **Batch Token Distribution**: Distributes tokens in batches for scalability.
- **Role-Based Access Control**: Implements roles like `FORWARDER_ROLE` and `OPERATOR_ROLE`.
- **Customizable Batch Size**: Allows administrators to set batch sizes for optimized processing.
- **Flexible Splits**: Supports distribution based on specified percentage splits.
- **Recoverable Funds**: Provides administrators the ability to recover unallocated funds.

---

## Requirements

- [Foundry](https://book.getfoundry.sh/) installed for development and deployment.
- ERC20 token address for distribution.
- Ethereum wallet and RPC endpoint configured for deployment.

---

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository_url>
cd distributor-contract
```

### 2. Install Dependencies

```bash
forge install
```

### 3. Compile the Contract

```bash
forge build
```

---

## Deployment Instructions

### 1. Set Up Environment Variables

Create a `.env` file and set the required variables:

```env
RPC_URL=<Your_RPC_Endpoint>
PRIVATE_KEY=<Your_Private_Key>
ERC20_ADDRESS=<Address_of_ERC20_Token>
OPERATOR_ADDRESS=<Address_with_OPERATOR_ROLE>
FORWARDER_ADDRESS=<Address_with_FORWARDER_ROLE>
```

### 2. Deploy the Contract

Deploy the contract using Foundry:

```bash
forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY Distributor --constructor-args $FORWARDER_ADDRESS $OPERATOR_ADDRESS $ERC20_ADDRESS
```

---

## Usage Instructions

### Add Recipients

Operators should first add recipients to the list:

```solidity
distributor.updateReceipients(recipients);
```

### Deposit Tokens

Operators can deposit tokens into the contract:

```solidity
distributor.deposit(amount);
```

### Forward Funds

Distribute tokens to recipients in batches. Use `startIndex` to specify the batch's starting recipient:

```solidity
distributor.forward_funds(totalAmount, splits, startIndex);
```

### Update Batch Size

Operators can adjust the batch size for optimized processing:

```solidity
distributor.updateBatchSize(newBatchSize);
```

### Update Recipients

Operators can modify the list of recipients:

```solidity
distributor.updateReceipients(newRecipients);
```

### Recover Funds

Administrators can recover unallocated funds:

```solidity
distributor.recoverFunds(destinationAddress);
```

---

## Access Control

The `Distributor` contract uses OpenZeppelin's `AccessControl` for permissions. Below are some examples of managing roles:

### Grant a Role

Grant a specific role (e.g., `FORWARDER_ROLE`):

```solidity
await accessControl.connect(admin).grantRole(FORWARDER_ROLE, forwarder);
```

### Revoke a Role

Revoke a specific role (e.g., `FORWARDER_ROLE`):

```solidity
await accessControl.connect(admin).revokeRole(FORWARDER_ROLE, account);
```

### Renounce a Role

Renounce the admin role:

```solidity
await accessControl.connect(admin).renounceRole(DEFAULT_ADMIN_ROLE, admin);
```

---

## Example: Transitioning Admin Role

The following steps demonstrate how to transfer the admin role to a new address (`accessManager`):

1. **Revoke Old Roles**

   ```solidity
   await accessControl.connect(admin).revokeRole(FORWARDER_ROLE, account);
   ```

2. **Grant the Admin Role to the New Admin**

   ```solidity
   await accessControl.connect(admin).grantRole(DEFAULT_ADMIN_ROLE, accessManager);
   ```

3. **Renounce the Current Admin Role**

   ```solidity
   await accessControl.connect(admin).renounceRole(DEFAULT_ADMIN_ROLE, admin);
   ```

---

## Notes

- **Splits Validation**: Ensure splits sum to 100 before calling `forward_funds`.
- **Batch Size**: The default batch size is `100` and can be adjusted as needed.
- **Security**: Validate recipients and roles to prevent misuse or loss of funds.

---

## License

This project is licensed under the MIT License.
