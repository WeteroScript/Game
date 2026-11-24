## Точка входа для моделей: каждая модель самоката собирается своим классом
## (G4Model / F3Model) на общей базе ScooterModelBase.
##
## Возвращает словарь: root, front_steer, front_wheel, rear_wheel,
## bar_left, bar_right, foot_left, foot_right.
class_name ScooterModel
extends RefCounted


static func build(spec: ScooterSpec) -> Dictionary:
	if spec.id == "f3":
		return F3Model.new().build_model(spec)
	if spec.id == "g4_test":
		return G4TestModel.new().build_model(spec)
	return G4Model.new().build_model(spec)
