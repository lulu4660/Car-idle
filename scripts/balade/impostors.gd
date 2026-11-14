## Imposteurs de la végétation : chaque modèle (pin, palmier, cactus…) est photographié une
## fois au démarrage, de biais (35° au-dessus de l'horizon, l'angle sous lequel la caméra
## drone voit les arbres lointains), en couleur et en normales, dans de petites vues à part
## (256 px). Les images sont recopiées en textures avec mipmaps (pas de scintillement au loin)
## et les vues libérées. Au loin, chaque arbre devient deux triangles tournés vers la caméra
## (`shaders/impostor.gdshader`) qui affichent sa photo, éclairée en jeu par ses normales.
extends Node

const SIZE := 256
const PITCH := 35.0
const CAPTURE := preload("res://shaders/impostor_capture.gdshader")
const SHADER := preload("res://shaders/impostor.gdshader")
const SHADOW := preload("res://shaders/impostor_shadow.gdshader")

## modèle -> ShaderMaterial (textures remplies une fois les photos prises).
var materials := {}
## modèle -> matériau de l'ombre lointaine (la photo couchée au sol).
var shadow_materials := {}
## modèle -> copies des matériaux (une par case, pour le fondu) : elles reçoivent aussi les photos.
var copies := {}
## Texture des hauteurs du terrain (pour poser les ombres sur le relief).
var height_tex: Texture2D
var done := false
var _jobs := []


## `kinds` : modèle -> [maillage, échelle moyenne en jeu]. Les matériaux sont utilisables tout
## de suite (rien n'est dessiné tant que les photos ne sont pas prises).
func prepare(kinds: Dictionary) -> void:
	for kind in kinds:
		var mesh: Mesh = kinds[kind][0]
		var unit: float = kinds[kind][1]
		var b := mesh.get_aabb()
		var c := b.get_center()
		var p := deg_to_rad(PITCH)
		# Hauteur vue de biais et largeur (le modèle tourne : on prend la plus grande).
		var width := maxf(b.size.x, b.size.z)
		var size := maxf(b.size.y * cos(p) + width * sin(p), width) * 1.08
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("quad_size", size)
		mat.set_shader_parameter("center_y", c.y)
		materials[kind] = mat
		copies[kind] = []
		var sm := ShaderMaterial.new()
		sm.shader = SHADOW
		sm.set_shader_parameter("quad_size", size)
		sm.set_shader_parameter("center_y", c.y)
		sm.set_shader_parameter("foot_y", b.position.y)
		sm.set_shader_parameter("height_tex", height_tex)
		shadow_materials[kind] = sm
		var shots := []
		for mode in 2:
			var vp := SubViewport.new()
			vp.size = Vector2i(SIZE, SIZE)
			vp.transparent_bg = true
			vp.own_world_3d = true
			vp.msaa_3d = Viewport.MSAA_4X
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			var cm := ShaderMaterial.new()
			cm.shader = CAPTURE
			cm.set_shader_parameter("mode", mode)
			cm.set_shader_parameter("unit", unit)
			mi.material_override = cm
			vp.add_child(mi)
			var cam := Camera3D.new()
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = size
			cam.near = 0.05
			cam.far = 4.0 * (size + width) + 10.0
			vp.add_child(cam)
			var dist := 2.0 * (size + width) + 5.0
			cam.look_at_from_position(c + Vector3(0.0, sin(p), cos(p)) * dist, c, Vector3.UP)
			add_child(vp)
			shots.append(vp)
		_jobs.append([kind, shots])
	_finish()


## Deux images plus tard, les vues ont été dessinées : on recopie et on libère.
func _finish() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for job in _jobs:
		var mat: ShaderMaterial = materials[job[0]]
		for mode in 2:
			var vp: SubViewport = job[1][mode]
			var img := vp.get_texture().get_image()
			if mode == 0:
				_bleed(img)
			img.generate_mipmaps()
			if OS.has_environment("IMPOSTOR_DUMP"):
				img.save_png("%s/%s_%d.png" % [OS.get_environment("IMPOSTOR_DUMP"), job[0], mode])
			var tex := ImageTexture.create_from_image(img)
			var pname := "albedo_tex" if mode == 0 else "normal_tex"
			mat.set_shader_parameter(pname, tex)
			if mode == 0:
				(shadow_materials[job[0]] as ShaderMaterial).set_shader_parameter(pname, tex)
			for m in copies[job[0]]:
				(m as ShaderMaterial).set_shader_parameter(pname, tex)
			vp.queue_free()
	_jobs.clear()
	done = true


## Les pixels transparents prennent la couleur de leurs voisins visibles : au loin (mipmaps),
## le bord des feuilles ne vire pas au noir.
static func _bleed(img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	img.fix_alpha_edges()
