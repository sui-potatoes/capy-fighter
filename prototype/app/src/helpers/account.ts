import { SuiClient, getFullnodeUrl } from "@mysten/sui.js/client";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519"
import {sha256} from "js-sha256";

export function getSuiClient() {
    // create a new SuiClient object pointing to the network you want to use
    return new SuiClient({ url: getFullnodeUrl('devnet') });
}

export function unsafe_getPrivateKey(email?: string){

    const savedState = email || localStorage.getItem('email');
    if(!savedState) throw new Error("needs an email to proceed");
    const hash = sha256(savedState);
    return Ed25519Keypair.deriveKeypairFromSeed(hash);
}

// Gets the connected address.
export function unsafe_getConnectedAddress(email?: string){
    const savedState = email || localStorage.getItem('email');
    if(!savedState) throw new Error("needs an email to proceed");
    return unsafe_getPrivateKey(savedState).toSuiAddress();
}
