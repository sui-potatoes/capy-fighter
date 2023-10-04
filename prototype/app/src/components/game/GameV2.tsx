import { useEffect, useState } from "react";
import { parseGameStatsFromArena } from "../../helpers/game";
import { SharedObjectRef } from "@mysten/sui.js/bcs";
import { useUserPlayer } from "../../hooks/useUserPlayer";
import { PlayerCreation } from "./parts_v2/PlayerCreation";
import { PlayerPreview } from "./parts_v2/PlayerPreview";
import { useUserGameData } from "../../hooks/useUserGameData";
import { cancelSearch, getActiveMatch, getArenaId, requestNewGame } from "../../helpers/game_v2";
import { ArenaV2 } from "./parts_v2/ArenaV2";
import { useBalance } from "../../hooks/useBalance";

// The game options.
export function GameV2() {

  const { balance } = useBalance();

  const { kiosk, extension, } = useUserGameData();
  const { player, isInGame, loading, getData, reset, setLoading } = useUserPlayer({ extension });

  const [gameStarted, setGameStarted] = useState<boolean>(false);

  const [arena, setArena] = useState<SharedObjectRef | null>(null);

  const getArenaData = async (gameId: string) => {
    const game = await parseGameStatsFromArena(gameId, true);

    if (game.playerOne && game.playerTwo
      && (game.playerOne.account !== kiosk?.kioskId)
      && (game.playerTwo.account !== kiosk?.kioskId)
    ) {
      throw new Error("You are not part of this game.");
    }
    return {
      game,
      arena: {
        mutable: true, objectId: gameId, initialSharedVersion: game.initialSharedVersion
      }
    };
  }

  useEffect(() => {

    if (isInGame) {
      start();
    }
  }, [isInGame])


  const cancel = async () => {
    if (!kiosk) return;
    setLoading(true);
    await cancelSearch(kiosk);
    reset();
    await getData();
    setLoading(false);
  }

  // we start PvP v2.
  const start = async () => {
    if (!extension) return;
    // we begin by allowing the user to create a player.
    if (!player && !isInGame) return;

    const hasMatch = await getActiveMatch(extension);

    let arena, game;

    if (hasMatch.matchId) {

      const arenaId = await getArenaId(hasMatch.matchId);

      if (!arenaId){
        setTimeout(()=>{
          start();
        }, 2000);
        return;
      }

      const data = await getArenaData(arenaId);

      console.log(arenaId);

      arena = data.arena;
      game = data.game;
      ///
    } else {

      const game = await requestNewGame();
      reset();
      getData();
      return;
    }

    if (arena) {
      setArena(arena);
      setGameStarted(true);
    }
  }

  const end = () => {
    reset();
    setGameStarted(false);
    setArena(null);

    getData();
  }

  if (balance === 0) return <p>Please use the faucet before you can play the game!</p>;
  if (loading) return <p>Loading....</p>;

  return (
    <div className="py-12 text-center">

      <div>
        {!player && !isInGame && <PlayerCreation />}

        {
          isInGame && !gameStarted && <div>
            <p>
              Waiting for a matching game...
            </p>
            <button className="mt-3"
              onClick={cancel}
            >Cancel search</button>

          </div>
        }
        {
          player &&
          !gameStarted &&
          <div>
            <p>
              Welcome back! Click the following button to automatically find someone to play with.
            </p>
            <div className="grid md:flex gap-5 justify-center py-6">

              <button onClick={() => {
                start();
              }}
                disabled={!kiosk}
              >Find a match</button>
            </div>
          </div>
        }
        {
          gameStarted && arena && kiosk &&
          <ArenaV2 arena={arena} kiosk={kiosk} end={end} />
        }

      </div>
    </div >
  )
}
