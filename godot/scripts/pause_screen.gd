## Меню паузы: открывается по кнопке МЕНЮ или Esc во время заезда.
## Две кнопки — «ПРОДОЛЖИТЬ» и «В МЕНЮ», ничего лишнего.
class_name PauseScreen
extends CanvasLayer

signal resume_pressed
signal menu_pressed

var root: Control


func _ready() -> void:
	layer = 15
	# Пауза останавливает дерево, поэтому этот слой должен работать всегда.
	process_mode = Node.PROCESS_MODE_ALWAYS

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var backdrop := UiFactory.panel(Color(0.02, 0.03, 0.05, 0.78))
	UiFactory.place(backdrop, 0.0, 0.0, 1280.0, 720.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	var card := UiFactory.panel(Color(0.05, 0.06, 0.09, 0.96))
	UiFactory.place(card, 400.0, 210.0, 480.0, 300.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)

	var title := UiFactory.label("ПАУЗА", 40, Color(1.0, 0.95, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	UiFactory.place(title, 400.0, 240.0, 480.0, 56.0)
	root.add_child(title)

	var resume := UiFactory.primary_button("ПРОДОЛЖИТЬ", 26, Vector2(400.0, 72.0))
	UiFactory.place(resume, 440.0, 320.0, 400.0, 72.0)
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	root.add_child(resume)

	var to_menu := UiFactory.button("В МЕНЮ", 24, Vector2(400.0, 64.0))
	UiFactory.place(to_menu, 440.0, 410.0, 400.0, 64.0)
	to_menu.pressed.connect(func() -> void: menu_pressed.emit())
	root.add_child(to_menu)

	visible = false


## Esc внутри паузы — «Продолжить»: игра на паузе, её ввод не работает.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		resume_pressed.emit()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true


func close() -> void:
	visible = false
