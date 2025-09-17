extends Control

@onready var texture_rect = $TextureRect

var zoom_level: float = 1.0
const ZOOM_SPEED: float = 0.25
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 8.0


func _ready() -> void:
	self.focus_entered.connect(queue_free)
	texture_rect.pivot_offset = texture_rect.size / 2.0


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
	if event.is_action_pressed("wheel_up"):
		texture_rect.pivot_offset = texture_rect.size / 2.0
		zoom_level = clamp(zoom_level+ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		texture_rect.scale = Vector2(zoom_level, zoom_level)
	elif event.is_action_pressed("wheel_down"):
		texture_rect.pivot_offset = texture_rect.size / 2.0
		zoom_level = clamp(zoom_level-ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		texture_rect.scale = Vector2(zoom_level, zoom_level)


func set_texture(in_texture : Texture2D) -> void:
	texture_rect.texture = in_texture
