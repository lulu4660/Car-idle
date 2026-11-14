## Compile tous les .gdshader du projet (moteur de rendu factice) : une erreur s'affiche
## « SHADER ERROR » juste après le nom du fichier.
##   godot --headless --path . -s tests/compile_shaders.gd
extends SceneTree


func _initialize() -> void:
	var paths := _find("res://", "gdshader")
	for path in paths:
		print("compile ", path)
		var shader := load(path) as Shader
		shader.get_shader_uniform_list()
	print("%d shaders compilés" % paths.size())
	quit(0)


func _find(dir: String, ext: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == ext:
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with(".") and sub != "addons":
			found.append_array(_find(dir.path_join(sub), ext))
	return found
