# Switchboard Oracle Quote Verifier Example


## Quick Start Guide

Get up and running with Switchboard oracles in 5 minutes.

## What You'll Build

A smart contract that:
- Fetches real-time BTC/USD price from multiple oracles
- Verifies oracle signatures
- Validates data freshness and price deviation
- Stores verified prices for your DeFi logic

## Prerequisites

- Sui CLI installed
- Bun or Node.js
- Testnet SUI tokens

## 30-Second Setup

```bash
# 1. Clone and navigate
cd sui/examples/example_2025

# 2. Install dependencies
bun install

# 3. Build
sui move build

# 4. Deploy
sui client publish --gas-budget 100000000

# 5. Run example (replace with your package ID)
EXAMPLE_PACKAGE_ID=0xYOUR_PACKAGE_ID bun start
```

## Expected Output

```
🚀 Switchboard Oracle Quote Verifier Example

📡 Connecting to Switchboard...
✅ Switchboard Connected

📝 Step 1: Creating QuoteConsumer...
✅ QuoteConsumer Created: 0x...

🔍 Step 2: Fetching Oracle Data...
✅ Oracle data fetched successfully

🔐 Step 3: Verifying and Updating Price...
✅ Price Update Successful!

📢 Events Emitted:
🎯 PriceUpdated Event:
   New Price: 98765432100
   Oracles Confirmed: 3
   
✨ Example completed successfully!
```

## What Just Happened?

1. **Created a QuoteConsumer**: Your on-chain oracle data consumer with verification
2. **Fetched Oracle Data**: Got signed price data from 3 Switchboard oracles
3. **Verified Signatures**: Cryptographically proved data authenticity
4. **Validated Freshness**: Ensured data is < 10 seconds old
5. **Stored Price**: Saved verified BTC/USD price on-chain

## Key Concepts

### Quote Verifier

The security layer that ensures oracle data is legitimate:

```move
// Creates a verifier tied to an oracle queue
let verifier = switchboard::quote::new_verifier(ctx, queue);

// Verifies signatures and timestamp
verifier.verify_quotes(&quotes, clock);
```

### Why It Matters

Without verification:
- Anyone could submit fake prices (if you don't check the queue id)
- You'd have to track last update for each price feed yourself (or prices could be manipulated)

With verification:
- Only fresh oracle data accepted
- You don't need to store update age or check against it

### Security Checks

The example performs 4 security validations:

```move
// 1. Verify oracle signatures
verifier.verify_quotes(&quotes, clock);

// 2. Check quote exists
assert!(verifier.quote_exists(feed_hash), EInvalidQuote);

// 3. Validate freshness (< 10 seconds)
assert!(quote.timestamp_ms() + 10000 > clock.timestamp_ms(), EQuoteExpired);

// 4. Check price deviation (< 10%)
validate_price_deviation(&last_price, &new_price, max_deviation_bps);
```

## Next Steps

### 1. Customize for Your Use Case

```move
// Example: Lending Protocol
public fun check_liquidation(
    consumer: &QuoteConsumer,
    position: &Position,
    clock: &Clock
): bool {
    // Ensure fresh data
    assert!(is_price_fresh(consumer, clock), EQuoteExpired);
    
    let price = consumer.last_price.borrow();
    let collateral_value = position.collateral * price.value();
    let debt_value = position.debt;
    
    // Liquidate if under 110% collateralization
    collateral_value < debt_value * 110 / 100
}
```

### 2. Add Multiple Price Feeds

```typescript
// Fetch multiple assets
const quotes = await Quote.fetchUpdateQuote(sb, tx, {
  feedHashes: [
    "0x7418...", // BTC/USD
    "0x13e5...", // ETH/USD  
    "0xef0d...", // SOL/USD
  ],
  numOracles: 3,
});
```

### 3. Set Up Price Monitoring

```typescript
// Listen for price updates
client.subscribeEvent({
  filter: {
    MoveEventType: `${packageId}::example_2025::PriceUpdated`
  },
  onMessage: (event) => {
    console.log("New price:", event.parsedJson.new_price);
    // Alert, update database, trigger logic, etc.
  }
});
```

### 4. Deploy to Mainnet

```bash
# Update Move.toml for mainnet
[dependencies.Switchboard]
rev = "mainnet"  # Change from "testnet"

# Build and deploy
sui move build
sui client publish --gas-budget 100000000
```

## Common Use Cases

### DeFi Lending
```move
// Get collateral value for liquidation checks
let price = get_current_price(&consumer);
let collateral_value = calculate_value(amount, price);
```

### DEX Trading
```move
// Get spot price for trades
let btc_price = get_current_price(&btc_consumer);
let eth_price = get_current_price(&eth_consumer);
let rate = calculate_rate(btc_price, eth_price);
```

### Options Settlement
```move
// Determine if option is in-the-money
let spot_price = get_current_price(&consumer);
let is_itm = spot_price.value() > strike_price;
```

### Prediction Markets
```move
// Resolve market based on real-world data
let result = get_current_price(&consumer);
resolve_market(market, result);
```

## Available Feeds

| Asset | Feed Hash |
|-------|-----------|
| BTC/USD | `0x4cd1cad962425681af07b9254b7d804de3ca3446fbfd1371bb258d2c75059812` |
| ETH/USD | `0xa0950ee5ee117b2e2c30f154a69e17bfb489a7610c508dc5f67eb2a14616d8ea` |
| SOL/USD | `0x822512ee9add93518eca1c105a38422841a76c590db079eebb283deb2c14caa9` |
| SUI/USD | `0x7ceef94f404e660925ea4b33353ff303effaf901f224bdee50df3a714c1299e9` |

Find more at: [https://explorer.switchboard.xyz](https://explorer.switchboard.xyz)

## Troubleshooting

### "Quote Consumer ID not found"
- Check transaction was successful
- Ensure sufficient gas

### "EInvalidQueue"
- Verify you're using the correct queue ID
- Check network (testnet vs mainnet)

### "EQuoteExpired"
- Data is > 10 seconds old
- Fetch fresh data before calling update

### "EPriceDeviationTooHigh"
- Price changed > 10% from last update
- Normal during high volatility
- Adjust `max_deviation_bps` if needed

## Documentation

- 📖 [README.md](./README.md) - Complete documentation
- 🚀 [DEPLOYMENT.md](./DEPLOYMENT.md) - Deployment guide
- 💻 [example.move](./sources/example.move) - Annotated source code

## Support

- 🌐 [Switchboard Docs](https://docs.switchboard.xyz)
- 🐦 [Twitter Updates](https://x.com/switchboardxyz)
- 🐛 [Report Issues](https://github.com/switchboard-xyz/sui/issues)

## Success! 🎉

You now have a working oracle integration with:
- ✅ Verified price feeds
- ✅ Security best practices
- ✅ Production-ready code
- ✅ Multiple validation layers

Ready to build the next generation of DeFi!

