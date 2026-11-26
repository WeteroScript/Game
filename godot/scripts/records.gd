## Рекорды заездов: лучший счёт по каждой паре «карта + режим».
##
## Хранится в user://records.cfg — рекорд виден и в меню (в карточке самоката),
## и на экране результатов. Файл читается целиком на запрос: он крошечный,
## а кэш пришлось бы сбрасывать после каждой записи.
class_name Records
extends RefCounted

const PATH := "user://records.cfg"


static func _key(map_id: int, mode_id: int) -> String:
	return "record_%d_%d" % [map_id, mode_id]


## Лучший заезд: {"score", "distance", "time", "crashes"}.
## Пустой словарь — рекорда ещё нет.
static func best(map_id: int, mode_id: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return {}
	var section := _key(map_id, mode_id)
	if not cfg.has_section(section):
		return {}
	return {
		"score": int(cfg.get_value(section, "score", 0)),
		"distance": float(cfg.get_value(section, "distance", 0.0)),
		"time": float(cfg.get_value(section, "time", 0.0)),
		"crashes": int(cfg.get_value(section, "crashes", 0)),
	}


## Записать заезд, если он лучше прежнего. true — это новый рекорд.
static func submit(map_id: int, mode_id: int, score: int, distance: float,
		time: float, crashes: int) -> bool:
	var previous := best(map_id, mode_id)
	if not previous.is_empty() and score <= int(previous["score"]):
		return false
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	var section := _key(map_id, mode_id)
	cfg.set_value(section, "score", score)
	cfg.set_value(section, "distance", distance)
	cfg.set_value(section, "time", time)
	cfg.set_value(section, "crashes", crashes)
	cfg.save(PATH)
	return true


## Строка для меню и результатов.
static func describe(map_id: int, mode_id: int) -> String:
	var entry := best(map_id, mode_id)
	if entry.is_empty():
		return "Рекорда пока нет"
	return "Рекорд: %d очков · %.2f км" % [int(entry["score"]), float(entry["distance"]) / 1000.0]
