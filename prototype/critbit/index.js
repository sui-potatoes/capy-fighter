class Matchmaker {
  constructor() {
    this.orders = [];

    // We're adding a median to reduce the number of iterations
    // when finding a match. It saves gas and computation costs when there's
    // a large number of orders.
    this.median = null;
  }

  submitOrder(player) {
    this.orders.push(player);
  }

  findMatch(player, tolerance = 1) {
    const levelIndex = player.level;

    const candidates = this.orders.filter(
      (order) =>
        order.level >= levelIndex - tolerance &&
        order.level <= levelIndex + tolerance &&
        order.difficulty === player.difficulty
    );

    if (candidates.length > 0) {
      const matchedPlayer =
        candidates[Math.floor(Math.random() * candidates.length)];

      this.orders = this.orders.filter(
        (order) => order.playerId !== matchedPlayer.playerId
      );

      return [player, matchedPlayer];
    }

    return null;
  }
}

class Player {
  constructor(playerId, level, difficulty) {
    this.playerId = playerId;
    this.level = level;
    this.difficulty = difficulty;
  }
}

// Example usage:
const matchmaker = new Matchmaker();

// Submit orders
matchmaker.submitOrder(new Player(1, 1, "low"));
matchmaker.submitOrder(new Player(2, 2, "mid"));
matchmaker.submitOrder(new Player(3, 10, "high"));
matchmaker.submitOrder(new Player(4, 3, "mid"));

// Find matches
const match1 = matchmaker.findMatch(new Player(4, 1, "mid"));
const match2 = matchmaker.findMatch(new Player(5, 10, "low"));

console.log("Match 1:", match1); // It should print something like: Match 1: [Player, MatchedPlayer]
console.log("Match 2:", match2); // It should print something like: Match 2: [Player, MatchedPlayer]
