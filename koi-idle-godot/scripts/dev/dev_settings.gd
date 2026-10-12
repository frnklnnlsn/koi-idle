# dev_settings.gd
# Switches for development. Nothing here affects an exported release build
# except where noted.
class_name DevSettings
extends RefCounted

## Wipe the save every time the game starts. Leave false to keep progress
## between sessions (needed to test offline earnings and pond growth).
const RESET_SAVE_ON_LAUNCH: bool = false

## Developer panel (F1). Only ever available in debug builds (running from the
## editor or a debug export), never in a release export.
const DEV_PANEL: bool = true

static func dev_panel_enabled() -> bool:
	return DEV_PANEL and OS.is_debug_build()
