import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { fromBase64 as fromB64 } from "@mysten/sui/utils";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

import {  SwitchboardClient, Quote } from "@switchboard-xyz/sui-sdk";

const TESTNET_SUI_RPC = "https://fullnode.testnet.sui.io:443";
const client = new SuiClient({
  url: TESTNET_SUI_RPC,
});

// Get the Switchboard state and log it
const sb = new SwitchboardClient(client);
const state = await sb.fetchState();
console.log("Switchboard state:", state);


let keypair: Ed25519Keypair | null = null;

try {
  const keystorePath = path.join(
    os.homedir(),
    ".sui",
    "sui_config",
    "sui.keystore"
  );
  const keystore = JSON.parse(fs.readFileSync(keystorePath, "utf-8"));

  if (keystore.length < 1) {
    throw new Error("Keystore has fewer than 1 key.");
  }

  const secretKey = fromB64(keystore[0]);
  keypair = Ed25519Keypair.fromSecretKey(secretKey.slice(1));
} catch (error) {
  console.log("Error loading keypair:", error);
}

if (!keypair) {
  throw new Error("Keypair not loaded");
}

const userAddress = keypair.getPublicKey().toSuiAddress();
console.log(`User account ${userAddress} loaded.`);

// Update these with your deployed contract address and queue ID
const exampleAddress =
  "0x73878169b1f35e04e65c5002557a48c7c6ea5e5618fb0c12ffbc485c25023755";
const queueId = state?.oracleQueueId;
if (!queueId) {
  throw new Error("Queue ID not found");
}

console.log("Queue ID:", queueId);

// Create the new transaction
const tx = new Transaction();


// intitialize the quote consumer
tx.moveCall({
  target: `${exampleAddress}::example_2025::create_quote_consumer`,
  arguments: [
    tx.pure.id(queueId),
    tx.pure.u64(300_000), // max_age_ms: 5 minutes
    tx.pure.u64(1000), // max_deviation_bps: 10%
  ],
});

const res = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: tx,
  options: {
    showEffects: true,
    showObjectChanges: true,
    showEvents: true,
  },
});

console.log("Quote Consumer Example response:", res);

// Get the quote consumer id
let quoteConsumerId: string | null = null;
for (const change of res.objectChanges ?? []) {
  if (
    change.type === "created" &&
    change.objectType === `${exampleAddress}::example_2025::QuoteConsumer`
  ) {
    quoteConsumerId = change.objectId;
    console.log("Quote Consumer ID:", quoteConsumerId);
  }
}

if (!quoteConsumerId) {
  throw new Error("Quote Consumer ID not found");
}

// Wait a moment to ensure the object is available
await new Promise(resolve => setTimeout(resolve, 2000));

// ========== Test Update Price ==========
console.log("\n=== Testing update_price ===\n");

// Define the feed hash you want to test with (example: BTC/USD)
// You can use any valid Switchboard feed hash
const feedHash = "0x7418dc6408f5e0eb4724dabd81922ee7b0814a43abc2b30ea7a08222cd1e23ee"; // BTC/USD

const updateTx = new Transaction();

// Fetch the quote update from Crossbar
const quotes = await Quote.fetchUpdateQuote(sb, updateTx, {
  feedHashes: [feedHash]
});

// Call the update_price function on your contract
updateTx.moveCall({
  target: `${exampleAddress}::example_2025::update_price`,
  arguments: [
    updateTx.object(quoteConsumerId), // QuoteConsumer object (shared)
    quotes, // Quotes object from fetchUpdateQuote
    updateTx.pure.vector("u8", Array.from(Buffer.from(feedHash.replace("0x", ""), "hex"))), // feed_hash as vector<u8>
    updateTx.object("0x6"), // Clock object
  ],
});

const updateRes = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: updateTx,
  options: {
    showEffects: true,
    showObjectChanges: true,
    showEvents: true,
  },
});

console.log("Update Price response:", JSON.stringify(updateRes, null, 2));

// Log any events emitted
if (updateRes.events && updateRes.events.length > 0) {
  console.log("\n=== Events Emitted ===");
  for (const event of updateRes.events) {
    console.log(`Event Type: ${event.type}`);
    console.log(`Event Data:`, JSON.stringify(event.parsedJson, null, 2));
  }
}

console.log("\n✅ Script completed successfully!");
