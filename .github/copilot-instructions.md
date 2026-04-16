# Copilot Instructions - MultiplayerPrototype (Godot)

## Project context
- This project uses Godot with GDScript for gameplay and networking logic.
- Multiplayer transport is ENet.
- Prioritize correctness of packet routing and signal flow over refactors.

## Code style
- Keep changes small and localized.
- Follow existing naming and scene/script structure.
- Do not rename packets, signals, or nodes unless explicitly requested.
- Add short comments only when network flow is not obvious.

## Networking rules
- Preserve authoritative flow: host handles player-originated packets and rebroadcasts when needed.
- Validate host/player branches with `GamePacketHandler.is_host` before wiring signals.
- Ensure receive-side signal matches the emitted signal in packet handlers.
- Do not send from client before connection is fully established.
- Keep ENet connection references persistent (avoid local-only connection objects).

## Debugging expectations
- When fixing network bugs, verify:
  1. packet arrives in handler,
  2. correct signal is emitted,
  3. chat/game script is connected to the same signal,
  4. UI/state update happens once per packet.
- Keep temporary logs minimal and remove noisy debug prints after validation.

## Response behavior
- For bug fixes, explain root cause briefly, then show exact file changes.
- If a behavior is ambiguous (host vs player), state assumptions before editing.
