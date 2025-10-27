import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { fromBase64 as fromB64 } from "@mysten/sui/utils";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

const MAINNET_SUI_RPC = "https://fullnode.mainnet.sui.io:443";
const client = new SuiClient({
  url: MAINNET_SUI_RPC,
});

let keypair: Ed25519Keypair | null = null;

try {
  const keystorePath = path.join(
    os.homedir(),
    ".sui",
    "sui_config",
    "sui.keystore"
  );
  const keystore = JSON.parse(fs.readFileSync(keystorePath, "utf-8"));

  if (keystore.length < 4) {
    throw new Error("Keystore has fewer than 4 keys.");
  }

  const secretKey = fromB64(keystore[3]);
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
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const queueId =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

// Create quote consumer
const tx = new Transaction();

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
  },
});

console.log("Quote Consumer Example response:", res);

