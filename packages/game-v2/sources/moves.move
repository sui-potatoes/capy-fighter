// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Tips:
/// 0 = Water
/// 1 = Fire
/// 2 = Grass
/// 3 = Earth
module game::moves {

    /// The maximum number of moves that can be used in a battle.
    const MAX_MOVE_COUNT: u8 = 4;

    /// Total number of moves.
    const TOTAL_MOVES: u8 = 4;

    /// The effectiveness of each element against the others.
    const EFFECTIVENESS: vector<vector<u8>> = vector[
        // Water is effective against Fire (index 1), Earth (index 2),
        // Air (index 3), and neutral against Water (index 0).
        vector[10, 20, 5, 10],
        // Fire is effective against Air (index 3), Water (index 0),
        // Fire (index 1), and neutral against Earth (index 2).
        vector[5, 10, 20, 10],
        // Earth is effective against Water (index 0), Air (index 3),
        // Fire (index 1), and neutral against Earth (index 2).
        vector[20, 5, 10, 10],
        // Air is effective against Earth (index 2), Fire (index 1),
        // Water (index 0), and neutral against Air (index 3).
        vector[10, 5, 10, 20]
    ];

    

}
