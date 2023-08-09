# Arena Computation

Once Capys are placed into the arena, players can start preparing their first
action. Once they're done, both (or one of the players) submit the transaction
to update the state of the Arena (ideally both, as one of the players might lose
the connection).

While usually we'd want to use a reveal-commit scheme, in this case, we try to
reach high speeds of execution and therefore eliminating the cheating aspect in
p2p battles. We will extend the system to support commit-reveal later on as the
game matures.
