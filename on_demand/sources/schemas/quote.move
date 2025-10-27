module switchboard::quote;

use switchboard::decimal::Decimal;
use sui::table::{Self, Table};
use sui::clock::Clock;


#[error]
const EQuoteNotFound: vector<u8> = b"Quote not found in update";

#[error]
const EInvalidQueue: vector<u8> = b"Invalid queue";

// A quote verifier struct for tracking updates in your own modules
// A simple tool for ensuring that updates come in the correct order
public struct QuoteVerifier has key, store {

    // The id of the quote verifier - can be shared or stored within a struct
    id: UID,

    // Queue that the verifier is on
    queue: ID,

    // The existing quotes for specific feeds
    quotes: Table<vector<u8>, Quote>,
}


// A bundle of quotes
// This tracks individual updates ingested from a set of oracles on a specific queue
public struct Quotes has drop {

    // The quotes in the bundle
    quotes: vector<Quote>,

    // The oracles that signed the quotes
    oracles: vector<ID>,

    // The queue that the oracles are on
    queue_id: ID,
}

// An quote to a feed
public struct Quote has copy, drop, store {

    // The feed id of the quote - equivalent to a feed hash for OracleFeed protos
    feed_id: vector<u8>,

    // The result of the quote
    result: Decimal,

    // The timestamp of the quote
    timestamp_ms: u64,

    // The slot that the quote was created in
    slot: u64,  
}

//===============================
// Constructors
//===============================

// Create a new quote
public(package) fun new(
    feed_id: vector<u8>, 
    result: Decimal, 
    timestamp_ms: u64, 
    slot: u64,
): Quote {
    Quote {
        feed_id,
        result,
        timestamp_ms,
        slot,
    }
}

// Create new bundle of quotes
public(package) fun new_quotes(quotes: vector<Quote>, oracles: vector<ID>, queue_id: ID): Quotes {
    Quotes {
        quotes,
        oracles,
        queue_id,
    }
}

// Create a new quote verifier
// @dev This is the recommended way to create a quote verifier
// @param ctx - The transaction context
// @param queue - The queue that the verifier is on - it is ESSENTIAL that this is set correctly
// @return The new quote verifier
public fun new_verifier(ctx: &mut TxContext, queue: ID): QuoteVerifier {
    let id = object::new(ctx);
    QuoteVerifier {
        id,
        quotes: table::new(ctx),
        queue,
    }
}

// Delete a quote verifier
public fun delete_verifier(verifier: QuoteVerifier) {
    let QuoteVerifier {
        id,
        quotes,
        queue: _,
    } = verifier;
    quotes.drop();
    id.delete();
}


//===============================
// Quote Verifier Accessors
//===============================

// get a quote by feed id
public fun get_quote(verifier: &QuoteVerifier, feed_id: vector<u8>): &Quote {
    table::borrow(&verifier.quotes, feed_id)
}

// quote with feed id exists
public fun quote_exists(verifier: &QuoteVerifier, feed_id: vector<u8>): bool {
    table::contains(&verifier.quotes, feed_id)
}

//===============================
// Quote Verifier Mutators
//===============================

// @dev This is the recommended way to verify quotes
// Verify quotes against existing quotes
// Check timestamps and slots
// If the quote is newer than the existing quote, update the quote
// If the quote is the same age, but slot is newer, update the quote
// If all is the same, or the quote is older, do nothing
// If the timestamp on the quote is in the future, do nothing
public fun verify_quotes(
    verifier: &mut QuoteVerifier, 
    quotes: &Quotes,
    clock: &Clock,
) {
    assert!(quotes.queue_id == verifier.queue, EInvalidQueue);
    let mut i = 0;
    while (i < quotes.quotes.length()) {
        let quote = &quotes.quotes[i];
        if (quote.timestamp_ms > clock.timestamp_ms()) {
            continue
        };
        
        // Check if quote exists first
        if (!verifier.quotes.contains(quote.feed_id)) {
            // First time seeing this feed - just add it
            table::add(&mut verifier.quotes, quote.feed_id, *quote);
        } else {
            // Quote exists - check if we should update it
            let existing_quote = get_quote(verifier, quote.feed_id);

            // If the quote is newer than the existing quote, or has same timestamp but newer slot, update it
            if (quote.timestamp_ms > existing_quote.timestamp_ms || 
                (quote.timestamp_ms == existing_quote.timestamp_ms && quote.slot > existing_quote.slot)) {
                let existing_quote = table::borrow_mut(&mut verifier.quotes, quote.feed_id);
                *existing_quote = *quote;
            };
        };
        i = i + 1;
    };
}


//===============================
// Quote Accessors
//===============================

// Get the feed id of an quote
public fun feed_id(quote: &Quote): vector<u8> {
    quote.feed_id
}

// Get the result of an quote
public fun result(quote: &Quote): Decimal {
    quote.result
}

// Get the timestamp of an quote
public fun timestamp_ms(quote: &Quote): u64 {
    quote.timestamp_ms
}

// Get the slot of an quote
public fun slot(quote: &Quote): u64 {
    quote.slot
}

//===============================
// Quotes Object Accessors
//===============================

// Get an quote by feed_id
public fun get(quotes: &Quotes, feed_id: vector<u8>): Quote {
    let mut result_opt = get_as_option(quotes, feed_id);
    assert!(option::is_some(&result_opt), EQuoteNotFound);
    result_opt.extract()
}

// Get an quote by feed id as an option
public fun get_as_option(quotes: &Quotes, feed_id: vector<u8>): Option<Quote> {
    let mut i = 0;
    while (i < quotes.quotes.length()) {
        let quote = &quotes.quotes[i];
        if (quote.feed_id == feed_id) {
            return option::some(*quote)
        };
        i = i + 1;
    };
    option::none()
}

// Get the queue id of an quotes object
public fun queue_id(quotes: &Quotes): ID {
    quotes.queue_id
}

// Get the oracles of an quotes object
public fun oracles(quotes: &Quotes): vector<ID> {
    quotes.oracles
}

// Get the length of the quotes object
public fun length(quotes: &Quotes): u64 {
    quotes.quotes.length()
}


// Get the quotes of an quotes object
public fun quotes_vec(quotes: &Quotes): vector<Quote> {
    quotes.quotes
}