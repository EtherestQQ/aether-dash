# Verification — 19 October 2026

## v1.1 finish correction

Removed the grounded requirement from the existing finish zone. Regression test reproduced a rejected airborne dash before the fix. Test cases: complete-ring dash wins before landing; the same dash with missing rings is rejected; grounded walking still wins. Source and Windows v1.1 are separate deliverables; the original showcase video records v1.0.

Godot 4.7.2 Windows; Compatibility renderer; NVIDIA RTX 3060 Laptop GPU.

- Controller tests: charge consumed once, refill permits another dash, dash exit sheds excess speed, reset cancels momentum and restores charge.
- Course tests: physical landing emits once; incomplete finish rejected; duplicate ring ignored; restart during fade restores ring visibility; time/momentum/progress reset; pause freezes clock; actual Escape input resumes; complete run unlocks finish; restart after finish restores controls.
- Input-only replay: all seven hops land; all seven rings collected; finish at approximately 14.22 seconds. No teleporting, direct ring calls, or velocity overrides in the traversal replay.
- Windows executable: headless startup exit 0; rendered startup movie inspected with character, texture and HUD present; no missing-resource or gameplay errors in final smoke log.
- Source gameplay: captured 1280×720 at 60 fps. Showcase is 45 seconds with title, full input replay and clearly labeled slow-motion excerpts. Raw gameplay video is approximately 17.9 seconds.

One harness limitation: running the audio-heavy course-state test with accelerated `--fixed-fps 60` can print Godot Ogg playback cleanup warnings on immediate shutdown. Run that state test at normal time, as documented; it passes without the warnings. The traversal replay remains fixed-fps and exits cleanly. This is not a claim of testing all hardware or all possible player inputs.

Independent static review found the pause-input and landing-signal bugs; both were reproduced and fixed with regression tests. The owner's playtest accepted the difficulty and identified the airborne-finish issue, fixed in v1.1. No job application was submitted by the development workflow.
