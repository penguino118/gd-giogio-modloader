extends Node

@onready var mod_list_view = %"Mod List View"
@onready var mod_description_view = %"Mod Description View"

@onready var mod_apply_button: Button = $"TabContainer/Mod Setup/FooterPanel/HBoxContainer/ApplyButton"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mod_list_view.mod_selected.connect(on_mod_selection)
	mod_list_view.request_mod_list.connect(set_mod_list)
	mod_list_view.visibility_changed.connect(set_mod_list)
	mod_apply_button.pressed.connect(on_mod_apply_pressed)
	set_mod_list()


func set_mod_list() -> void:
	Global.init_mod_list()
	mod_list_view.set_list()
	mod_description_view.set_default_description()
	mod_description_view.set_default_preview()


func on_mod_selection(active : bool, row_index : int) -> void:
	var mod : ModData = Global.mod_list[row_index]
	mod.set_if_active(active)
	mod_description_view.set_text(mod.get_author_clean(), mod.get_description_clean())
	mod_description_view.set_preview_from_image(mod.get_preview_image())


func on_mod_apply_pressed() -> void:
	Global.mod_apply_start.emit()
	Global.file_handler.apply_mods()
	Global.save_config()
	Global.mod_apply_end.emit()
