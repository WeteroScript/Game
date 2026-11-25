## Экспорт процедурных моделей в GLB без редактора и без рендера:
##   godot --headless --path godot -s res://tools/export_glb.gd
## Сохраняет геометрию, материалы (PBR: albedo/normal/roughness/emission),
## текстуры и иерархию узлов, включая отдельные колёса, узлы подвески,
## рулевую стойку и приборный блок — дальше их можно анимировать в любом DCC.
extends SceneTree

const MODELS := {
	"g4_user": "KuKirin_G4_USER",
	"g4": "KuKirin_G4",
	"f3": "Kugoo_F3_Pro_Max",
}


func _initialize() -> void:
	var out_dir := "res://build/glb"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var ok := 0
	for id in MODELS.keys():
		if _export_one(id, MODELS[id], out_dir):
			ok += 1
	print("GLB DONE %d/%d" % [ok, MODELS.size()])
	quit(0 if ok == MODELS.size() else 1)


func _export_one(id: String, file_name: String, out_dir: String) -> bool:
	var spec := ScooterSpec.get_by_id(id)
	var built := ScooterModel.build(spec)
	var root: Node3D = built["root"]
	root.name = file_name
	root.position = Vector3.ZERO
	get_root().add_child(root)

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err != OK:
		printerr("GLB: не удалось прочитать сцену %s, код %d" % [id, err])
		return false
	var path := "%s/%s.glb" % [out_dir, file_name]
	err = doc.write_to_filesystem(state, path)
	if err != OK:
		printerr("GLB: не удалось записать %s, код %d" % [path, err])
		return false
	var size := FileAccess.get_file_as_bytes(path).size()
	print("GLB %s -> %s (%d байт)" % [id, path, size])
	root.queue_free()
	return true
