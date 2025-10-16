module switchboard::quote_submit_action;

use sui::clock::Clock;
use sui::ecdsa_k1;
use sui::event;
use switchboard::decimal::{Self, Decimal};
use switchboard::hash;
use switchboard::quote::{Self, Quotes};
use switchboard::oracle::Oracle;
use switchboard::queue::Queue;

#[error]
const EOracleInvalid: vector<u8> = b"Oracle is invalid";
#[error]
const EQueueMismatch: vector<u8> = b"Queue mismatch";
#[error]
const EInvalidLength: vector<u8> = b"Invalid length";

// Utility struct to store relevant oracle data
public struct OracleData has drop {
    secp_key: vector<u8>,
    oracle_id: ID,
}

// Signature invalid event
public struct SignatureInvalid has copy, drop {
    signature: vector<u8>,
    oracle_id: ID,
}

// Run an quote with one oracle
public fun run_1(
    feed_ids: vector<vector<u8>>,
    values: vector<u128>,
    values_neg: vector<bool>,
    min_oracle_samples: vector<u8>,
    signatures: vector<vector<u8>>,
    slot: u64,
    timestamp_seconds: u64,
    oracle_1: &Oracle,
    queue: &Queue,
    clock: &Clock,
): Quotes {

    let mut oracle_data = vector::empty();
    
    // validate oracle on the queue, validate signatures / the updates
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_1, clock);

    // validate the oracle data
    validate(
        feed_ids, 
        values, 
        values_neg, 
        min_oracle_samples, 
        signatures, 
        slot,
        timestamp_seconds, 
        &oracle_data,
        queue.id()
    )
}

// Run an quote with two oracles
public fun run_2(
    feed_ids: vector<vector<u8>>,
    values: vector<u128>,
    values_neg: vector<bool>,
    min_oracle_samples: vector<u8>,
    signatures: vector<vector<u8>>,
    slot: u64,
    timestamp_seconds: u64,
    oracle_1: &Oracle,
    oracle_2: &Oracle,
    queue: &Queue,
    clock: &Clock,
): Quotes {

    let mut oracle_data = vector::empty();

    // validate the oracle data
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_1, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_2, clock);

    // validate the oracle data
    validate(
        feed_ids, 
        values, 
        values_neg, 
        min_oracle_samples, 
        signatures, 
        slot,
        timestamp_seconds, 
        &oracle_data,
        queue.id()
    )
}

// Run an quote with three oracles
public fun run_3(
    feed_ids: vector<vector<u8>>,
    values: vector<u128>,
    values_neg: vector<bool>,
    min_oracle_samples: vector<u8>,
    signatures: vector<vector<u8>>,
    slot: u64,
    timestamp_seconds: u64,
    oracle_1: &Oracle,
    oracle_2: &Oracle,
    oracle_3: &Oracle,
    queue: &Queue,
    clock: &Clock,
): Quotes {
    let mut oracle_data = vector::empty();
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_1, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_2, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_3, clock);
    
    // validate the oracle data
    validate(
        feed_ids, 
        values, 
        values_neg, 
        min_oracle_samples, 
        signatures, 
        slot,
        timestamp_seconds, 
        &oracle_data,
        queue.id()
    )
}

// Run an quote with four oracles
public fun run_4(
    feed_ids: vector<vector<u8>>,
    values: vector<u128>,
    values_neg: vector<bool>,
    min_oracle_samples: vector<u8>,
    signatures: vector<vector<u8>>,
    slot: u64,
    timestamp_seconds: u64,
    oracle_1: &Oracle,
    oracle_2: &Oracle,
    oracle_3: &Oracle,
    oracle_4: &Oracle,
    queue: &Queue,
    clock: &Clock,
): Quotes {
    let mut oracle_data = vector::empty();
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_1, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_2, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_3, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_4, clock);
    
    // validate the oracle data
    validate(
        feed_ids, 
        values, 
        values_neg, 
        min_oracle_samples, 
        signatures, 
        slot,
        timestamp_seconds, 
        &oracle_data,
        queue.id()
    )
}

// Run an quote with five oracles
public fun run_5(
    feed_ids: vector<vector<u8>>,
    values: vector<u128>,
    values_neg: vector<bool>,
    min_oracle_samples: vector<u8>,
    signatures: vector<vector<u8>>,
    slot: u64,
    timestamp_seconds: u64,
    oracle_1: &Oracle,
    oracle_2: &Oracle,
    oracle_3: &Oracle,
    oracle_4: &Oracle,
    oracle_5: &Oracle,
    queue: &Queue,
    clock: &Clock,
): Quotes {
    let mut oracle_data = vector::empty();
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_1, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_2, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_3, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_4, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_5, clock);
    
    // validate the oracle data
    validate(
        feed_ids, 
        values, 
        values_neg, 
        min_oracle_samples, 
        signatures, 
        slot,
        timestamp_seconds, 
        &oracle_data,
        queue.id()
    )
}

// Run an quote with six oracles
public fun run_6(
    feed_ids: vector<vector<u8>>,
    values: vector<u128>,
    values_neg: vector<bool>,
    min_oracle_samples: vector<u8>,
    signatures: vector<vector<u8>>,
    slot: u64,
    timestamp_seconds: u64,
    oracle_1: &Oracle,
    oracle_2: &Oracle,
    oracle_3: &Oracle,
    oracle_4: &Oracle,
    oracle_5: &Oracle,
    oracle_6: &Oracle,
    queue: &Queue,
    clock: &Clock,
): Quotes {
    let mut oracle_data = vector::empty();
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_1, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_2, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_3, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_4, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_5, clock);
    validate_oracle_and_add_secp_key(&mut oracle_data, queue.id(), oracle_6, clock);
    
    // validate the oracle data
    validate(
        feed_ids, 
        values, 
        values_neg, 
        min_oracle_samples, 
        signatures, 
        slot,
        timestamp_seconds, 
        &oracle_data,
        queue.id()
    )
}

// Validate the oracle data and build the quotes
fun validate(
    feed_ids: vector<vector<u8>>,
    values: vector<u128>,
    values_neg: vector<bool>,
    min_oracle_samples: vector<u8>,
    signatures: vector<vector<u8>>,
    slot: u64,
    timestamp_seconds: u64,
    oracle_data: &vector<OracleData>,
    queue_id: ID,
): Quotes {
    let decimals = build_decimals(values, values_neg);
    let consensus_message = hash::generate_consensus_msg(
        slot,
        timestamp_seconds,
        &feed_ids,
        &decimals,
        min_oracle_samples,
    );

    // validate the signatures
    let oracle_ids = validate_signatures(consensus_message, signatures, oracle_data);

    // build the quotes
    build_quotes(
        oracle_ids, 
        feed_ids, 
        decimals, 
        timestamp_seconds, 
        min_oracle_samples, 
        queue_id,
        slot,
    )
}


// Utility function to check oracle queue membership, and add its secp key to the quote
fun validate_oracle_and_add_secp_key(
    oracle_data: &mut vector<OracleData>,
    queue_id: ID,
    oracle: &Oracle,
    clock: &Clock,
) {
    assert!(oracle.queue() == queue_id, EQueueMismatch);
    assert!(oracle.expiration_time_ms() > clock.timestamp_ms(), EOracleInvalid);
    oracle_data.push_back(
        OracleData {
            secp_key: oracle.secp256k1_key(),
            oracle_id: oracle.id(),
        }
    );
}

// Build the decimals vector from the values and values_neg vectors
fun build_decimals(
    values: vector<u128>,
    values_neg: vector<bool>,
): vector<Decimal> {
    assert!(values.length() == values_neg.length(), EInvalidLength);
    let mut decimals = vector::empty();
    let mut i = 0;
    while (i < values.length()) {
        decimals.push_back(decimal::new(values[i], values_neg[i]));
        i = i + 1;
    };
    decimals
}

// Build quotes from oracle data
fun build_quotes(
    oracle_ids: vector<ID>,
    feed_ids: vector<vector<u8>>,
    values: vector<Decimal>,
    timestamp_seconds: u64,
    min_oracle_samples: vector<u8>,
    queue_id: ID,
    slot: u64,
): Quotes {
    assert!(feed_ids.length() == values.length(), EInvalidLength);
    let mut quotes_vec = vector::empty();

    // build the quotes vector
    let mut i = 0;
    while (i < feed_ids.length()) {
        // if the min oracle samples is met, add the quote
        if (min_oracle_samples[i] as u64 <= oracle_ids.length()) {
            quotes_vec.push_back(
                quote::new(
                    feed_ids[i], 
                    values[i], 
                    timestamp_seconds * 1000,
                    slot,
                )
            );
        };
        i = i + 1;
    };

    // Build the quotes bundle
    quote::new_quotes(quotes_vec, oracle_ids, queue_id)
}

// Validate the signatures
fun validate_signatures(
    consensus_message: vector<u8>,
    signatures: vector<vector<u8>>,
    oracle_data: &vector<OracleData>,
): vector<ID> {
    let mut valid_ids = vector::empty();
    let mut i = 0;
    while (i < signatures.length()) {

        // recover the pubkey from the signature
        let recovered_pubkey_compressed = ecdsa_k1::secp256k1_ecrecover(
            &signatures[i], 
            &consensus_message, 
            1,
        );

        // decompress the pubkey
        let recovered_pubkey = ecdsa_k1::decompress_pubkey(&recovered_pubkey_compressed);

        // check that the recovered pubkey is in the oracle data at index i
        if (hash::check_subvec(&recovered_pubkey, &oracle_data[i].secp_key, 1)) {
            valid_ids.push_back(oracle_data[i].oracle_id);
        } else {
            event::emit(SignatureInvalid {
                signature: signatures[i],
                oracle_id: oracle_data[i].oracle_id,
            });
        };
        
        // increment the index
        i = i + 1;
    };

    // return the valid ids
    valid_ids
}

