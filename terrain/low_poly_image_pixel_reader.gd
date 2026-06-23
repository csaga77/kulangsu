@tool
class_name LowPolyImagePixelReader
extends RefCounted

## Caches an image's RGBA8 byte buffer so terrain sampling can read pixels without the
## per-call overhead of Image.get_pixel. Callers must pass an FORMAT_RGBA8 image.

var data: PackedByteArray
var width: int
var height: int


func _init(image: Image) -> void:
	width = image.get_width()
	height = image.get_height()
	data = image.get_data()


func get_pixel(x: int, y: int) -> Color:
	var index := (y * width + x) * 4
	return Color8(data[index], data[index + 1], data[index + 2], data[index + 3])
