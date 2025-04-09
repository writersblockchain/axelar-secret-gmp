# Using Axelar GMP for Cross-Chain Gas Payments

## Why Is Gas Abstraction Important?

Typically, users must hold native gas tokens on every chain they interact with. This requirement is cumbersome for mainstream adoption and can deter users from exploring new chains. Allowing users to pay gas with a stablecoin—rather than forcing them to acquire the native chain token—simplifies the on-chain experience and makes dApps more accessible. While current solutions exist, they are limited.

| Feature / Solution            | Native Gas Bridging  | Meta Transactions | dApp Relayers    | Axelar GMP              |
|-------------------------------|----------------------|-------------------|------------------|-------------------------|
| Supports automatic execution  | ❌ No                | ⚠️ Partial         | ⚠️ Partial       | ✅ Yes                  |
| Scalable to many chains       | ⚠️ Partial           | ❌ No              | ❌ No            | ✅ Yes                  |
| UX abstraction level          | ⚠️ Medium            | ⚠️ Medium          | ⚠️ Medium        | ✅ High                 |
| Developer effort required     | ⚠️ High              | ⚠️ Medium          | ⚠️ Medium        | ✅ Low (SDK/API ready)  |
| Trust assumptions             | ✅ Minimal           | ❌ Relayer trust   | ❌ Relayer trust | ✅ Trustless via Axelar |

## 🚀 How Axelar GMP Solves These Limitations

To simplify and streamline cross-chain gas payments, Axelar provides the `AxelarGasService` [smart contract](https://github.com/axelarnetwork/axelar-gmp-sdk-solidity/blob/main/contracts/interfaces/IAxelarGasService.sol). This contract plays a key role in managing gas fees for General Message Passing (GMP) by allowing applications to prepay gas on the source chain. It also handles gas refunds if too much was paid.

When sending a cross-chain message using Axelar GMP, the transaction must eventually be executed on the destination chain. This final execution step requires gas, and Axelar supports two approaches for covering that cost:

- Manual payment on the destination chain
- Prepayment on the source chain via AxelarGasService

With Axelar GMP, developers can focus on building cross-chain logic without worrying about gas management across chains.

## 🌐 System Design Overview

This guide walks you through a cross-chain system where users pay gas fees on one blockchain (Sepolia) using a stablecoin from another blockchain (Base-Sepolia), powered by Axelar's General Message Passing (GMP) and Interchain Token Transfers.

### 🧩 How It Works

1. User initiates a contract call on Sepolia, providing a destination chain (Base-Sepolia), a message, and a stablecoin (aUSDC) for gas. When paying with a stablecoin, the user calls [`setRemoteValuePayToken`](./CallContract.sol#L71-L106), transferring the fee in aUSDC from their wallet to the contract.

2. The contract:
   - Approves Axelar's Gas Service to spend the aUSDC,
   - Calls [payGasForContractCallWithToken](https://github.com/axelarnetwork/axelar-gmp-sdk-solidity/blob/00682b6c3db0cc922ec0c4ea3791852c93d7ae31/contracts/interfaces/IAxelarGasService.sol#L198) to pay for the cross-chain execution,
   - Invokes callContract() to trigger the contract call to the destination chain.

3. Axelar GMP handles the cross-chain message routing securely and trustlessly.

4. On the destination chain (Base-Sepolia), the `_execute()` method is automatically called with the payload data, storing the message and emitting an event.

### 🧪 Contract Snippet

Here's the key logic from `setRemoteValuePayToken()` that enables ERC-20 based gas payments:

```solidity
IERC20(gasToken).transferFrom(msg.sender, address(this), gasFeeAmount);
IERC20(gasToken).approve(address(gasService), gasFeeAmount);

gasService.payGasForContractCallWithToken(
    address(this),
    destinationChain,
    destinationAddress,
    payload,
    gasTokenSymbol,
    0,
    gasToken,
    gasFeeAmount,
    msg.sender
);

gateway().callContract(destinationChain, destinationAddress, payload);
```

## ⚙️ How Axelar Enables This System

Axelar makes this cross-chain gas payment system possible by combining **General Message Passing (GMP)** with **Interchain Token Transfers**.

### ✅ 1. Axelar GMP Relays the Gas Payment Request

Axelar's **General Message Passing (GMP)** allows smart contracts on one blockchain to securely call smart contracts on another blockchain.

In this system:

1. The user initiates a message from **Chain A (Sepolia)** using the `setRemoteValuePayToken()` function in the `CallContract`.
2. This message includes a payload (e.g. a string) and gas payment information.
3. The contract calls `gateway().callContract(...)`, which forwards the message to Axelar.
4. **Axelar GMP** securely relays the message to **Chain B (Base-Sepolia)** and automatically executes the `_execute()` function on the destination contract.

✅ **Result**: The message is delivered trustlessly and executed on the destination chain.

### ✅ 2. Axelar Interchain Token Transfers Convert ERC-20 into Native Gas

To avoid requiring users to hold native tokens (like ETH) on Sepolia, this system allows them to pay gas fees using a stablecoin (e.g. aUSDC) from Base-Sepolia.

1. The user provides a gas fee in aUSDC by calling `setRemoteValuePayToken()` and passing:
   - The token address (e.g. aUSDC),
   - The amount,
   - The token symbol understood by Axelar (e.g. `"aUSDC"`).

2. The contract:
   - Transfers the tokens from the user,
   - Approves Axelar's Gas Service to spend them,
   - Calls `gasService.payGasForContractCallWithToken(...)`.

3. **Axelar Interchain Token Transfers**:
   - Accept the aUSDC payment,
   - **Convert it to native gas** (e.g. ETH on Sepolia),
   - **Distribute the gas** to Axelar relayers so they can process the cross-chain transaction.

✅ **Result**: The user pays in stablecoins, and Axelar ensures the destination chain receives the native gas required to complete the message execution.

## 🧾 Smart Contract Example

This section explains the [`CallContract`](./CallContract.sol) smart contract and how to deploy and use it on **both Sepolia (Chain A)** and **Base-Sepolia (Chain B)** to enable cross-chain messaging with gas paid in ERC-20 tokens.

### 🔍 Contract Overview

```solidity
contract CallContract is AxelarExecutable {
    ...
    function setRemoteValuePayToken(...) external { ... }
    function _execute(...) internal override { ... }
}
```

This contract allows:
- Sending a string message cross-chain.
- Paying Axelar gas fees in native ETH or an ERC-20 token (like aUSDC).
- Automatically executing logic on the destination chain once the message is delivered by Axelar GMP.

### 🧱 Deployment on Both Chains

You will deploy the same contract to both chains: Sepolia and Base-Sepolia.

Each deployment requires the following constructor parameters:

```solidity
constructor(address _gateway, address _gasReceiver)
```

#### Use Remix for Deployment

Deploy your contract using [Remix Ethereum IDE](https://remix.ethereum.org/) with the following addresses:

**Base-Sepolia Configuration:**
- Chain Name: `base-sepolia`
- Gateway Contract: `0xe432150cce91c13a887f7D836923d5597adD8E31`  
- Gas Service Contract: `0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6`

**Ethereum Sepolia Configuration (Chain ID: 11155111):**
- Chain Name: `ethereum-sepolia`
- Gateway Contract: `0xe432150cce91c13a887f7D836923d5597adD8E31`
- Gas Service Contract: `0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6`

> You can find the complete addresses in [Axelar's testnet contract addresses documentation](https://docs.axelar.dev/dev/reference/testnet-contract-addresses).
>
> For aUSDC token information and denominations, refer to the [same documentation page](https://docs.axelar.dev/dev/reference/testnet-contract-addresses).

### 📬 Sending a Message with Token-based Gas Payment

Once deployed, call `setRemoteValuePayToken()` on Sepolia to send a message to Base-Sepolia, paying for gas with an ERC-20 token (like aUSDC):

```solidity
function setRemoteValuePayToken(
    string destinationChain,
    string destinationAddress,
    string _message,
    address gasToken,
    uint256 gasFeeAmount,
    string gasTokenSymbol
)
```

Example usage:
```solidity
setRemoteValuePayToken(
    "base-sepolia",
    "<BaseSepolia_Contract_Address>",
    "Hello from Sepolia!",
    <aUSDC_Address>,
    500000,                 // Amount in aUSDC
    "aUSDC"
);
```

**What Happens Under the Hood:**
1. Transfers `gasFeeAmount` of aUSDC from the user to the contract.
2. Approves the Axelar Gas Service to spend that aUSDC.
3. Calls `payGasForContractCallWithToken()` to pay for gas on the destination chain.
4. Triggers the actual cross-chain message using Axelar's `callContract()`.

### 🔁 Receiving the Message on Destination Chain

On Base-Sepolia, the Axelar relayer will call the `_execute()` function:

```solidity
function _execute(
    bytes32 commandId,
    string calldata _sourceChain,
    string calldata _sourceAddress,
    bytes calldata _payload
) internal override
```

This function:
- Decodes the message string from `_payload`.
- Stores it in the `message` state variable.
- Records the source chain and address.
- Emits an `Executed` event for traceability.

**Output:**

```solidity
event Executed(bytes32 commandId, string from, string message);
```

You can then query:
- `message` – the latest message received
- `sourceChain` – the origin chain name
- `sourceAddress` – the address that sent the message

### 🧪 Native ETH Gas Payment Alternative

The contract also supports native ETH gas payment via:

```solidity
function setRemoteValue(
    string calldata destinationChain,
    string calldata destinationAddress,
    string calldata _message
) external payable
```

This allows you to pass ETH with the transaction and lets Axelar use it to cover gas on the destination chain.

## ✅ Summary

| Function | Description |
|----------|-------------|
| `setRemoteValuePayToken()` | Sends a message and pays gas with ERC-20 (like aUSDC). |
| `setRemoteValue()` | Sends a message and pays gas with native ETH. |
| `_execute()` | Receives and processes the message on the destination chain. |

With this contract deployed on both Sepolia and Base-Sepolia, you can enable cross-chain communication where users pay gas with stablecoins from another chain, creating a smooth experience without managing native tokens on both chains.

### Key Challenges - Transaction Latency in Cross-Chain Messaging

One of the major challenges in cross-chain gas payment systems using Axelar GMP is **transaction latency**. Cross-chain messages inherently take longer to process than single-chain transactions due to:

- Confirmation requirements on the source chain
- The time needed for Axelar validators to reach consensus
- Block confirmation times on the destination chain
- Network congestion across multiple chains

This latency has the potential to create a suboptimal user experience, as users may wait minutes or even longer for their cross-chain messages to be delivered and executed, especially during network congestion.

### Solution

To mitigate transaction latency, implement a **improved progressive UX for Axelarscan on Testnet with immediate feedback**:

1. **Optimistic UI Updates**: Show users an immediate "pending" state in the UI after a user initiates a cross-chain transaction, with clear indicators that the operation is in progress (From my experience, this seems much better on Axelarscan Mainnet than Testnet. My [testnet transaction on Axelarscan](https://testnet.axelarscan.io/gmp/0xce16019f75c07582b665b1f70cccdd2b8504387ab8cd2f5d68ee308ccbf476ac-6) is still pending hours later)



