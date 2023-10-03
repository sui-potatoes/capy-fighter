import { SharedObjectRef } from "@mysten/sui.js/bcs"
import { useState } from "react";


export type ArenaTitleProps = {
    arena: SharedObjectRef | null
}
export function ArenaTitle({ arena }: ArenaTitleProps) {
    const [copied, setCopied] = useState<boolean>(false);

    const copyLink = () => {
        window.navigator.clipboard.writeText(window.location.origin + '/?join=' + arena?.objectId);
    }
    return (
        <div className="mb-6">
            <h2 className="pb-0">Arena Fight
                <a className="text-xl ml-3 cursor-pointer"
                    onClick={() => {
                        setCopied(true);
                        copyLink();
                        setTimeout(() => {
                            setCopied(false);
                        }, 3000)
                    }}>{copied ? 'Copied...' : 'Copy Link'}</a></h2>
            <a href={`https://www.suiexplorer.com/object/${arena?.objectId}?network=devnet`} className="text-blue-500 text-xl"
                target="_blank">
                View on explorer
            </a>
        </div>
    )
}
