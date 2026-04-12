extends RefCounted

var m_stream_cache: Dictionary = {}


func get_stream(file_path: String) -> AudioStream:
	if file_path.is_empty():
		return null
	if m_stream_cache.has(file_path):
		return m_stream_cache.get(file_path) as AudioStream
	if !ResourceLoader.exists(file_path):
		return null

	var stream: AudioStream = null
	if file_path.get_extension().to_lower() == "ogg":
		stream = AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(file_path))
	else:
		stream = load(file_path) as AudioStream
	if stream == null:
		return null

	m_stream_cache[file_path] = stream
	return stream
