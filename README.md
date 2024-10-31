# sui

Switchboard On-Demand Sui Integration

# Switchboard On-Demand Integration Guide

This guide covers the setup and use of Switchboard data feeds within your project, using the `Aggregator` module for updating feeds and integrating `Switchboard` in Move language.

## Creating an Aggregator and Sending Transactions

To create a feed aggregator, initialize it with specific parameters such as feed hash, name, authority, and settings for sample size, staleness, and variance.

### Example: Creating and Sending a Transaction

```typescript
{
  feedHash,
  name: feedName,
  authority: userAddress,
  minSampleSize,
  maxStalenessSeconds,
  maxVariance,
  minResponses: minJobResponses,
}

// Send the transaction
const res = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction,
  options: {
    showEffects: true,
  },
});

// Capture the created aggregator ID
let aggregatorId;
res.effects?.created?.forEach((c) => {
  if (c.reference.objectId) {
    aggregatorId = c.reference.objectId;
  }
});

// Wait for transaction confirmation
await client.waitForTransaction({
  digest: res.digest,
});

// Log the transaction effects
console.log(res);
Updating Feeds
With Switchboard On-Demand, passing the PTB (proof-to-be) into the feed update method handles the update automatically.

javascript
Copy code
const aggregator = new Aggregator(sb, aggregatorId);

// Create the PTB transaction
let feedTx = new Transaction();

// Fetch and log the oracle responses
const response = await aggregator.fetchUpdateTx(feedTx);
console.log("Fetch Update Oracle Response: ", response);

// Send the transaction
const res = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: feedTx,
  options: {
    showEffects: true,
  },
});

// Wait for transaction confirmation
await client.waitForTransaction({
  digest: res.digest,
});

// Log the transaction effects
console.log(res);
```

Note: Ensure the Switchboard Aggregator update is the first action in your PTB or occurs before referencing the feed update.

## Adding Switchboard to Move Code

To integrate Switchboard with Move, add the following dependencies to Move.toml:

```toml
[dependencies.switchboard]
git = "https://github.com/switchboard-xyz/sui.git"
subdir = "on_demand/"
rev = "main" # testnet or mainnet

[dependencies.Sui]
git = "https://github.com/MystenLabs/sui.git"
subdir = "crates/sui-framework/packages/sui-framework"
rev = "3ada97c109cc7ae1b451cb384a1f2cfae49c8d3e" # testnet or mainnet
Once dependencies are configured, updated aggregators can be referenced easily.
```

## Example Move Code for Using Switchboard Values

In the example.move module, use the Aggregator and CurrentResult types to access the latest feed data.

```move
module example::switchboard;

use switchboard::aggregator::{Aggregator, CurrentResult};
use switchboard::decimal::Decimal;

public entry fun use_switchboard_value(aggregator: &Aggregator) {

    // Get the latest update info for the feed
    let current_result = aggregator.current_result();

    // Access various result properties
    let result: Decimal = current_result.result();        // Median result
    let result_u128: u128 = result.value();               // Result as u128
    let min_timestamp_ms: u64 = current_result.min_timestamp_ms(); // Oldest data timestamp
    let max_timestamp_ms: u64 = current_result.max_timestamp_ms(); // Latest data timestamp
    let range: Decimal = current_result.range();          // Range of results
    let mean: Decimal = current_result.mean();            // Average (mean)
    let stdev: Decimal = current_result.stdev();          // Standard deviation
    let max_result: Decimal = current_result.max_result();// Max result
    let min_result: Decimal = current_result.min_result();// Min result
    let neg: bool = result.neg();                         // Check if negative (ignore for prices)

    // Use the computed result as needed...
}
```

This implementation allows you to read and utilize Switchboard data feeds within Move. If you have any questions or need further assistance, please contact the Switchboard team.
