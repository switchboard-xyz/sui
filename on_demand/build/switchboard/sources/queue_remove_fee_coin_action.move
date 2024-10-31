module switchboard::queue_remove_fee_coin_action;
 
use sui::coin::Coin;
use sui::event;
use std::type_name::{Self, TypeName};
use switchboard::queue::Queue;

#[error]
const EInvalidAuthority: vector<u8> = b"Invalid authority";

public struct QueueFeeTypeRemoved has copy, drop {
    queue_id: ID,
    fee_type: TypeName,
}

public fun validate(
    queue: &Queue,
    ctx: &mut TxContext
) {
    assert!(queue.has_authority(ctx), EInvalidAuthority);
}

fun actuate<T>(
    queue: &mut Queue,
) {
    queue.remove_fee_type<T>();
    event::emit(QueueFeeTypeRemoved {
        queue_id: queue.id(),
        fee_type: type_name::get<Coin<T>>(),
    });
}

public entry fun run<T>(
    queue: &mut Queue,
    ctx: &mut TxContext
) {   
    validate(
        queue,
        ctx,
    );
    actuate<T>(queue);
}
