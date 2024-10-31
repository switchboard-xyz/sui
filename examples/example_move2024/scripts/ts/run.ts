// sui client upgrade --upgrade-capability 0x75c9afab64928bbb62039f0b4f4bb4437e5312557583c4f3d350affd705cb1ba
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

const suiKeyIdx = parseInt(process.env.SUI_KEY_IDX || "3");

try {
  // Read the keystore file (usually in JSON format)
  const keystorePath = path.join(
    os.homedir(),
    ".sui",
    "sui_config",
    "sui.keystore"
  );
  const keystore = JSON.parse(fs.readFileSync(keystorePath, "utf-8"));

  // Ensure the keystore has at least key
  if (keystore.length < suiKeyIdx + 1) {
    throw new Error(`Keystore has fewer than ${suiKeyIdx + 1} keys.`);
  }

  // Access the 4th key (index 3) and decode from base64
  const secretKey = fromB64(keystore[suiKeyIdx]);
  keypair = Ed25519Keypair.fromSecretKey(secretKey.slice(1)); // Slice to remove the first byte if needed
} catch (error) {
  console.log("Error:", error);
}

if (!keypair) {
  throw new Error("Keypair not loaded");
}

//================================================================================================
// Initialization and Logging
//================================================================================================

// create new user
const userAddress = keypair.getPublicKey().toSuiAddress();

console.log(`User account ${userAddress} loaded.`);

const exampleAddress =
  "0xaff454f567e502d4a0504298e55d1e5215bd15bc1614569e06e3f17884bfe05c";

const aggregatorAddress =
  "0xa12b4dfc7e22f14e6e169171fba765d12e604d7ecbb118b8bc799d387b665bfb";

const tx = new Transaction();

tx.moveCall({
  target: `${exampleAddress}::move2024::example_move2024`,
  arguments: [tx.object(aggregatorAddress)],
});

const res = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: tx,
  options: {
    showEffects: true,
    showObjectChanges: true,
  },
});

console.log("On Demand Example Run Response: ", res);
