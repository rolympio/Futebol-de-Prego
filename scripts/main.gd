extends Control
## Raiz do jogo: fundo animado + troca de telas + pausa ao sair do app.

const SCREENS := {
	"menu": preload("res://scripts/ui/menu_screen.gd"),
	"setup": preload("res://scripts/ui/setup_screen.gd"),
	"match": preload("res://scripts/game/match_screen.gd"),
	"challenges": preload("res://scripts/ui/challenges_screen.gd"),
	"settings": preload("res://scripts/ui/settings_screen.gd"),
	"help": preload("res://scripts/ui/help_screen.gd"),
	"lan": preload("res://scripts/ui/lan_screen.gd"),
}

var current: Control
var current_name := ""
var _bg: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = preload("res://scripts/ui/background.gd").new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	goto("menu")


func goto(screen: String, params := {}) -> void:
	if current:
		current.queue_free()
	var scr: Control = SCREENS[screen].new()
	scr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scr.set("main", self)
	scr.set("params", params)
	current = scr
	current_name = screen
	add_child(scr)
	_bg.visible = screen != "match"
	scr.modulate.a = 0.0
	scr.create_tween().tween_property(scr, "modulate:a", 1.0, 0.2)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if current and current.has_method("on_app_paused"):
				current.on_app_paused()
			Save.save_all()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if current and current.has_method("on_back"):
				current.on_back()
			elif current_name != "menu":
				goto("menu")
			else:
				get_tree().quit()
