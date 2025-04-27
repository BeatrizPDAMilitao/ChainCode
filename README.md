# Medsky Solidity Smart Contract

This project contains the Solidity version of the Medsky medical record access control system, built using Hardhat for development and testing.

## 🚀 Getting Started
### 1. Install Dependencies

Make sure you have Node.js installed. Then run:
```shell
npm install
```

If you're starting fresh, install Hardhat:

```shell
npm install --save-dev hardhat
npx hardhat
```
When prompted, choose "Create a JavaScript project".

### 2. Compile the Contracts

```shell
npx hardhat compile
```

### 🧪 3. Run the Test Suite
```shell
npx hardhat test
```
To run a specific file only:

```shell
npx hardhat test test/MedskyContract.test.js
```

### 🧼 Optional: Clean Artifacts

```shell
npx hardhat clean
```

### To Create .abi and .bin file
```shell
solc --abi --bin healthyContract.sol -o build
```

### To create a wrapper for the contract
```shell
web3j generate solidity   --binFile=build/MedicalRecordAccess.bin   --abiFile=build/MedicalRecordAccess.abi   --outputDir=app/src/main/java   --package=com.example.ethktprototype.contracts
```

### 🛠️ Developer Notes
- Contracts are written in Solidity ^0.8.28
- Tests use Ethers.js (v6+) and Chai
- Structs are returned as arrays (not objects) — access fields like record[0], record[1], etc.
- Events are emitted for record creation, access logging, and bad actions

### 📄 License
MIT