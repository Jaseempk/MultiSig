## Multi-Signature Wallet (MSig)

**Overview**

The Multi-Signature Wallet (MSig) is a sophisticated smart contract developed on the Ethereum blockchain. Designed for enhanced security in asset management, it requires multiple approvals from designated owners before any transaction execution. This project is ideal for decentralized organizations, joint accounts, or any scenario requiring collective decision-making for fund management.

**Key Features**

**Multi-Signature Approval**

Securely executes transactions only after receiving the required number of approvals from the wallet owners, preventing unauthorized access and actions.

**Flexible Owner Management**

Dynamic addition, removal, and replacement of wallet owners, providing adaptability in managing control over the wallet.

**Comprehensive Transaction Control**

Supports submission of transactions by any owner, complete with destination, value, and data.
Keeps track of approvals for each transaction, ensuring clarity and transparency in transaction management.

**Advanced Security**

Utilizes OpenZeppelin's ECDSA library for secure signature verification.
Custom error messages for different failure scenarios enhance security and aid in troubleshooting.









## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
