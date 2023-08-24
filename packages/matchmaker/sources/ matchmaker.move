// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Implements an Orderbook-like system to match players together.
/// We're looking for a match that matches the level and the stats of a Capy.
/// Everyone can submit their Kiosk to the matchmaker, and the matchmaker will
/// try to match them with other players.
module matchmaker::matchmaker {
    use sui::table::Table;

    /// A Hot-Potato object which leads to a match. The opponent finds a match
    /// and delivers the Hot-Potato to the player's Kiosk therefore starting the
    /// match.
    ///
    /// There can be only one match per Kiosk happening at a time.
    struct Match { kiosk: address }

    /// For simplicity, we're making the Matchmaker an object. In the future,
    /// the system can be reworked
    struct Matchmaker has key, store {
        id: UID,
        /// The list of all Kiosks 
        matches: vector<address>
    }
}
