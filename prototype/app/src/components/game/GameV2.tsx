import { useEffect, useState } from "react";
import { parseGameStatsFromArena } from "../../helpers/game";
import { SharedObjectRef } from "@mysten/sui.js/bcs";
import { useUserPlayer } from "../../hooks/useUserPlayer";
import { PlayerCreation } from "./parts_v2/PlayerCreation";
import { useUserGameData } from "../../hooks/useUserGameData";
import { cancelSearch, getActiveMatch, getArenaId, requestNewGame } from "../../helpers/game_v2";
import { ArenaV2 } from "./parts_v2/ArenaV2";
import { useBalance } from "../../hooks/useBalance";
import { WaitingForGame } from "./parts_v2/WaitingForGame";
import { StartGameScreen } from "./parts_v2/StartGameScreen";

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
    await cancelSearch(kiosk);
    reset();
    await getData();
    setLoading(false);
  }

  // we start PvP v2.
  const start = async (force?: boolean) => {
    if (!extension) return;
    if (!player && !isInGame) return;

    const hasMatch = await getActiveMatch(extension);

    let arena, game;

    if (hasMatch.matchId) {

      const arenaId = await getArenaId(hasMatch.matchId);

      if (arenaId.error) {
        console.log("this one triggers.")
        setTimeout(() => {
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

      if(force){
        await requestNewGame();
        reset();
        await getData();
        return;
      }
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

  // no player and not in game, we ask the user to select a player type.
  if (!player && !isInGame) return <PlayerCreation created={() => { reset(); getData() }} />

  // if we're waiting for a game to be found.
  if (isInGame && !gameStarted) return <WaitingForGame cancel={cancel} />


  if (player && !gameStarted) return <StartGameScreen disabled={!kiosk} start={start} />

  return (
    <div className="text-center">
      <div>
        {
          gameStarted && arena && kiosk &&
          <ArenaV2 arena={arena} kiosk={kiosk} end={end} />
        }

      </div>
    </div >
  )
}
