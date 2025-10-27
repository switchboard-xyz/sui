module switchboard::quote_emit_result_action;

use switchboard::quote::{Self, Quotes};
use sui::event;

public struct QuoteVerified has copy, drop {
    timestamp_ms: u64,
    slot: u64,
    feed_id: vector<u8>,
    oracles: vector<ID>,
    queue: ID,
}

public fun run(
    quotes: Quotes,
) {
    let queue = quotes.queue_id();
    let oracles = quotes.oracles();
    let quotes_vec = quotes.quotes_vec();
    
    let mut i = 0;
    while (i < quotes_vec.length()) {
        let quote = &quotes_vec[i];
        event::emit(QuoteVerified {
            timestamp_ms: quote::timestamp_ms(quote),
            slot: quote::slot(quote),
            feed_id: quote::feed_id(quote),
            oracles,
            queue,
        });
        i = i + 1;
    };
}
