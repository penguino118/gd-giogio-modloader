extends HBoxContainer

@onready var image_preview_scene = preload("uid://ccjodbmxptjtf")
@onready var placeholder_image = preload("uid://cu2mhurfymrck")
@onready var image_rect : TextureRect = %ImageRect
@onready var description_box : RichTextLabel = %DescriptionBox


func _ready() -> void:
	set_default_description()
	set_default_preview()
	image_rect.focus_entered.connect(on_preview_focused)


func set_text(author : String, description : String) -> void:
	if author == "": author = "N/A"
	if description == "": description = "N/A"
	description_box.text = "" # clear textbox
	description_box.append_text( \
		"[b][color=#ebce78]Author[/color]:[/b] %s\n" % [author])
	description_box.append_text( \
		"[b][color=#ebce78]Description[/color]:[/b] %s" % [description])


func set_default_description() -> void:
	set_text("N/A", "N/A")


func set_default_preview() -> void:
	image_rect.texture = placeholder_image
	image_rect.mouse_default_cursor_shape = Control.CURSOR_ARROW


func set_preview_from_image(input_image : Image) -> void:
	if input_image == null or input_image.is_empty(): set_default_preview()
	else: 
		image_rect.texture = ImageTexture.create_from_image(input_image)
		image_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func on_preview_focused() -> void:
	if image_rect.texture == placeholder_image: return
	image_rect.release_focus()
	var scene = image_preview_scene.instantiate()
	get_tree().root.add_child(scene)
	scene.set_texture(image_rect.texture)
