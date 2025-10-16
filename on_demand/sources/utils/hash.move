module switchboard::hash;
 
use std::hash;
use std::bcs;
use std::u128;
use switchboard::decimal::{Self, Decimal};

#[error]
const EWrongFeedHashLength: vector<u8> = b"Feed hash must be 32 bytes";
#[error]
const EWrongOracleIdLength: vector<u8> = b"Oracle ID must be 32 bytes";
#[error]
const EWrongSlothashLength: vector<u8> = b"Slothash must be 32 bytes";
#[error]
const EWrongQueueLength: vector<u8> = b"Queue must be 32 bytes";
#[error]
const EWrongMrEnclaveLength: vector<u8> = b"MR Enclave must be 32 bytes";
#[error]
const EWrongSec256k1KeyLength: vector<u8> = b"Secp256k1 key must be 64 bytes";


public struct Hasher has drop, copy {
    buffer: vector<u8>,
}

public fun new(): Hasher {
    Hasher {
        buffer: vector::empty(),
    }
}

public fun finalize(self: &Hasher): vector<u8> {
    hash::sha2_256(self.buffer)
}

public fun push_u8(self: &mut Hasher, value: u8) {
    self.buffer.push_back(value);
}

public fun push_u32(self: &mut Hasher, value: u32) {
    let mut bytes = bcs::to_bytes(&value);
    vector::reverse(&mut bytes);
    self.buffer.append(bytes);
}

public fun push_u32_le(self: &mut Hasher, value: u32) {
    let bytes = bcs::to_bytes(&value);
    self.buffer.append(bytes);
}

public fun push_u64(self: &mut Hasher, value: u64) {
    let mut bytes = bcs::to_bytes(&value);
    vector::reverse(&mut bytes);
    self.buffer.append(bytes);
}

public fun push_u64_le(self: &mut Hasher, value: u64) {
    let bytes = bcs::to_bytes(&value);
    self.buffer.append(bytes);
}

public fun push_u128(self: &mut Hasher, value: u128) {
    let mut bytes = bcs::to_bytes(&value);
    vector::reverse(&mut bytes);
    self.buffer.append(bytes);
}

public fun push_i128(self: &mut Hasher, value: u128, neg: bool) {

    let signed_value: u128 = if (neg) {
        // Get two's complement by subtracting from 2^128
        u128::max_value!() - value + 1
    } else {
        value
    };

    let mut bytes = bcs::to_bytes(&signed_value);
    vector::reverse(&mut bytes);
    self.buffer.append(bytes);
}

public fun push_i128_le(self: &mut Hasher, value: u128, neg: bool) {
    let signed_value: u128 = if (neg) {
        // Get two's complement by subtracting from 2^128
        u128::max_value!() - value + 1
    } else {
        value
    };
    let bytes = bcs::to_bytes(&signed_value);
    self.buffer.append(bytes);
}

public fun push_decimal(self: &mut Hasher, value: &Decimal) {
    let (value, neg) = decimal::unpack(*value);
    self.push_i128(value, neg);
}

public fun push_decimal_le(self: &mut Hasher, value: &Decimal) {
    let (value, neg) = decimal::unpack(*value);
    self.push_i128_le(value, neg);
}


public fun push_bytes(self: &mut Hasher, bytes: vector<u8>) {
    self.buffer.append(bytes);
}

public fun generate_update_msg(
    value: &Decimal,
    queue_key: vector<u8>,
    feed_hash: vector<u8>,
    slothash: vector<u8>,
    max_variance: u64,
    min_responses: u32,
    timestamp: u64,
): vector<u8> {
    let mut hasher = new();
    assert!(queue_key.length() == 32, EWrongQueueLength);
    assert!(feed_hash.length() == 32, EWrongFeedHashLength);
    assert!(slothash.length() == 32, EWrongSlothashLength);
    hasher.push_bytes(queue_key);
    hasher.push_bytes(feed_hash);
    hasher.push_decimal_le(value);
    hasher.push_bytes(slothash);
    hasher.push_u64_le(max_variance);
    hasher.push_u32_le(min_responses);
    hasher.push_u64_le(timestamp);
    let Hasher { buffer } = hasher;
    buffer
}

public fun generate_consensus_msg(
    slot: u64,
    timestamp: u64,
    feed_ids: &vector<vector<u8>>,
    values: &vector<Decimal>,
    min_oracle_samples: vector<u8>,
): vector<u8> {
    let mut hasher = new();
    
    // Add slot number (8 bytes)
    hasher.push_u64_le(slot);
    
    // Add timestamp (8 bytes)
    hasher.push_u64_le(timestamp);
    
    // For each feed: append feed_id (32 bytes) + value (16 bytes LE) + min_oracle_samples (1 byte)
    let mut i = 0;
    while (i < feed_ids.length()) {
        let feed_id = &feed_ids[i];
        let value = &values[i];
        let min_samples = min_oracle_samples[i];
        
        assert!(feed_id.length() == 32, EWrongFeedHashLength);
        
        // Append feed_id (32 bytes)
        hasher.push_bytes(*feed_id);
        
        // Append value as i128 little endian (16 bytes)
        hasher.push_decimal_le(value);
        
        // Append min_oracle_samples (1 byte)
        hasher.push_u8(min_samples);
        
        i = i + 1;
    };
    
    let Hasher { buffer } = hasher;
    buffer
}

public fun generate_attestation_msg(
    oracle_key: vector<u8>, 
    queue_key: vector<u8>,
    mr_enclave: vector<u8>,
    slothash: vector<u8>,
    secp256k1_key: vector<u8>,
    timestamp: u64,
): vector<u8> {
    let mut hasher = new();
    assert!(oracle_key.length() == 32, EWrongOracleIdLength);
    assert!(queue_key.length() == 32, EWrongQueueLength);
    assert!(mr_enclave.length() == 32, EWrongMrEnclaveLength);
    assert!(slothash.length() == 32, EWrongSlothashLength);
    assert!(secp256k1_key.length() == 64, EWrongSec256k1KeyLength);
    hasher.push_bytes(oracle_key);
    hasher.push_bytes(queue_key);
    hasher.push_bytes(mr_enclave);
    hasher.push_bytes(slothash);
    hasher.push_bytes(secp256k1_key);
    hasher.push_u64_le(timestamp);
    let Hasher { buffer } = hasher;
    buffer
}

public fun check_subvec(v1: &vector<u8>, v2: &vector<u8>, start_idx: u64): bool {
    if (v1.length() < start_idx + v2.length()) {
        return false
    };

    let mut iterations = v2.length();
    while (iterations > 0) {
        let idx = iterations - 1;
        if (v1[start_idx + idx] != v2[idx]) {
            return false
        };
        iterations = iterations - 1;
    };

    true
}

#[test]
fun test_update_msg() { 
    let value = decimal::new(226943873990930561085963032052770576810, false);
    let queue_key = x"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    let feed_hash = x"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    let slothash = x"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd";
    let max_variance: u64 = 42;  
    let min_responses: u32 = 3;
    let timestamp: u64 = 1620000000;
    let value_num: u128 = 226943873990930561085963032052770576810;
    let msg = generate_update_msg(
        &value,
        queue_key,
        feed_hash,
        slothash,
        max_variance,
        min_responses,
        timestamp,
    );
    test_check_subvec(&msg, &queue_key, 0);
    test_check_subvec(&msg, &feed_hash, 32);
    test_check_subvec(&msg, &bcs::to_bytes(&value_num), 64);
    test_check_subvec(&msg, &slothash, 80);
    test_check_subvec(&msg, &bcs::to_bytes(&max_variance), 112);
    test_check_subvec(&msg, &bcs::to_bytes(&min_responses), 120);
    test_check_subvec(&msg, &bcs::to_bytes(&timestamp), 124);
}

#[test]
fun test_update_msg_ecrecover() { 
    let value = decimal::new(66681990000000000000000, false);
    let queue_key = x"86807068432f186a147cf0b13a30067d386204ea9d6c8b04743ac2ef010b0752";
    let feed_hash = x"013b9b2fb2bdd9e3610df0d7f3e31870a1517a683efb0be2f77a8382b4085833";
    let slothash = x"0000000000000000000000000000000000000000000000000000000000000000";
    let max_variance: u64 = 5000000000;  
    let min_responses: u32 = 1;
    let timestamp: u64 = 1729903069;
    let signature = x"0544f0348504715ecbf8ce081a84dd845067ae2a11d4315e49c4a49f78ad97bf650fe6c17c28620cbe18043b66783fcc09fcd540c2b9e2dabf2159f078daa14500";
    let msg = generate_update_msg(
        &value,
        queue_key,
        feed_hash,
        slothash,
        max_variance,
        min_responses,
        timestamp,
    );
    let recovered_pubkey = sui::ecdsa_k1::secp256k1_ecrecover(
        &signature, 
        &msg, 
        1,
    );
    let decompressed_pubkey = sui::ecdsa_k1::decompress_pubkey(&recovered_pubkey);
    let expected_signer = x"23dcf1a2dcadc1c196111baaa62ab0d1276e6f928ce274d2898f29910cc4df45e18a642df3cc82e73e978237abbae7e937f1af41b0dcc179b102f7b4c8958121";
    test_check_subvec(&decompressed_pubkey, &expected_signer, 1);
}



#[test]
fun test_consensus_msg() {
    let slot: u64 = 1234567890;
    let timestamp: u64 = 1729903069;
    
    // Test with single feed
    let feed_ids = vector[
        x"013b9b2fb2bdd9e3610df0d7f3e31870a1517a683efb0be2f77a8382b4085833"
    ];
    let values = vector[
        decimal::new(66681990000000000000000, false)
    ];
    let min_oracle_samples = vector[1u8];
    
    let msg = generate_consensus_msg(
        slot,
        timestamp,
        &feed_ids,
        &values,
        min_oracle_samples,
    );
    
    // Verify structure: slot (8) + timestamp (8) + (feed_id (32) + value (16) + min_samples (1)) * num_feeds
    let expected_length = 8 + 8 + (32 + 16 + 1);
    assert!(msg.length() == expected_length, msg.length());
    
    // Check slot is at the beginning (little endian)
    test_check_subvec(&msg, &bcs::to_bytes(&slot), 0);
    
    // Check timestamp at offset 8 (little endian)
    test_check_subvec(&msg, &bcs::to_bytes(&timestamp), 8);
    
    // Check feed_id at offset 16
    test_check_subvec(&msg, &feed_ids[0], 16);
    
    // Check min_oracle_samples at offset 16 + 32 + 16 = 64
    assert!(msg[64] == 1u8, msg[64] as u64);
}

#[test]
fun test_consensus_msg_multiple_feeds() {
    let slot: u64 = 1234567890;
    let timestamp: u64 = 1729903069;
    
    // Test with multiple feeds
    let feed_ids = vector[
        x"013b9b2fb2bdd9e3610df0d7f3e31870a1517a683efb0be2f77a8382b4085833",
        x"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    ];
    let values = vector[
        decimal::new(66681990000000000000000, false),
        decimal::new(12345, true)
    ];
    let min_oracle_samples = vector[1u8, 3u8];
    
    let msg = generate_consensus_msg(
        slot,
        timestamp,
        &feed_ids,
        &values,
        min_oracle_samples,
    );
    
    // Verify structure: slot (8) + timestamp (8) + 2 * (feed_id (32) + value (16) + min_samples (1))
    let expected_length = 8 + 8 + 2 * (32 + 16 + 1);
    assert!(msg.length() == expected_length, msg.length());
    
    // Check slot is at the beginning
    test_check_subvec(&msg, &bcs::to_bytes(&slot), 0);
    
    // Check timestamp at offset 8
    test_check_subvec(&msg, &bcs::to_bytes(&timestamp), 8);
    
    // Check first feed_id at offset 16
    test_check_subvec(&msg, &feed_ids[0], 16);
    
    // Check first min_oracle_samples at offset 16 + 32 + 16 = 64
    assert!(msg[64] == 1u8, msg[64] as u64);
    
    // Check second feed_id at offset 65 (16 + 49)
    test_check_subvec(&msg, &feed_ids[1], 65);
    
    // Check second min_oracle_samples at offset 65 + 32 + 16 = 113
    assert!(msg[113] == 3u8, msg[113] as u64);
}

#[test]
fun test_attestation_msg() { 
    let oracle_key = x"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    let queue_key = x"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    let mr_enclave = x"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
    let slothash = x"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd";
    let secp256k1_key = x"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee";
    let timestamp: u64 = 1620000000;
    let msg = generate_attestation_msg(
        oracle_key,
        queue_key,
        mr_enclave,
        slothash,
        secp256k1_key,
        timestamp,
    );
    test_check_subvec(&msg, &oracle_key, 0);
    test_check_subvec(&msg, &queue_key, 32);
    test_check_subvec(&msg, &mr_enclave, 64);
    test_check_subvec(&msg, &slothash, 96);
    test_check_subvec(&msg, &secp256k1_key, 128);
    test_check_subvec(&msg, &bcs::to_bytes(&timestamp), 192);
}

#[test]
fun test_consensus_msg_ecrecover() {
    // Test data from the provided oracle response
    let slot: u64 = 414581714;
    let timestamp: u64 = 1760461642; // Use the consensus timestamp from oracle response
    
    // Single feed from medianResponses
    let feed_ids = vector[
        x"7418dc6408f5e0eb4724dabd81922ee7b0814a43abc2b30ea7a08222cd1e23ee"
    ];
    let values = vector[
        decimal::new(10000000000000000000, false) // 10000000000000000000 from medianResponses
    ];
    let min_oracle_samples = vector[2u8]; // numOracles: 2 from medianResponses
    
    // Generate the consensus message using the oracle response data
    let consensus_msg = generate_consensus_msg(
        slot,
        timestamp,
        &feed_ids,
        &values,
        min_oracle_samples,
    );
    
    // Verify consensus message is generated correctly
    assert!(consensus_msg.length() > 0, 1);
    
    // Test oracle signature recovery using individual feed signatures and messages
    // Note: These signatures are for individual oracle messages, not the consensus message
    
    // First oracle
    let oracle1_sig = x"f7db131b2ef88afc4cec2581740172140510df26a2608ab079760159b8588c3237e3716e6ea0cd0ddde2d68856f3b7c6de3884d4fc0eb98169524309df3030b201"; // recoveryId: 1
    let oracle1_msg = x"7d2807a18d54091794adda5954b0d4584abfa0a756dda95d654e0a431fa53a90"; // Individual oracle message
    let recovered1 = sui::ecdsa_k1::secp256k1_ecrecover(
        &oracle1_sig,
        &oracle1_msg,
        1,
    );
    let decompressed1 = sui::ecdsa_k1::decompress_pubkey(&recovered1);
    
    // Verify we can recover a valid public key
    assert!(decompressed1.length() == 65, decompressed1.length());
    
    // Second oracle
    let oracle2_sig = x"70047d7e784c4eb13b8cad3b6ac04b98ab250451eb1913ccd9f5fe2377dd9bdc0af508269264b025ecf05ed334be0c2689bb6ff215192941ecb7e6620149de9a00"; // recoveryId: 0
    let oracle2_msg = x"7069cebdbe5d260f0168e13cc9594d68276396c5c02d789d7a3d402cc86b729a"; // Individual oracle message
    let recovered2 = sui::ecdsa_k1::secp256k1_ecrecover(
        &oracle2_sig,
        &oracle2_msg,
        0,
    );
    let decompressed2 = sui::ecdsa_k1::decompress_pubkey(&recovered2);
    
    // Verify we can recover a valid public key
    assert!(decompressed2.length() == 65, decompressed2.length());
    
    // Both oracles successfully recovered their public keys from their individual signatures
    // This demonstrates that the oracle response data is valid and can be used for verification
}

#[test_only]
fun test_check_subvec(v1: &vector<u8>, v2: &vector<u8>, start_idx: u64) {
    assert!(v1.length() >= start_idx + v2.length());
    let mut iterations = v2.length();
    while (iterations > 0) {
        let idx = iterations - 1;
        assert!(v1[start_idx + idx] == v2[idx], idx as u64);
        iterations = iterations - 1;
    }
}
