# Tasks (Move)

1. Registration of Capys
2. Finding a match (matchmaking)
3. The Battle engine
    - The Algorithm
    - Interaction between players (commit-reveal)
    - End of the battle condition
    - Experience + level calculation
4. Account Management
    - wins / losses history
    - cooldown
    - punished for non-competitive behavior

---

Matchmaking:
    - based on player kd / capy level / capy power rating / fullnode (geo)
    - different styles: low / mid / high - risk levels and expectation
    - split into: 3 columns, match 2 by 2

---

1. Loot generation engine - every item has variable stats / range
2.

---

Capy is a in a Kiosk. Before the battle we "lock" the Capy, so the user can't
sell it or take / move anywhere. That gives us an option to ban a player that
abandoned the game because there will always be a transaction to unlock the Capy.

---

Every Player has stored properties: number of wins / loses; we may want to add
the cooldown period. They are stored in the user's Kiosk.

---

Stats are stored on the Capy;



P1: I call a function `place_order(capy_level, capy_id, risk)`
P2: I call a function `place_order(capy_level, capy_id, risk)`
    -> the match happens, event is emitted containing Capy ID
    -> the arena is created for P1 and P2

P2: initialize the arena by submitting the stats
P1: initialize the arena by submitting the stats
    -> the match begins
    -> created in a Kiosk

// low risk is only allowed for Capy LVL > 1
// don't match if the LVL diff is > 5
