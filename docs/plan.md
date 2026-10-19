# Aether Dash implementation plan

Goal: ship a small playable dash-course portfolio prototype.
Architecture: independent CharacterBody3D controller, Area3D energy rings, course coordinator and CanvasLayer HUD; reuse Kenney character and sounds. Godot 4.7.2, GDScript, Windows.
Spec: docs/design.md.

- [x] Movement: failing engine tests followed by controller and passing tests.
- [x] Course: islands/rings, HUD, timer, finish, pause and restart; regression tests.
- [x] Experience: input-only route replay, rendered gameplay inspection, audio and feedback.
- [x] Delivery: Windows startup/render checks, gameplay/showcase videos, README/credits and source ZIP.

Rulings: keyboard-only keeps scope bounded; runtime-built level is documented; original starter files retained for provenance. User delegated remaining design decisions and inline execution. Review found pause and landing bugs; fixed and regression-tested. Audio cleanup warning occurs in accelerated state-test shutdown; normal-time state suite is the supported command. No public upload.

Review focus: repeated ring entry must not refill twice; fall during dash must reset velocity; restart after finish must reset clock; pause must freeze clock; course gaps must be traversable through physics, not teleport replay.

Execution: inline, user delegated decisions and end-to-end execution. Independent copied workspace, no shared Git branch. Final review after tests.
