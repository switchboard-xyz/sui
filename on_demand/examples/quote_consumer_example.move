/// Quote Consumer Example
/// 
/// This Move module demonstrates how to integrate Switchboard quotes into your program.
/// It shows the complete flow from creating a quote verifier to consuming quote data.
/// This is a simple example only to demonstrate the functionality of the quote consumer.

module example::quote_consumer;

use sui::clock::Clock;
use sui::event;
use switchboard::quote::{QuoteVerifier, Quotes};
use switchboard::decimal::{Self, Decimal};

// ========== Error Codes ==========

#[error]
const EInvalidQuote: vector<u8> = b"Invalid quote data";
#[error]
const EQuoteExpired: vector<u8> = b"Quote data is expired";
#[error]
const EPriceDeviationTooHigh: vector<u8> = b"Price deviation exceeds threshold";

// ========== Structs ==========

/// Main program that uses Switchboard quotes
public struct QuoteConsumer has key {
    id: UID,
    quote_verifier: QuoteVerifier,
    last_price: Option<Decimal>,
    last_update_time: u64,
    max_age_ms: u64,
    max_deviation_bps: u64, // basis points (1% = 100 bps)
}

/// Event emitted when price is updated
public struct PriceUpdated has copy, drop {
    feed_hash: vector<u8>,
    old_price: Option<u128>,
    new_price: u128,
    timestamp: u64,
    num_oracles: u64,
}

/// Event emitted when quote validation fails
public struct QuoteValidationFailed has copy, drop {
    feed_hash: vector<u8>,
    reason: vector<u8>,
    timestamp: u64,
}

// ========== Public Functions ==========

/// Initialize the quote consumer with a quote verifier
public fun init_quote_consumer(
    queue: ID,
    max_age_ms: u64,
    max_deviation_bps: u64,
    ctx: &mut TxContext
): QuoteConsumer {
    let verifier = switchboard::quote::new_verifier(ctx, queue);
    
    QuoteConsumer {
        id: object::new(ctx),
        quote_verifier: verifier,
        last_price: option::none(),
        last_update_time: 0,
        max_age_ms,
        max_deviation_bps,
    }
}

/// Create and share a quote consumer
public fun create_quote_consumer(
    queue: ID,
    max_age_ms: u64,
    max_deviation_bps: u64,
    ctx: &mut TxContext
) {
    let consumer = init_quote_consumer(queue, max_age_ms, max_deviation_bps, ctx);
    transfer::share_object(consumer);
}

/// Update price using Switchboard quotes
public fun update_price(
    consumer: &mut QuoteConsumer,
    quotes: Quotes,
    feed_hash: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    // Verify quotes using the quote verifier
   consumer.quote_verifier.verify_quotes(&quotes, clock);
    
    // Check if the feed hash exists in the quotes
    assert!(consumer.quote_verifier.quote_exists(*& feed_hash), EInvalidQuote);

    // Get the specific quote
    let quote = consumer.quote_verifier.get_quote(*& feed_hash);

    // Ensure the timestamp is a maximum of 10 seconds old
    assert!(quote.timestamp_ms() + 10000 > clock.timestamp_ms(), EQuoteExpired);
    
    // Get the price from the quote
    let new_price = quote.result();
    
    // Validate price deviation if we have a previous price
    if (consumer.last_price.is_some()) {
        let last_price = *consumer.last_price.borrow();
        validate_price_deviation(&last_price, &new_price, consumer.max_deviation_bps);
    };
    
    // Store the old price for the event
    let old_price_value = if (consumer.last_price.is_some()) {
        option::some(consumer.last_price.borrow().value())
    } else {
        option::none()
    };
    
    // Update the stored price and timestamp
    consumer.last_price = option::some(new_price);
    consumer.last_update_time = quote.timestamp_ms();
    
    // Emit price update event
    event::emit(PriceUpdated {
        feed_hash,
        old_price: old_price_value,
        new_price: new_price.value(),
        timestamp: quote.timestamp_ms(),
        num_oracles: quotes.oracles().length(),
    });
}

/// Get the current price (if available)
public fun get_current_price(consumer: &QuoteConsumer): Option<Decimal> {
    consumer.last_price
}

/// Get the last update time
public fun get_last_update_time(consumer: &QuoteConsumer): u64 {
    consumer.last_update_time
}

/// Check if the current price is fresh (within max age)
public fun is_price_fresh(consumer: &QuoteConsumer, clock: &Clock): bool {
    if (consumer.last_update_time == 0) {
        return false
    };
    
    let current_time = clock.timestamp_ms();
    current_time - consumer.last_update_time <= consumer.max_age_ms
}

/// Advanced: Update multiple prices in a single transaction
public entry fun update_multiple_prices(
    consumer: &mut QuoteConsumer,
    quotes: Quotes,
    feed_hashes: vector<vector<u8>>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    consumer.quote_verifier.verify_quotes(&quotes, clock);
    let mut i = 0;
    while (i < feed_hashes.length()) {
        let feed_hash = *&feed_hashes[i];
        
        if (consumer.quote_verifier.quote_exists(*& feed_hash)) {
            let quote = consumer.quote_verifier.get_quote(*& feed_hash);
            
            // Validate quote age
            if (quote.timestamp_ms() + 10000 > clock.timestamp_ms()) {
                // Process this quote (simplified for example)
                // In practice, you might store multiple prices or handle them differently
                event::emit(PriceUpdated {
                    feed_hash: copy feed_hash,
                    old_price: option::none(),
                    new_price: quote.result().value(),
                    timestamp: quote.timestamp_ms(),
                    num_oracles: quotes.oracles().length(),
                });
            } else {
                event::emit(QuoteValidationFailed {
                    feed_hash: copy feed_hash,
                    reason: b"Quote expired",
                    timestamp: quote.timestamp_ms(),
                });
            };
        } else {
            event::emit(QuoteValidationFailed {
                feed_hash: copy feed_hash,
                reason: b"Feed not found in quotes",
                timestamp: clock.timestamp_ms(),
            });
        };
        
        i = i + 1;
    };
}

/// Example business logic: Calculate collateral ratio using fresh price
public fun calculate_collateral_ratio(
    consumer: &QuoteConsumer,
    collateral_amount: u64,
    debt_amount: u64,
    clock: &Clock
): u64 {
    // Ensure we have fresh price data
    assert!(is_price_fresh(consumer, clock), EQuoteExpired);
    
    let price = consumer.last_price.borrow();
    let collateral_value = (collateral_amount as u128) * price.value();
    let debt_value = (debt_amount as u128) * 1_000_000_000; // Assuming debt is in base units
    
    // Return collateral ratio as percentage (e.g., 150 = 150%)
    ((collateral_value * 100) / debt_value as u64)
}

/// Example business logic: Check if liquidation is needed
public fun should_liquidate(
    consumer: &QuoteConsumer,
    collateral_amount: u64,
    debt_amount: u64,
    liquidation_threshold: u64, // e.g., 110 = 110%
    clock: &Clock
): bool {
    if (!is_price_fresh(consumer, clock)) {
        return false // Don't liquidate with stale data
    };
    
    let ratio = calculate_collateral_ratio(consumer, collateral_amount, debt_amount, clock);
    ratio < liquidation_threshold
}

// ========== Private Helper Functions ==========

/// Validate that price deviation is within acceptable bounds
fun validate_price_deviation(
    old_price: &Decimal,
    new_price: &Decimal,
    max_deviation_bps: u64
) {
    let old_value = old_price.value();
    let new_value = new_price.value();
    
    // Calculate percentage change in basis points
    let change = if (new_value > old_value) {
        ((new_value - old_value) * 10000) / old_value
    } else {
        ((old_value - new_value) * 10000) / old_value
    };
    
    assert!(change <= (max_deviation_bps as u128), EPriceDeviationTooHigh);
}

// ========== Test Functions ==========

#[test_only]
use sui::test_scenario;

#[test]
fun test_quote_consumer_creation() {
    let mut scenario = test_scenario::begin(@0x1);
    let ctx = test_scenario::ctx(&mut scenario);
    
    let queue_id = object::id_from_address(@0x123);
    let consumer = init_quote_consumer(queue_id, 300_000, 1000, ctx); // 5 min max age, 10% max deviation
    
    assert!(consumer.last_price.is_none(), 0);
    assert!(consumer.last_update_time == 0, 1);
    assert!(consumer.max_age_ms == 300_000, 2);
    assert!(consumer.max_deviation_bps == 1000, 3);
    
    // Clean up
    let QuoteConsumer { id, quote_verifier: _, last_price: _, last_update_time: _, max_age_ms: _, max_deviation_bps: _ } = consumer;
    object::delete(id);
    test_scenario::end(scenario);
}

#[test]
fun test_collateral_ratio_calculation() {
    let mut scenario = test_scenario::begin(@0x1);
    let ctx = test_scenario::ctx(&mut scenario);
    
    let queue_id = object::id_from_address(@0x123);
    let mut consumer = init_quote_consumer(queue_id, 300_000, 1000, ctx);
    
    // Set a mock price (this would normally come from quotes)
    let mock_price = decimal::new(50_000_000_000, false); // $50,000 with 9 decimals
    consumer.last_price = option::some(mock_price);
    consumer.last_update_time = 1000;
    
    // Create a mock clock
    let clock = clock::create_for_testing(ctx);
    clock::set_for_testing(&mut clock, 2000); // 1 second later
    
    // Test collateral ratio calculation
    let ratio = calculate_collateral_ratio(&consumer, 2, 1000, &clock); // 2 units collateral, 1000 debt
    
    // Expected: (2 * 50000) / 1000 * 100 = 10000%
    assert!(ratio == 10000, 0);
    
    // Clean up
    clock::destroy_for_testing(clock);
    let QuoteConsumer { id, quote_verifier: _, last_price: _, last_update_time: _, max_age_ms: _, max_deviation_bps: _ } = consumer;
    object::delete(id);
    test_scenario::end(scenario);
}
