# Example with Move 2024 Edition

This example demonstrates how to use Switchboard On-Demand quotes with the new Move 2024 edition.

## Overview

This example implements a quote consumer that:
- Integrates with Switchboard's quote verification system
- Validates price feeds and ensures freshness
- Tracks price updates and manages collateral ratios
- Provides examples of using Switchboard data in lending/collateral logic

## Prerequisites

- Bun.sh installed
- Sui move environment configured

## Installation

```bash
bun install
```

## Usage

### 0. (Optional) Deploy the Contract

Ensure the Move.toml is configured for the correct network and the sui client environment matches that.

```bash
sui client publish
```

### 1. Configure the Script

Edit the `scripts/ts/run.ts` file and set:
- `exampleAddress`: The address of your deployed example contract
- `queueId`: The Switchboard queue ID you want to use

### 2. Run the Script

```bash
bun run scripts/ts/run.ts
```

### 3. Check the Output

The script will output the transaction effects and object changes.
