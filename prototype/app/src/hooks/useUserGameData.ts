import { KioskOwnerCap } from "@mysten/kiosk";
import { useEffect, useState } from "react";
import { getOwnedKiosk } from "../helpers/account";
import { getExtension } from "../helpers/game_v2";

export type KioskExtension = {
    isEnabled: boolean;
    permissions: number;
    storage: string;
}

// Returns the Kiosk of the user + the extension
export function useUserGameData() {

    const [kiosk, setKiosk] = useState<KioskOwnerCap | null>(null);
    const [extension, setExtension] = useState<KioskExtension | null>(null);

    const getData = async () => {
        const kiosk = await getOwnedKiosk();
        setKiosk(kiosk);

        const ext = await getExtension(kiosk.kioskId);
        setExtension(ext);
    }

    useEffect(() => {
        getData();
    }, []);


    return {
        kiosk,
        extension
    }

}
