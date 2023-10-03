import { SharedObjectRef } from "@mysten/sui.js/bcs"


export type ArenaTitleProps = {
    arena: SharedObjectRef | null
}
export function ArenaTitle({
    arena
}: ArenaTitleProps) {

    return (
        <div className="mb-6">
            <h3 className="text-3xl">
                Arena Fight
            </h3>
            {/* <input value={arena?.objectId} className="block" disabled/> */}
            <a href={`https://www.suiexplorer.com/object/${arena?.objectId}?network=devnet`} className="text-blue-500 text-lg"
                target="_blank">
                View on explorer
            </a>
        </div>
    )
}
