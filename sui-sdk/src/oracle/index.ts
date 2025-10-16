import type {
  CommonOptions,
  MoveObjectFields,
  SwitchboardClient,
} from '../index.js';
import { getFieldsFromObject, ObjectParsingHelper } from '../index.js';

import type { MoveValue } from '@mysten/sui/client';
import type { SuiGraphQLClient } from '@mysten/sui/graphql';
import { graphql } from '@mysten/sui/graphql/schemas/2024.4';
import type { Transaction } from '@mysten/sui/transactions';
import { fromHex, toBase58, toHex } from '@mysten/sui/utils';

export interface OracleInitParams extends CommonOptions {
  oracleKey: string;
  isGuardian?: boolean;
}

export interface OracleAttestParams extends CommonOptions {
  minAttestations: number;
  isGuardian?: boolean;
  solanaRPCUrl?: string;
}
export interface OracleData {
  expirationTime: number;
  id: string;
  mrEnclave: string;
  oracleKey: string;
  queue: string;
  queueKey: string;
  secp256k1Key: string;
  validAttestations: MoveValue[];
}

// Define an interface for GraphQL node content
export interface OracleGraphQLNode {
  asMoveObject: {
    contents: {
      json: MoveObjectFields;
    };
  };
}

export class Oracle {
  constructor(
    readonly client: SwitchboardClient,
    readonly address: string
  ) {}

  /**
   * Create a new Oracle
   */
  public static async initTx(
    client: SwitchboardClient,
    tx: Transaction,
    options: OracleInitParams
  ) {
    const { switchboardAddress, oracleQueueId, guardianQueueId } =
      await client.fetchState(options);
    const queueId = options.isGuardian ? guardianQueueId : oracleQueueId;
    tx.moveCall({
      target: `${switchboardAddress}::oracle_init_action::run`,
      arguments: [
        tx.pure.vector('u8', Array.from(fromHex(options.oracleKey))),
        tx.object(queueId),
      ],
    });
  }

  public static parseOracleData(oracleData: MoveObjectFields): OracleData {
    return {
      expirationTime: ObjectParsingHelper.asNumber(
        oracleData.expiration_time_ms
      ),
      id: ObjectParsingHelper.asId(oracleData.id),
      mrEnclave: toHex(ObjectParsingHelper.asUint8Array(oracleData.mr_enclave)),
      oracleKey: toBase58(
        ObjectParsingHelper.asUint8Array(oracleData.oracle_key)
      ),
      queue: ObjectParsingHelper.asString(oracleData.queue),
      queueKey: toBase58(
        ObjectParsingHelper.asUint8Array(oracleData.queue_key)
      ),
      secp256k1Key: toHex(
        ObjectParsingHelper.asUint8Array(oracleData.secp256k1_key)
      ),
      validAttestations: ObjectParsingHelper.asArray(
        oracleData.valid_attestations
      ),
    };
  }

  /**
   * Get the oracle data object
   */
  public async loadData(): Promise<OracleData> {
    const oracleData = await this.client.client
      .getObject({
        id: this.address,
        options: {
          showContent: true,
          showType: true,
        },
      })
      .then(getFieldsFromObject);

    return Oracle.parseOracleData(oracleData);
  }

  public static async loadAllOracles(
    graphqlClient: SuiGraphQLClient,
    switchboardAddress: string
  ): Promise<OracleData[]> {
    const fetchAggregatorsQuery = graphql(`
      query {
        objects(
          filter: {
            type: "${switchboardAddress}::oracle::Oracle"
          }
        ) {
          nodes {
            address
            digest
            asMoveObject {
              contents {
                json
              }
            }
          }
        }
      }
    `);
    const result = await graphqlClient.query({
      query: fetchAggregatorsQuery,
    });

    const oracleData: OracleData[] = result.data?.objects?.nodes?.map(
      result => {
        const moveObject = result.asMoveObject.contents
          .json as MoveObjectFields;

        // build the data object from moveObject which looks like the above json
        return {
          expirationTime: ObjectParsingHelper.asNumber(
            moveObject.expiration_time_ms
          ),
          id: ObjectParsingHelper.asString(moveObject.id),
          mrEnclave: toHex(
            ObjectParsingHelper.asUint8Array(moveObject.mr_enclave)
          ),
          oracleKey: toBase58(
            ObjectParsingHelper.asUint8Array(moveObject.oracle_key)
          ),
          queue: ObjectParsingHelper.asString(moveObject.queue),
          queueKey: toBase58(
            ObjectParsingHelper.asUint8Array(moveObject.queue_key)
          ),
          secp256k1Key: toHex(
            ObjectParsingHelper.asUint8Array(moveObject.secp256k1_key)
          ),
          validAttestations: ObjectParsingHelper.asArray(
            moveObject.valid_attestations
          ),
        };
      }
    );

    return oracleData;
  }

  public static async loadMany(
    client: SwitchboardClient,
    oracles: string[]
  ): Promise<OracleData[]> {
    const oracleData = await client.client
      .multiGetObjects({
        ids: oracles,
        options: {
          showContent: true,
          showType: true,
        },
      })
      .then(o => o.map(getFieldsFromObject));

    return oracleData.map(o => this.parseOracleData(o));
  }
}
