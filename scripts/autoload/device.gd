class_name Device
extends RefCounted
## What kind of device the game is on, and the small adjustments that follow:
## a lighter effects profile and haptics on phones, touch-friendly hints.

## Pretend to be a phone (for testing the mobile profile on a desktop).
static var force_mobile := false


## A phone or tablet: a native mobile build, or a browser on Android / iOS.
static func is_mobile() -> bool:
	return force_mobile or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## True when the player is probably using a finger rather than a mouse and keys.
static func uses_touch() -> bool:
	return is_mobile() or DisplayServer.is_touchscreen_available()


## A phone's browser, the slowest place the game runs.
static func is_mobile_web() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_ios")


## Multiplier for particle counts: phones get half, and phone browsers a third, to keep
## 30+ fps.
static func particle_scale() -> float:
	if is_mobile_web():
		return 0.35
	return 0.5 if is_mobile() else 1.0


## Phone browsers draw the game at its own 1280x720 and scale that up to the screen,
## instead of drawing every frame at the phone's full resolution (often 2400x1080 or
## more); it looks nearly the same and costs a fraction. Frames are capped at 60.
static func apply_performance_profile(window: Window) -> void:
	if not is_mobile_web():
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	Engine.max_fps = 60


## A short buzz on phones (if vibration is on in Settings).
static func vibrate(milliseconds: int) -> void:
	if is_mobile() and Save.vibration:
		Input.vibrate_handheld(milliseconds)


## The screen's safe area (avoiding notches and rounded corners) as insets in
## viewport units: [left, top, right, bottom].
static func safe_insets(viewport: Viewport) -> Array[float]:
	var window := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if window.x <= 0 or window.y <= 0 or safe.size.x <= 0 or not is_mobile():
		return [0.0, 0.0, 0.0, 0.0]
	var screen := DisplayServer.screen_get_size()
	var scale := viewport.get_visible_rect().size / Vector2(window)
	var left := maxf(0.0, safe.position.x) * scale.x
	var top := maxf(0.0, safe.position.y) * scale.y
	var right := maxf(0.0, screen.x - safe.end.x) * scale.x
	var bottom := maxf(0.0, screen.y - safe.end.y) * scale.y
	return [left, top, right, bottom]
