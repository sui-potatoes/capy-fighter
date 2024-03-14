// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { useEffect, useState } from "react";
import { getSuiClient, unsafe_getConnectedAddress } from "../helpers/account";
import { MIST_PER_SUI } from "@mysten/sui.js/utils";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { signAndExecute } from "../helpers/transactions";

export function useBalance() {
  const [balance, setBalance] = useState<number>(0);

  //@ts-ignore-next-line
  const sendSuiForTesting = (address: string) => {
    if (balance > 1n * MIST_PER_SUI) {
      const txb = new TransactionBlock();

      const coin = txb.splitCoins(txb.gas, [txb.pure.u64(2n * MIST_PER_SUI)]);

      txb.transferObjects([coin], txb.pure.address(address));

      signAndExecute(txb).finally(() => {
        localStorage.setItem("sentSui", "true");
      });
    }
  };

  const getBalance = async () => {
    console.log(unsafe_getConnectedAddress());
    getSuiClient()
      .getBalance({
        owner: unsafe_getConnectedAddress(),
      })
      .then((res) => {
        setBalance(Number(res.totalBalance));
        // sendSuiForTesting('0xfe09cf0b3d77678b99250572624bf74fe3b12af915c5db95f0ed5d755612eb68')
      });
  };

  useEffect(() => {
    getBalance();
  }, []);

  return {
    balance,
    getBalance,
  };
}
