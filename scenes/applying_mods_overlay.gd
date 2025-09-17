extends Control


func _ready() -> void:
	Global.mod_apply_start.connect(applying_started)
	Global.mod_apply_end.connect(applying_ended)


func applying_started() -> void:
	show()


func applying_ended() -> void:
	hide()
