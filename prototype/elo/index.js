// Step 1:
// - determine a rating an RD for each player at the onset of the rating period.
// - ...the system constant T which constrains the change in volatility over time,
// needs to be set prior to the application of the system. Reasonable choices are
// in between 0.3 and 1.2
//
// NOTE: 0.3 and 1.2 can be upscaled to 30 and 120 respectively (for BigInt math).
// NOTE: the smaller the T, the less the RD will change over time.
// NOTE: the larger the T, the more the RD will change; sometimes by large amounts.

// > Smaller values of τ prevent the volatility measures from changing by large
// > amounts, which in turn prevent enormous changes in ratings based on very improbable
// > results. If the application of Glicko-2 is expected to involve extremely improbable
// > collections of game outcomes, then τ should be set to a small value, even as small as,
// > say, τ = 0.2.

// (a) if the player is unrated, set the rating to 1500 and the RD to 350. Set the player's
// volatility to 0.06. Otherwise use the player's most recent rating, RD and volatility O.

// Step 2:
// - for each player, convert the rating and RD to Glicko-2's scale:
// ```
// µ = (r − 1500) / 173.7178`
// φ = RD / 173.7178
// ```
//
// NOTE: the rating of a player is mu (µ).
// NOTE: opponent's volatilities are not relevant in calculations.

// Step 3:
// - for each player, determine the quantity `v`. This is the estimated variance of the teams/player's
// rating based only on game outcomes


// Example:
//
// Player ( R: 1500, RD: 200, Vol: 0.06 )
// System Constant = 0.5
// Games:
// - Opponent ( R: 1400, RD: 30,  Vol: 0.06, Result: 1 ) // win
// - Opponent ( R: 1550, RD: 100, Vol: 0.06, Result: 0 ) // loss
// - Opponent ( R: 1700, RD: 300, Vol: 0.06, Result: 0 ) // loss

// Now let's convert it to Glicko-2's scale:
// ```
// µ = (R − 1500) / 173.7178 = 0
// φ = 200 / 173.7178 = 1.1513
// ```
//
// For the opponents (1):
// ```
// µ = (R − 1500) / 173.7178 = -100 / 173.7178 = -0.5756
// φ = 30 / 173.7178 = 0.1727
// ```

// now how do we apply a scaling factor to all of this...

// ...

// Compute:
// ```
// ([(0.9955)^2(0.639)(1 = 0.639) + same for P2 + same ofr P3])^-1 = 1.7785
// ∆ = 1.7785(0.9955(1 − 0.639) + same for P2 + same for P3) = -0.4834
// ```
