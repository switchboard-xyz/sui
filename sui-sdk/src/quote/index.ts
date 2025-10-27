// Third-party imports first, sorted alphabetically by package
// Local imports last
import type { CommonOptions, SwitchboardClient } from '../index.js';
import { getFieldsFromObject, ObjectParsingHelper } from '../index.js';

import type { MoveValue } from '@mysten/sui/client';
import type { Transaction, TransactionResult } from '@mysten/sui/transactions';
import { fromHex, SUI_CLOCK_OBJECT_ID } from '@mysten/sui/utils';
import type { BN } from '@switchboard-xyz/common';
import { CrossbarClient, V2UpdateResponse } from '@switchboard-xyz/common';

export interface QuoteVerifierInitParams extends CommonOptions {
  queue: string;
}

export interface QuoteFetchUpdateParams extends CommonOptions {
  feedHashes: string[];
  crossbarUrl?: string;
  crossbarClient?: CrossbarClient;
  numOracles?: number;
}

export interface QuoteData {
  id: string;
  quotes: Map<string, QuoteEntry>;
  queue: string;
}

export interface QuoteEntry {
  feedHash: string;
  value: BN;
  timestamp: number;
  slot: number;
}

export interface QuoteVerifierMoveFields {
  id: MoveValue;
  quotes: MoveValue;
  queue: MoveValue;
  [key: string]: MoveValue;
}

export interface QuoteUpdateResponse {
  feedHashes: string[];
  values: string[];
  valuesNeg: boolean[];
  minOracleSamples: number[];
  signatures: string[];
  slot: number;
  timestampSeconds: number;
  oracleIds: string[];
  queueId: string;
}

export class Quote {
  constructor(
    readonly client: SwitchboardClient,
    readonly address: string
  ) {}

  /**
   * Create a new Quote Verifier
   * @param client - SuiClient
   * @param tx - Transaction
   * @param options - QuoteVerifierInitParams
   * @constructor
   */
  public static async createVerifierTx(
    client: SwitchboardClient,
    tx: Transaction,
    options: QuoteVerifierInitParams
  ) {
    const { switchboardAddress } = await client.fetchState(options);

    return tx.moveCall({
      target: `${switchboardAddress}::quote::new_verifier`,
      arguments: [tx.pure.id(options.queue)],
    });
  }

  /**
   * Fetch quote update using CrossbarClient v2 update route
   * @param client - SwitchboardClient
   * @param tx - Transaction
   * @param options - QuoteFetchUpdateParams
   * @returns Promise with the move call result - a Quotes object from the move call
   */
  public static async fetchUpdateQuote(
    client: SwitchboardClient,
    tx: Transaction,
    options: QuoteFetchUpdateParams
  ): Promise<TransactionResult> {
    const { switchboardAddress, mainnet, oracleQueueId } =
      await client.fetchState(options);

    // Initialize CrossbarClient
    const crossbarClient =
      options.crossbarClient ??
      new CrossbarClient(
        options.crossbarUrl ?? 'https://crossbar.switchboard.xyz'
      );

    // Fetch v2 update data
    const updateData = await crossbarClient.fetchV2Update(options.feedHashes, {
      chain: 'sui',
      network: mainnet ? 'mainnet' : 'devnet',
      use_timestamp: true,
      num_oracles: options.numOracles,
    });

    // Process the update data
    const processedUpdate = await Quote.processV2UpdateData(updateData);

    // Select the appropriate run function based on oracle count
    const runFunction = Quote.selectRunFunction(
      processedUpdate.oracleIds.length
    );

    // Create oracle arguments for the move call
    const oracleArgs = processedUpdate.oracleIds.map(id => tx.object(id));

    // Build the move call
    return tx.moveCall({
      target: `${switchboardAddress}::quote_submit_action::${runFunction}`,
      arguments: [
        tx.pure.vector(
          'vector<u8>',
          processedUpdate.feedHashes.map(hash => Array.from(fromHex(hash)))
        ),
        tx.pure.vector('u128', processedUpdate.values),
        tx.pure.vector('bool', processedUpdate.valuesNeg),
        tx.pure.vector('u8', processedUpdate.minOracleSamples),
        tx.pure.vector(
          'vector<u8>',
          processedUpdate.signatures.map(sig => Array.from(fromHex(sig)))
        ),
        tx.pure.u64(processedUpdate.slot),
        tx.pure.u64(processedUpdate.timestampSeconds),
        ...oracleArgs,
        tx.object(oracleQueueId),
        tx.object(SUI_CLOCK_OBJECT_ID),
      ],
    });
  }

  /**
   * Process V2 update data into format expected by Move functions
   */
  public static async processV2UpdateData(
    updateData: V2UpdateResponse
  ): Promise<QuoteUpdateResponse> {
    // Build arrays for the Move call
    const feedHashes: string[] = [];
    const values: string[] = [];
    const valuesNeg: boolean[] = [];
    const minOracleSamples: number[] = [];
    const signatures: string[] = [];
    const oracleIds: string[] = [];

    // First, collect all unique feed hashes and their data
    const feedDataMap = new Map<
      string,
      {
        value: string;
        isNegative: boolean;
        minSamples: number;
      }
    >();

    for (const oracleResponse of updateData.oracleResponses) {
      for (const feedResponse of oracleResponse.feedResponses) {
        if (!feedDataMap.has(feedResponse.feed_hash)) {
          feedDataMap.set(feedResponse.feed_hash, {
            value: feedResponse.success_value,
            isNegative: feedResponse.success_value.startsWith('-'),
            minSamples: feedResponse.min_oracle_samples,
          });
        }
      }
    }

    // Convert feed data to arrays
    for (const [feedHash, data] of Array.from(feedDataMap.entries())) {
      feedHashes.push(feedHash);
      values.push(data.value);
      valuesNeg.push(data.isNegative);
      minOracleSamples.push(data.minSamples);
    }

    // Process oracle responses for signatures and IDs
    for (const oracleResponse of updateData.oracleResponses) {
      // Use the oracle ID directly from the response
      oracleIds.push(oracleResponse.oracleId);

      // For Sui chain, oracle-level signatures are already recovery-id appended
      // Convert from hex string to hex (it's already in hex format)
      signatures.push(oracleResponse.signature);
    }

    return {
      feedHashes,
      values,
      valuesNeg,
      minOracleSamples,
      signatures,
      slot: updateData.slot,
      timestampSeconds: updateData.timestamp,
      oracleIds,
      queueId: updateData.queue || '', // Queue ID from top-level response
    };
  }

  /**
   * Select the appropriate run function based on oracle count
   */
  private static selectRunFunction(oracleCount: number): string {
    if (oracleCount < 1 || oracleCount > 6) {
      throw new Error(
        `Invalid oracle count: ${oracleCount}. Must be between 1 and 6.`
      );
    }
    return `run_${oracleCount}`;
  }

  /**
   * Get the quote verifier data object
   */
  public async loadData(): Promise<QuoteData> {
    const quoteData = (await this.client.client
      .getObject({
        id: this.address,
        options: {
          showContent: true,
          showType: false,
        },
      })
      .then(getFieldsFromObject)) as QuoteVerifierMoveFields;

    // Build the data object
    const data: QuoteData = {
      id: ObjectParsingHelper.asId(quoteData.id),
      quotes: new Map(), // TODO: Parse quotes table if needed
      queue: ObjectParsingHelper.asString(quoteData.queue),
    };

    return data;
  }
}

/**
 * Standalone function to fetch quote updates
 * @param client - SwitchboardClient
 * @param feedHashes - Array of feed hashes to fetch
 * @param options - Optional parameters
 * @returns Promise with processed quote update data
 */
export async function fetchQuoteUpdate(
  client: SwitchboardClient,
  feedHashes: string[],
  transaction: Transaction,
  options?: Omit<QuoteFetchUpdateParams, 'feedHashes'>
): Promise<TransactionResult> {
  return Quote.fetchUpdateQuote(client, transaction, {
    feedHashes,
    ...options,
  });
}

/**
 * Emit a quote verified event
 * @param client - SwitchboardClient
 * @param feedHashes - Array of feed hashes to fetch
 * @param transaction - Transaction
 * @param options - Optional parameters
 * @returns Promise with the move call result - a Quotes object from the move call
 */
export async function emitQuoteVerified(
  client: SwitchboardClient,
  feedHashes: string[],
  transaction: Transaction,
  options?: Omit<QuoteFetchUpdateParams, 'feedHashes'>
): Promise<TransactionResult> {
  const { switchboardAddress } = await client.fetchState(options);
  const quotes = await Quote.fetchUpdateQuote(client, transaction, {
    feedHashes,
    ...options,
  });
  return transaction.moveCall({
    target: `${switchboardAddress}::quote_emit_result_action::run`,
    arguments: [quotes],
  });
}
