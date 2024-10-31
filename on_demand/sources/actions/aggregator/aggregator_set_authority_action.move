module switchboard::aggregator_set_authority_action;
 
use sui::event;
use switchboard::aggregator::Aggregator;

#[error]
const EInvalidAuthority: vector<u8> = b"Invalid authority";

public struct AggregatorAuthorityUpdated has copy, drop {
    aggregator_id: ID,
    existing_authority: address,
    new_authority: address,
}

public fun validate(aggregator: &Aggregator, ctx: &mut TxContext) {
    assert!(aggregator.has_authority(ctx), EInvalidAuthority);
}

fun actuate(aggregator: &mut Aggregator, new_authority: address) {
    let update_event = AggregatorAuthorityUpdated {
        aggregator_id: aggregator.id(),
        existing_authority: aggregator.authority(),
        new_authority: new_authority,
    };
    aggregator.set_authority(new_authority);
    event::emit(update_event);
}

public entry fun run(
    aggregator: &mut Aggregator,
    new_authority: address,
    ctx: &mut TxContext
) {   
    validate(aggregator, ctx);
    actuate(aggregator, new_authority);
}

