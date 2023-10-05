import { useState } from "react";
import { TYPES, createPlayer } from "../../../helpers/game_v2";

// A player creation component.
export function PlayerCreation({
    created
}: { created: () => void }) {

    const [creating, setCreating] = useState<boolean>(false);

    const create = async (type: number) => {

        setCreating(true);

        createPlayer(type).then(() => {
            created();
        }).catch(e => {
            console.log(e);
        })
    };

    return (
        <div>
            <h2>Please select your player's type</h2>

            <div className="grid md:grid-cols-4 gap-5 mt-12">
                {
                    TYPES.map((type) => {
                        return <button
                            key={type.name}
                            className="hover:bg-gray-600 hover:text-white"
                            disabled={creating}
                            onClick={() => {
                                create(type.value)
                            }}
                        >
                            <img src={type.icon} className="w-18 mx-auto" />
                            <h3 className="font-bold">{type.name}</h3>
                            <p>{type.description}</p>
                        </button>
                    })
                }
            </div>

        </div>
    )
}
