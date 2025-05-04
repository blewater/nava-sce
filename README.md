# Simple n-of-m Multisig Wallet (Solidity/Foundry)

A simple implementation of an n-of-m multisig wallet supporting Ether transfers only.

## Features

### n-of-m Multisig 

At construction, statically initialize the contract with a list of owners and a required approval threshold.

### ETH Transfers 

Allows owners to propose, approve, and execute transactions to send ETH to a specified address.

### Event Emissions 

Emits events for important actions like deposits, transaction proposals, approvals, and executions, facilitating off-chain monitoring.

### Security Checks 

Includes checks for ownership, transaction validity, reentrancy protection.

## Project Structure

```
    ├── src/                  # Main contract source files
    │   └── MultisigWallet.sol
    ├── test/                 # Foundry test files
    │   └── MultisigWallet.t.sol
    ├── lib/                  # Dependencies (e.g. forge-std)
    ├── foundry.toml          # Foundry configuration file
    ├── soldeer.lock          # Soldeer package manager lock file
    ├── .github/              # GitHub workflow configuration files
```

## Setup and Testing

### Prerequisites

### [Foundry](https://getfoundry.sh/)
Ensure you have Foundry installed. Follow the instructions on the official Foundry website.

### [Soldeer](https://book.getfoundry.sh/projects/soldeer)
Ensure you have Soldeer installed. Follow the instructions on the official Foundry book.

## Built with Foundry v1.1.0 and Soldeer package manager.

### Getting Started

1.  **Clone the repository**
    ```bash
    git clone https://github.com/blewater/nava-sce.git
    cd nava-sce
    ```
2.  **Install dependencies**

You may also note the Github workflow file `.github/workflows/test.yml` for a bootstraping example.
    
    ```bash
    # Install Foundry: https://getfoundry.sh/
    curl -L https://foundry.paradigm.xyz | bash
    forge soldeer install
    ```

### Running Tests

Execute the test suite using Foundry:

```bash
forge test

# You can increase verbosity to see emitted events and logs:forge test -vvv
```

## Implementation Choices and Limitations
### ETH Only
This implementation only supports proposing and executing transactions involving the native currency (ETH). It does not handle ERC20 tokens or arbitrary contract calls, i.e. ERC4337 or Gnosis Safe allow.

### Fixed Owners/Threshold
The set of owners (m) and the required approval threshold (n) are set in the constructor and cannot be changed after deployment. Adding owner/threshold management would significantly increase complexity.

### No Transaction Data
Only `to` recipient address and `value` are included in the transactions. It doesn't support sending transaction data (calldata) for interacting with other contracts, i.e., ERC4337 or Gnosis Safe allow.
### Off-Chain Signature Aggregation
This is an on-chain multisig. It does not implement off-chain signature aggregation schemes.