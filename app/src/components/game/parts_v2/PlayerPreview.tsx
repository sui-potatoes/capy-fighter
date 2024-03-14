// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { Player } from "../../../hooks/useUserPlayer";
import { PlayerStatistics } from "../parts/PlayerStatistics";

export function PlayerPreview({ player }: { player: Player | null }) {
  if (!player) return null;

  return (
    <div className="text-left bg-gray-600 text-white rounded-lg p-4 mb-6">
      <div className="flex gap-10 items-center flex-s">
        <div className="flex-shrink-0">
          <h3>Your Player Stats</h3>
          <img src={player.stats.type.icon} />
        </div>
        <div>
          <PlayerStatistics currentPlayer={player.stats} otherPlayer={null} />
        </div>
      </div>
    </div>
  );
}
