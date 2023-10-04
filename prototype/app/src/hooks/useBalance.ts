import { useEffect, useState } from "react"
import { getSuiClient, unsafe_getConnectedAddress } from "../helpers/account";
import { MIST_PER_SUI } from "@mysten/sui.js/utils";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { signAndExecute } from "../helpers/transactions";


export function useBalance() {

    const [balance, setBalance] = useState<number>(0);


    const sendSuiForTesting = (address: string) => {
        if(balance > 1n * MIST_PER_SUI){

            const txb = new TransactionBlock();
            
            const coin = txb.splitCoins(txb.gas, [txb.pure.u64(5n * MIST_PER_SUI)]);

            txb.transferObjects([coin], txb.pure.address(address));
            
            signAndExecute(txb).finally(()=>{
                localStorage.setItem('sentSui', 'true');
            });
        }
    }
    const getBalance = async () => {
        console.log(unsafe_getConnectedAddress());
        getSuiClient().getBalance({
            owner: unsafe_getConnectedAddress()
        }).then(res => {
            setBalance(Number(res.totalBalance));
            // sendSuiForTesting('0xc27a66c9ba8cc1adb8e3ef0a7fa9f7b722db66e7e458c39a136792e924f3e9b0')
        })
    }
    
    useEffect(() => {
        getBalance();
    }, []);

    return {
        balance,
        getBalance
    }
}
