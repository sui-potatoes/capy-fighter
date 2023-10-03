import { SharedObjectRef } from "@mysten/sui.js/bcs"


export type ArenaTitleProps = {
    arena: SharedObjectRef | null
}
export function ArenaTitle({
    arena
}: ArenaTitleProps) {

    return (
        <div className="mb-6">
            <h1>
                Arena Fight
            </h1>
            {/* <input value={arena?.objectId} className="block" disabled/> */}
            <a href={`https://www.suiexplorer.com/object/${arena?.objectId}?network=devnet`} className="text-blue-500"
                target="_blank">
                View on explorer
            </a>
        </div>
    )
}
