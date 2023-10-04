import { useEffect, useState } from "react"
import { getSuiClient, unsafe_getConnectedAddress } from "../helpers/account";


export function useBalance() {

    const [balance, setBalance] = useState<number>(0);

    const getBalance = async () => {
        getSuiClient().getBalance({
            owner: unsafe_getConnectedAddress()
        }).then(res => {
            setBalance(Number(res.totalBalance));
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
