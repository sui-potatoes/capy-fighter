import { TransactionBlock } from "@mysten/sui.js/transactions";
import { getSuiClient, unsafe_getPrivateKey } from "./account";

export async function signAndExecute(email: string, txb: TransactionBlock){
    return getSuiClient().signAndExecuteTransactionBlock({
        transactionBlock: txb,
        signer: unsafe_getPrivateKey(email),
        options: {
            showEffects: true,
            showObjectChanges: true,
            showEvents: true,
        },
    })
}
