# Day 2 — Shared authoritative zombies

Start only after Day 1 is tested and confirmed.

## Goal

One server-owned zombie type with:

```text
IDLE
CHASE
ATTACK
DEAD
```

## Definition of Done

- both clients see the same zombie IDs/state;
- target selection is server-side;
- position and HP are authoritative;
- attacks are server-side;
- death synchronizes;
- reconnect restores current nearby zombie state.

Do not add inventory/loot/guns in this task unless Day 2 scope is explicitly changed.
