module switchboard::on_demand;

use std::string;
use sui::package;
use switchboard::queue;

public struct ON_DEMAND has drop {}

public struct State has key {
    id: UID,
    oracle_queue: ID,
    guardian_queue: ID,
    on_demand_package_id: ID,
}

public struct AdminCap has key {
    id: UID,
}

public fun oracle_queue(state: &State): ID {
    state.oracle_queue
}

public fun guardian_queue(state: &State): ID {
    state.guardian_queue
}

fun init(otw: ON_DEMAND, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);
    let guardian_queue = queue::new(

        // Queue key
        x"963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c",

        // Authority
        ctx.sender(),

        // Queue name
        string::utf8(b"Mainnet Guardian Queue"),

        // 0 fee for guardian queues
        0,
        
        // fee_recipient
        ctx.sender(),

        // min_attestations
        3,

        // oracle_validity_length_ms (5 years for fixed guardian queue oracles)
        1000 * 60 * 60 * 24 * 365 * 5,

        // gets ignored
        object::id_from_address(@0x963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c),

        // is_guardian_queue
        true,

        // context
        ctx,
    );

    let oracle_queue = queue::new(

        // Queue key
        x"86807068432f186a147cf0b13a30067d386204ea9d6c8b04743ac2ef010b0752",

        // Authority
        ctx.sender(),

        // name
        string::utf8(b"Mainnet Oracle Queue"),

        // 0 fee for oracle queues
        0,
        
        // fee_recipient
        ctx.sender(),

        // min_attestations
        3,

        // oracle_validity_length_ms (7 days max for oracles)
        1000 * 60 * 60 * 24 * 7,

        // guardian_queue_id
        *&guardian_queue,

        // is_guardian_queue
        false,

        // context
        ctx,
    );

    // Share the state object
    let state = State {
        id: object::new(ctx),
        oracle_queue,
        guardian_queue,
        on_demand_package_id: object::id_from_address(ctx.sender()),
    };

    transfer::share_object(state);
    transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender());
}

public fun on_demand_package_id(state: &State): ID {
    state.on_demand_package_id
}

public(package) fun set_on_demand_package_id(
    state: &mut State,
    on_demand_package_id: ID
) {
    state.on_demand_package_id = on_demand_package_id;
}