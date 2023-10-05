// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { useEffect, useState } from "react";
import { TYPES, getPlayer } from "../helpers/game_v2";
import { KioskExtension } from "./useUserGameData";
import { PlayerStats } from "../helpers/game";

export type Player = {
  bannedUntil: number;
  kioskId: string;
  moveIds: number[];
  rank: string;
  stats: PlayerStats;
};

// Returns the Kiosk of the user + the extension
export function useUserPlayer({
  extension,
}: {
  extension: KioskExtension | null;
}) {
  const [loading, setLoading] = useState<boolean>(true);
  const [player, setPlayer] = useState<any | null>(null);
  const [isInGame, setIsInGame] = useState<boolean>(false);

  const reset = () => {
    setLoading(true);
    setIsInGame(false);
    setPlayer(null);
  };

  const getData = async () => {
    if (!extension) return;
    const player = await getPlayer(extension.storage);
    if (!player.data) {
      setLoading(false);
      return;
    }

    //@ts-ignore-next-line;
    const playerData = player.data.content.fields.value?.fields;

    if (!playerData) {
      setLoading(false);
      setIsInGame(true);
      return;
    }

    const data: Player = {
      bannedUntil: playerData.banned_until,
      kioskId: playerData.kiosk,
      moveIds: playerData.moves,
      rank: playerData.rank,
      stats: playerData.stats.fields,
    };

    data.stats.type = TYPES.find((x) => x.value === data.stats.types[0])!;

    setPlayer(data);
    setLoading(false);
  };

  useEffect(() => {
    getData();
  }, [extension]);

  return {
    loading,
    player,
    isInGame,
    getData,
    reset,
    setLoading,
  };
}
