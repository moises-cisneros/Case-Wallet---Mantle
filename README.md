# 🧾 Case Wallet Smart Contract – StandardUserWallet (MVP)

![Cooked on Mantle](https://img.shields.io/badge/Cooked%20on-Mantle-orange?style=for-the-badge&logo=ethereum)

## 🥘 From Our Kitchen to the Blockchain

Welcome to the **Case Kitchen** — where we don't just build contracts, we *cook* experiences for users in emerging economies. This MVP is our first *dish* served with care, crypto, and community at heart.

Every function, limit, and feature you see here is a carefully selected **ingredient**, mixed over the fire of decentralization, stirred with open-source love, and plated on the **Mantle Network**.

> 🍽️ Crafted by Chefs, not just devs — for Cookathon 02.

![Case Cookathon Dish - From Our Kitchen to the Blockchain](/assets/case-cookathon-banner.png)

## 📋 Project Overview

**StandardUserWallet** is the core Solidity smart contract for **Case**, a digital wallet solution designed to address economic instability in Bolivia. This contract implements key functionalities for **Profile 1 – Standard Users**, enabling secure and transparent crypto custody, transfers, and withdrawals using **USDT** on the **Mantle blockchain**.

> Case helps users convert local currency to stable crypto, transact peer-to-peer, and preserve their value over time — combining blockchain security with mobile-first usability.

---

## 🌐 Contract Deployment

| Network        | Status       | Address                                             |
|----------------|--------------|-----------------------------------------------------|
| Mantle Testnet | ✅ Live       | `0xaB054A94d8b9B46a0c8b98663a96AcF28C269a37`|
| Mantle Mainnet | 🔜 Planned    | *Pending security audits and testing*

> 🔗 You can explore the deployed contract on the [Mantle Testnet Explorer](https://explorer.sepolia.mantle.xyz/address/0xaB054A94d8b9B46a0c8b98663a96AcF28C269a37?tab=contract).

---

## 🎯 Key Features

- **Dual Balance System**: Manages off-chain (local) and on-chain (crypto) balances.
- **P2P Transfers**: Enables secure USDT transfers between registered users.
- **Currency Conversion**: Supports swapping between local balance and USDT (mock oracle).
- **Auto-Custody Wallet**: Designed for integration with external mobile wallets.
- **Daily & Transaction Limits**: Built-in rate limiting and daily transfer ceilings.
- **Emergency Controls**: System-wide pause functionality for incident response.

---

## 🏗️ Architecture

**StandardUserWallet** interacts with:

- **Flutter Mobile App** – UI layer and wallet interactions via Web3Dart.
- **Spring Boot Backend** – User management, KYC, and transaction recording.
- **PostgreSQL Database** – Stores user profiles, limits, and off-chain balances.
- **Oracle Service** – (Mocked) for token conversion rates.
- **OAuth 2.0 (Google)** – Authentication for user registration and login.

---

## 🚀 Contract Specifications

### Core Details

- **Profile Type**: Standard User (Profile 1)
- **Blockchain**: Mantle Network
- **Solidity Version**: `^0.8.20`
- **License**: MIT

### Security Features

- ✅ Reentrancy Protection (OpenZeppelin)
- ✅ Pausable Contract
- ✅ Access Control (admin-only functions)
- ✅ Daily Transfer Limits ($1,000/day)
- ✅ Transaction Cooldown (60 seconds)

---

### Constants & Limits

```solidity
uint256 public constant TRANSFER_FEE = 50;
uint256 public constant MAX_DAILY_TRANSFER = 1000 * 10**18;
uint256 public constant MIN_TRANSFER_AMOUNT = 1 * 10**15;
uint256 public constant MAX_SINGLE_TRANSFER = 10000 * 10**18;
````

---

## ✅ Feature Implementation Status

### ✅ Completed

| Feature           | Description                                  |
| ----------------- | -------------------------------------------- |
| User Registration | Admin-only registration with unique username |
| Dual Balances     | Tracks crypto balances per user              |
| P2P Transfers     | Secure transfers with fees                   |
| Conversion        | Swap between local and crypto balances       |
| Withdrawals       | Send USDT to external wallet                 |
| Rate Limiting     | 1-min delay between TXs                      |
| Daily Limit       | Enforced \$1000/day/user                     |
| Emergency Pause   | Pause/unpause by admin                       |
| Events            | Emitted for each operation                   |
| Access Control    | Role-restricted functions                    |

### ⏳ In Progress

| Feature             | Description                       |
| ------------------- | --------------------------------- |
| Oracle Integration  | Using fixed mock price for now    |
| Username Validation | Needs uniqueness logic refinement |
| Dynamic Fees        | Fee scaling based on usage        |
| Multisig            | For higher security operations    |

### 🔄 Planned

| Feature          | Description                          |
| ---------------- | ------------------------------------ |
| Profile Upgrades | E.g. to merchant/freelancer roles    |
| Staking          | Token staking for rewards            |
| DeFi             | Lending/saving protocol integrations |
| Cross-chain      | Expand beyond Mantle to EVM chains   |
| Analytics        | On-chain stats & dashboards          |
| Governance       | Voting via token holders             |
| NFT Profiles     | Avatars linked to NFTs               |
| Social Layer     | Friend list & request-based TXs      |

---

## 🛠️ Smart Contract Functions

### 👥 User Functions

- `registerUser(address, string memory username)`
- `transferCrypto(address to, uint amount)`
- `swapLocalToCrypto(uint localAmount)`
- `swapCryptoToLocal(uint cryptoAmount)`
- `withdrawCrypto(uint amount, address to)`

### 🔍 Query Functions

- `getUserProfile(address)`
- `getBalance(address)`
- `getDailyTransferLimit(address)`
- `getCurrentExchangeRate()`

### 🛡️ Admin Functions

- `emergencyPause()`
- `emergencyUnpause()`
- `updatePriceOracle(address)`
- `depositCrypto(address, uint amount)` *(for testing)*

---

## 🔐 Security Considerations

### ✅ Implemented Measures

1. Reentrancy Guard (OpenZeppelin)
2. SafeMath (via Solidity >= 0.8)
3. Role-based access control
4. Cooldowns & TX limits
5. Oracle abstraction
6. Event logging

### ⚠️ Known Limitations

- Oracle is mocked (no Chainlink yet)
- Only admin can register users
- Not upgradeable (suggest proxy for production)
- No multisig implemented yet

---

## 🧪 Deployment & Testing

### Prerequisites

- MetaMask or Wallet supporting Mantle
- MNT test tokens
- Hardhat or Remix for deployment
- Node.js & OpenZeppelin

```bash
npm install --save-dev hardhat @openzeppelin/contracts
```

### Steps

1. Compile and deploy to Mantle Testnet
2. Use mock oracle address in constructor
3. Verify contract on block explorer
4. Link with Spring Boot backend and Flutter front

---

## 🔄 Integration Guide

### 🧩 Backend (Spring Boot + Web3j)

```java
StandardUserWallet contract = StandardUserWallet.load(
    contractAddress, web3j, credentials, gasPrice, gasLimit);
contract.transferCrypto(toAddress, amount).send();
```

### 📱 Flutter Frontend (Web3dart)

```dart
final contract = DeployedContract(
  ContractAbi.fromJson(abi, 'StandardUserWallet'),
  EthereumAddress.fromHex(contractAddress),
);
await web3client.sendTransaction(
  credentials,
  Transaction.callContract(
    contract: contract,
    function: contract.function('transferCrypto'),
    parameters: [recipient, amount],
  ),
);
```

---

## 🧩 Contributing & Roadmap

We welcome contributors to help:

- Expand testing coverage
- Integrate price oracles (Chainlink, etc.)
- Improve user registration mechanisms
- Explore upgradeable patterns (UUPS)
- Implement multi-role support for merchants/freelancers

---

## 📄 License

MIT License. See [`LICENSE`](LICENSE).

---

## ⚠️ Disclaimer

This is an MVP developed for Cookathon purposes. It is not yet audited for production use. Use at your own risk. Security reviews and test coverage are required before deploying to Mantle mainnet.

---

## 🧠 Project Contact

- 🛠 Developers: Case Team (Cookathon Finalists)
- 🌐 Website / Info: *coming soon*
- 💬 For support: Open a GitHub issue or contact via X: [Case Wallet Bolivia](https://x.com/CaseBolivia).

---

**Built for Bolivia 🇧🇴. Powered by Mantle 🛠️. Backed by Purpose 💚.**
