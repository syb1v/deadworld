# Server

TypeScript runtime for the Nakama `world` authoritative match.

Implemented through Day 5:

- authoritative movement and shared zombie simulation;
- server-validated combat, magazines, ammo, death and respawn;
- quantity inventory stacks, world loot and versioned containers;
- private versioned Nakama Storage aggregate for player/world persistence;
- rollback on ownership persistence conflicts;
- isolated integration worlds and a full Docker restart test.

Run from the repository root:

```bash
make test
make test-restart
```

`make test-restart` performs two complete Docker Compose teardown/startup cycles and verifies the same account after restart.
