module switchboard::queue_init_action;

use sui::event;
use std::string::String;
use switchboard::queue::{Self, Queue};

#[error]
const EInvalidOracleValidityLength: vector<u8> = b"Invalid oracle validity length";
#[error]
const EInvalidMinAttestations: vector<u8> = b"Invalid min attestations";

public struct QueueCreated has copy, drop {
    queue_id: ID,
    guardian_queue_id: ID,
    queue_key: vector<u8>,
}

public fun validate(
    min_attestations: u64,
    oracle_validity_length_ms: u64,
) {
    assert!(min_attestations > 0, EInvalidMinAttestations);
    assert!(oracle_validity_length_ms > 0, EInvalidOracleValidityLength);
}

fun actuate(
    queue_key: vector<u8>,
    authority: address,
    name: String,
    fee: u64,
    fee_recipient: address,
    min_attestations: u64,
    oracle_validity_length_ms: u64,
    guardian_queue_id: ID,
    ctx: &mut TxContext
) {
    let queue_id = queue::new(
        queue_key,
        authority,
        name,
        fee,
        fee_recipient,
        min_attestations,
        oracle_validity_length_ms,
        guardian_queue_id,
        false,
        ctx,
    );

    // emit the creation event
    let created_event = QueueCreated {
        queue_id,
        guardian_queue_id: guardian_queue_id,
        queue_key: queue_key,
    };
    event::emit(created_event);
    
}

// initialize aggregator for user
public entry fun run(
    queue_key: vector<u8>,
    authority: address,
    name: String,
    fee: u64,
    fee_recipient: address,
    min_attestations: u64,
    oracle_validity_length_ms: u64,
    guardian_queue: &Queue,
    ctx: &mut TxContext
) {   
    validate(
        min_attestations,
        oracle_validity_length_ms,
    );
    actuate(
        queue_key,
        authority,
        name,
        fee,
        fee_recipient,
        min_attestations,
        oracle_validity_length_ms,
        guardian_queue.id(),
        ctx,
    );
}
