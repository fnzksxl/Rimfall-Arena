extends Control

const Rules = preload("res://rules.gd")
const Match = preload("res://match.gd")
const SkillIcon = preload("res://skill_icon.gd")
const CombatView = preload("res://assets/robot/combat_view.gd")
const BASE := Color("#0c1924")
const PANEL := Color("#101f2c")
const TILE := Color("#172a38")
const BORDER := Color("#2d4655")
const TEXT := Color("#edf7f9")
const SUBTLE := Color("#9fb8c5")
const MINT := Color("#79f2db")
const GOLD := Color("#ffcd85")
const AMBER := Color("#ffab85")

var game: Node
var menu_layer: Control
var game_layer: Control
var contact: LineEdit
var nickname: LineEdit
var port: LineEdit
var host_button: Button
var join_button: Button
var practice_button: Button
var mode_options: OptionButton
var cast_options: Array[OptionButton] = []
var bot_options: OptionButton
var menu_status: Label
var sidebar: Panel
var change_button: Button
var team_button: Button
var team_score_badge: Label
var copy_button: Button
var address_options: OptionButton
var mute_button: Button
var menu_mute_button: Button
var sidebar_title: Label
var sidebar_meta: Label
var sidebar_hint: Label
var arena_hint: Label
var gear_hint: Label
var phase_badge: Label
var round_badge: Label
var center_box: Control
var center_title: Label
var center_detail: Label
var character_picker: Panel
var character_buttons: Array[Button] = []
var roster: Array[Label] = []
var shop_rows: Array[Button] = []
var shop_names: Array[Label] = []
var shop_details: Array[Label] = []
var shop_prices: Array[Label] = []
var picker: Panel
var picker_slot := -1
var picker_title: Label
var picker_note: Label
var picker_page := 0
var picker_tabs: Array[Button] = []
const GEAR_PAGE_SIZE := 5
var option_cards: Array[Panel] = []
var option_names: Array[Label] = []
var option_meta: Array[Label] = []
var option_details: Array[Label] = []
var option_actions: Array[Button] = []
var option_icons: Array[Control] = []
var combat_feed: Array[Label] = []
var skill_names: Array[Label] = []
var skill_status: Array[Label] = []
var skill_fill: Array[ColorRect] = []
var skill_tiles: Array[Panel] = []
var self_title: Label
var self_stats: Label
var self_bar: ColorRect
var recap: Panel
var recap_rows: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_menu()
	build_game()


func layer() -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node


func style(color: Color, border: Color, rounding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(rounding)
	box.content_margin_left = 14
	box.content_margin_right = 14
	return box


func position_ui(node: Control, parent: Control, rect: Rect2) -> void:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size


func panel(parent: Control, rect: Rect2, color: Color = PANEL, border: Color = BORDER, rounding := 12) -> Panel:
	var node := Panel.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", style(color, border, rounding))
	position_ui(node, parent, rect)
	return node


func fill(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.color = color
	position_ui(node, parent, rect)
	return node


func label(parent: Control, rect: Rect2, value: String, font_size: int,
	color: Color = TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.text = value
	node.horizontal_alignment = align
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	position_ui(node, parent, rect)
	return node


func button(parent: Control, rect: Rect2, value: String, callback: Callable, primary := false) -> Button:
	var node := Button.new()
	node.text = value
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.add_theme_font_size_override("font_size", 17)
	var color := MINT if primary else TILE
	var edge := MINT if primary else BORDER
	node.add_theme_stylebox_override("normal", style(color, edge, 8))
	node.add_theme_stylebox_override("hover", style(color.lightened(0.14), MINT, 8))
	node.add_theme_stylebox_override("pressed", style(color.darkened(0.18), MINT, 8))
	node.add_theme_stylebox_override("disabled", style(Color("#12212c"), BORDER.darkened(0.3), 8))
	var focus := style(Color.TRANSPARENT, GOLD, 8)
	focus.set_border_width_all(2)
	node.add_theme_stylebox_override("focus", focus)
	for property in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(property, BASE if primary else TEXT)
	node.add_theme_color_override("font_disabled_color", Color("#8fa7b4"))
	node.pressed.connect(callback)
	position_ui(node, parent, rect)
	return node


func entry(parent: Control, rect: Rect2, value: String, hint: String, limit: int) -> LineEdit:
	var node := LineEdit.new()
	node.text = value
	node.placeholder_text = hint
	node.max_length = limit
	node.add_theme_font_size_override("font_size", 18)
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_placeholder_color", SUBTLE)
	node.add_theme_stylebox_override("normal", style(BASE, BORDER, 8))
	node.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, MINT, 8))
	position_ui(node, parent, rect)
	return node


func build_menu() -> void:
	menu_layer = layer()
	var frame := panel(menu_layer, Rect2(62, 103, 522, 710), BASE)
	fill(frame, Rect2(34, 35, 33, 3), MINT)
	label(frame, Rect2(79, 20, 390, 34), "2–6인 생존 PvP", 16, MINT)
	menu_mute_button = button(frame, Rect2(362, 18, 122, 38), "소리 켜짐", func(): game.toggle_audio())
	label(frame, Rect2(32, 67, 452, 79), "RIMFALL", 67)
	label(frame, Rect2(35, 133, 442, 56), "ARENA", 45, MINT)
	label(frame, Rect2(38, 197, 446, 28), "상대를 밀어내고 마지막까지 살아남으세요.", 19, SUBTLE)
	fill(frame, Rect2(38, 252, 446, 1), BORDER)
	label(frame, Rect2(38, 273, 324, 24), "닉네임", 15, SUBTLE)
	label(frame, Rect2(382, 273, 102, 24), "UDP 포트", 15, SUBTLE)
	nickname = entry(frame, Rect2(38, 302, 327, 49), "", "플레이어 이름", 16)
	port = entry(frame, Rect2(382, 302, 102, 49), "7410", "7410", 5)
	mode_options = selector(frame, Rect2(38, 364, 156, 50), "방과 연습전의 경기 방식")
	mode_options.add_item("개인전", Match.FREE_FOR_ALL)
	mode_options.add_item("팀전", Match.TEAM_MATCH)
	mode_options.item_selected.connect(update_bot_options)
	host_button = button(frame, Rect2(208, 364, 276, 50), "친구 방 만들기", func():
		game.host_game(nickname.text, port.text, mode_options.get_selected_id()), true)
	label(frame, Rect2(38, 430, 446, 24), "친구 방에 참가할 때 입력", 15, SUBTLE)
	contact = entry(frame, Rect2(38, 459, 318, 49), "", "호스트 IP 주소", 70)
	join_button = button(frame, Rect2(368, 459, 116, 49), "방 참가", join_room)
	contact.text_submitted.connect(func(_value: String): join_room())
	bot_options = selector(frame, Rect2(38, 546, 156, 48), "연습전 스파링 봇 수")
	practice_button = button(frame, Rect2(208, 546, 276, 48), "봇과 연습", func():
		game.practice(nickname.text, bot_options.get_selected_id(), mode_options.get_selected_id()))
	update_bot_options(mode_options.selected)
	label(frame, Rect2(38, 609, 102, 40), "스킬 조작", 15, SUBTLE)
	add_cast_mode(frame, Rect2(144, 609, 340, 40))
	menu_status = label(frame, Rect2(38, 657, 446, 35), "", 15, AMBER)
	label(menu_layer, Rect2(65, 827, 565, 34), "WASD 이동  ·  마우스 조준  ·  좌클릭 / Q / E / R / F / Space", 16, SUBTLE)


func add_cast_mode(parent: Control, rect: Rect2) -> void:
	var control := selector(parent, rect, "공격 스킬 조작")
	control.add_item("즉시 입력")
	control.add_item("궤적 표시")
	control.select(int(game.preview_casts))
	control.tooltip_text = "궤적 표시에서는 Q·E·R을 누르고, 전장에 좌클릭하면 선택한 스킬을 시전합니다. Esc로 취소합니다."
	control.item_selected.connect(func(mode: int): game.set_cast_mode(mode))
	cast_options.append(control)


func update_cast_mode(mode: int) -> void:
	for control in cast_options:
		control.select(mode)


func selector(parent: Control, rect: Rect2, accessible: String) -> OptionButton:
	var control := OptionButton.new()
	control.accessibility_name = accessible
	control.add_theme_stylebox_override("normal", style(BASE, BORDER, 8))
	control.add_theme_stylebox_override("hover", style(TILE, MINT, 8))
	control.add_theme_stylebox_override("pressed", style(TILE, MINT, 8))
	control.add_theme_font_size_override("font_size", 15)
	position_ui(control, parent, rect)
	return control


func update_bot_options(_index: int) -> void:
	var teams := mode_options.get_selected_id() == Match.TEAM_MATCH
	bot_options.clear()
	for count in range(1, Rules.CAPACITY, 2 if teams else 1):
		var size := (count + 1) / 2
		bot_options.add_item("봇 %d · %d 대 %d" % [count, size, size] if teams else "봇 %d마리" % count, count)
	bot_options.select(1 if teams else 0)
	host_button.text = "팀전 방 만들기" if teams else "개인전 방 만들기"
	practice_button.text = "봇과 팀전 연습" if teams else "봇과 개인전 연습"


func join_room() -> void:
	if not join_button.disabled:
		game.join_game(nickname.text, contact.text, port.text)


func build_game() -> void:
	game_layer = layer()
	var header := panel(game_layer, Rect2(28, 24, 1384, 69), BASE)
	fill(header, Rect2(20, 21, 3, 28), MINT)
	label(header, Rect2(36, 15, 288, 41), "RIMFALL ARENA", 25)
	round_badge = label(header, Rect2(322, 16, 240, 38), "", 18, MINT)
	add_cast_mode(header, Rect2(524, 14, 118, 40))
	phase_badge = label(header, Rect2(648, 12, 292, 45), "", 22, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	team_score_badge = label(header, Rect2(946, 15, 155, 39), "", 16, SUBTLE, HORIZONTAL_ALIGNMENT_CENTER)
	mute_button = button(header, Rect2(1116, 14, 116, 40), "소리 켜짐", func(): game.toggle_audio())
	button(header, Rect2(1244, 14, 120, 40), "방 나가기", func(): game.leave_game())

	arena_hint = label(game_layer, Rect2(46, 119, 960, 24), "", 15, SUBTLE)
	gear_hint = label(game_layer, Rect2(46, 145, 500, 24), "", 14, Rules.SLOTS[Rules.GEAR].color)
	sidebar = panel(game_layer, Rect2(1046, 111, 366, 650))
	sidebar_title = label(sidebar, Rect2(21, 15, 322, 39), "", 24)
	sidebar_meta = label(sidebar, Rect2(22, 56, 322, 26), "", 16, GOLD)
	fill(sidebar, Rect2(21, 94, 324, 1), BORDER)
	sidebar_hint = label(sidebar, Rect2(21, 541, 324, 25), "", 14, SUBTLE)
	change_button = button(sidebar, Rect2(21, 574, 324, 52), "", func(): game.primary_action(), true)
	team_button = button(sidebar, Rect2(21, 377, 324, 44), "", func(): game.switch_team())
	copy_button = button(sidebar, Rect2(235, 490, 110, 44), "주소 복사", func(): game.copy_address(address_options.selected))
	address_options = selector(sidebar, Rect2(21, 490, 204, 44), "호스트 주소")
	for index in range(Rules.CAPACITY):
		var line := label(sidebar, Rect2(23, 108 + index * 40, 317, 34), "", 17)
		roster.append(line)
	for index in range(4):
		var line := label(game_layer, Rect2(1045, 115 + index * 29, 347, 26), "", 15, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		line.add_theme_color_override("font_shadow_color", BASE)
		line.add_theme_constant_override("shadow_offset_y", 2)
		combat_feed.append(line)
	for slot in range(Rules.SLOTS.size()):
		var data: Dictionary = Rules.SLOTS[slot]
		var y := 106 + slot * 58
		var row := button(sidebar, Rect2(19, y, 328, 52), "", func(): open_shop_slot(slot))
		var keycap := panel(row, Rect2(12, 10, 52, 32), BASE, BORDER, 6)
		var badge: String = "ITEM" if slot == Rules.GEAR else data.key
		label(keycap, Rect2(1, 0, 50, 32), badge, 13, data.color, HORIZONTAL_ALIGNMENT_CENTER)
		shop_rows.append(row)
		shop_names.append(label(row, Rect2(76, 13, 155, 26), "", 17))
		shop_details.append(label(row, Rect2(76, 27, 155, 20), "", 13, SUBTLE))
		shop_prices.append(label(row, Rect2(238, 0, 76, 52), "", 14, GOLD, HORIZONTAL_ALIGNMENT_RIGHT))

	var bottom := panel(game_layer, Rect2(28, 779, 1384, 93), BASE)
	self_title = label(bottom, Rect2(18, 11, 215, 27), "", 19, MINT)
	self_stats = label(bottom, Rect2(18, 40, 256, 23), "", 15, SUBTLE)
	fill(bottom, Rect2(18, 71, 233, 4), BORDER)
	self_bar = fill(bottom, Rect2(18, 71, 233, 4), MINT)
	for slot in range(Rules.ACTIVE_SLOTS):
		var data: Dictionary = Rules.SLOTS[slot]
		var tile := panel(bottom, Rect2(260 + slot * 185, 11, 174, 70), TILE, BORDER, 7)
		tile.mouse_filter = Control.MOUSE_FILTER_PASS
		skill_tiles.append(tile)
		var keycap := panel(tile, Rect2(9, 12, 49, 43), BASE, BORDER, 6)
		label(keycap, Rect2(1, 0, 47, 43), data.key, 14, data.color, HORIZONTAL_ALIGNMENT_CENTER)
		skill_names.append(label(tile, Rect2(66, 9, 101, 25), "", 15))
		skill_status.append(label(tile, Rect2(66, 35, 101, 21), "", 14, SUBTLE))
		skill_fill.append(fill(tile, Rect2(3, 66, 168, 2), data.color))

	center_box = panel(game_layer, Rect2(293, 645, 470, 93), Color(BASE, 0.94), BORDER, 9)
	center_title = label(center_box, Rect2(12, 9, 446, 40), "", 26, MINT, HORIZONTAL_ALIGNMENT_CENTER)
	center_detail = label(center_box, Rect2(12, 49, 446, 29), "", 16, SUBTLE, HORIZONTAL_ALIGNMENT_CENTER)
	build_character_picker()
	recap = panel(game_layer, Rect2(44, 164, 272, 261), Color(BASE, 0.95))
	label(recap, Rect2(16, 10, 242, 28), "직전 라운드 보상", 17)
	label(recap, Rect2(16, 40, 242, 22), "순위 · 이름              킬 / 피해 / 골드", 13, SUBTLE)
	fill(recap, Rect2(16, 67, 240, 1), BORDER)
	for index in range(Rules.CAPACITY):
		recap_rows.append(label(recap, Rect2(16, 72 + index * 28, 240, 27), "", 14, GOLD))
	build_picker()


func build_character_picker() -> void:
	character_picker = panel(game_layer, Rect2(118, 178, 844, 444), BASE)
	character_picker.hide()
	label(character_picker, Rect2(24, 16, 796, 38), "캐릭터 선택", 25)
	for choice in range(Rules.CHARACTER_NAMES.size()):
		var column := choice % 3
		@warning_ignore("integer_division")
		var row := choice / 3
		var card := panel(character_picker, Rect2(24 + column * 268, 65 + row * 180, 260, 172), TILE)
		if DisplayServer.get_name() != "headless":
			var preview := CombatView.new()
			preview.variant = choice
			card.add_child(preview)
			preview.size = Vector2i(192, 192)
			preview.camera.position = Vector3(2.0, 1.75, 3.8)
			preview.camera.look_at(Vector3(0, 0.94, 0))
			preview.camera.size = 2.15
			preview.robot.pose_walk(0.0, 0.0, 0.0)
			var portrait := TextureRect.new()
			portrait.texture = preview.get_texture()
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			position_ui(portrait, card, Rect2(66, 3, 128, 128))
		var select_button := button(card, Rect2(8, 128, 244, 36), Rules.CHARACTER_NAMES[choice],
			func(): game.select_character(choice))
		select_button.add_theme_stylebox_override("disabled", style(Color("#183135"), MINT, 8))
		select_button.add_theme_color_override("font_disabled_color", MINT)
		character_buttons.append(select_button)


func build_picker() -> void:
	picker = panel(game_layer, Rect2(100, 134, 925, 526), BASE)
	picker_title = label(picker, Rect2(23, 16, 543, 36), "", 24)
	button(picker, Rect2(827, 16, 75, 44), "닫기", close_picker)
	picker_note = label(picker, Rect2(24, 55, 780, 25), "", 15, SUBTLE)
	for page in range(2):
		var tab := button(picker, Rect2(565 + page * 130, 16, 120, 44), "", func(): picker_page = page)
		tab.add_theme_stylebox_override("disabled", style(Color("#183135"), MINT, 8))
		tab.add_theme_color_override("font_disabled_color", MINT)
		picker_tabs.append(tab)
	for index in range(Rules.MAX_CHOICES):
		var card := panel(picker, Rect2(22 + (index % 3) * 296, 92 + (index / 3) * 211, 286, 200), TILE, BORDER, 8)
		option_cards.append(card)
		var emblem := panel(card, Rect2(16, 16, 48, 48), BASE, BORDER, 7)
		var icon := SkillIcon.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		position_ui(icon, emblem, Rect2(0, 0, 48, 48))
		option_icons.append(icon)
		option_names.append(label(card, Rect2(77, 14, 193, 27), "", 20))
		option_meta.append(label(card, Rect2(77, 44, 193, 20), "", 14, SUBTLE))
		var detail := label(card, Rect2(16, 79, 254, 53), "", 15, SUBTLE)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		detail.max_lines_visible = 2
		option_details.append(detail)
		option_actions.append(button(card, Rect2(16, 141, 254, 44), "", func(): choose_option(index), true))
	picker.hide()


func open_shop_slot(slot: int) -> void:
	if Rules.SLOTS[slot].options.size() == 1:
		close_picker()
		game.buy_slot(slot)
	else:
		var local: Dictionary = game.state.players.get(game.own_id, {})
		picker_page = 0 if slot == Rules.GEAR else int(local.get("choices", Rules.BASE_CHOICES)[slot]) / Rules.MAX_CHOICES
		picker_slot = slot


func choose_option(card_index: int) -> void:
	if picker_slot >= 0 and option_cards[card_index].visible and not option_actions[card_index].disabled:
		var choice: int = option_actions[card_index].get_meta("choice", -1)
		if choice < 0:
			return
		var local: Dictionary = game.state.players.get(game.own_id, {})
		if picker_slot == Rules.GEAR and choice in local.get("equipment", []):
			game.sell_gear(choice)
		else:
			game.buy_slot(picker_slot, choice)
		if picker_slot != Rules.GEAR:
			close_picker()


func close_picker() -> void:
	picker_slot = -1
	picker.hide()


func update_picker(phase: int, local: Dictionary) -> void:
	if phase != Match.SHOP or local.is_empty() or local.ready:
		close_picker()
		return
	picker.visible = picker_slot >= 0
	if not picker.visible:
		return
	var slot: Dictionary = Rules.SLOTS[picker_slot]
	var gear := picker_slot == Rules.GEAR
	var level: int = 0 if gear else local.levels[picker_slot]
	var selected: int = 0 if gear else local.choices[picker_slot]
	var page_size := GEAR_PAGE_SIZE if gear else Rules.MAX_CHOICES
	var start := picker_page * page_size
	var count := mini(page_size, slot.options.size() - start)
	for page in range(picker_tabs.size()):
		picker_tabs[page].visible = slot.options.size() > page_size
		picker_tabs[page].disabled = page == picker_page
		picker_tabs[page].text = ["기동·장외", "방어·회복"][page] if gear else ("%d / %d 페이지" % [page + 1, picker_tabs.size()])
	picker_title.text = "장비 상점" if gear else "%s  ·  %s" % [slot.key, slot.name]
	picker_title.add_theme_color_override("font_color", slot.color)
	picker_note.text = "%d/%d개 장착  ·  판매 시 구매가의 절반 반환" % [local.equipment.size(), Rules.EQUIPMENT_CAP] if gear else (
		"후보 하나를 고르세요. 선택은 경기 종료까지 유지됩니다." if level == 0 else "이번 경기에서는 장착한 스킬을 강화할 수 있습니다.")
	for index in range(option_cards.size()):
		option_cards[index].visible = index < count
		if index >= count:
			continue
		var choice := start + index
		var data: Dictionary = slot.options[choice]
		var equipped: bool = choice in local.equipment if gear else level > 0 and choice == selected
		var action := option_actions[index]
		action.set_meta("choice", choice)
		var cost := Rules.price(picker_slot, level, choice)
		option_icons[index].show_skill(data.id, slot.color)
		option_names[index].text = data.name
		option_names[index].add_theme_color_override("font_color", slot.color if equipped else TEXT)
		option_details[index].text = data.help
		if gear:
			option_meta[index].text = "장착 중" if equipped else ""
			var full: bool = local.equipment.size() >= Rules.EQUIPMENT_CAP
			action.text = "판매 +%d G" % Rules.resale(choice) if equipped else ("장비 칸 가득 참" if full else "구매 %d G" % cost)
			action.disabled = not equipped and (full or local.gold < cost)
			action.tooltip_text = data.help
			continue
		var maxed := equipped and level >= Rules.level_cap(picker_slot)
		var locked := level > 0 and not equipped
		var cd := Rules.cooldown(picker_slot, choice, maxi(level, 1))
		option_meta[index].text = "재사용 %.1f초%s" % [cd, "  ·  장착 중" if equipped else ""]
		action.text = "선택 불가" if locked else ("최대 레벨" if maxed else "%s %d G" % ["강화" if equipped else "구매", cost])
		action.disabled = locked or maxed or local.gold < cost
		action.tooltip_text = "다음 경기에서 선택할 수 있습니다." if locked else "강화 시 %s" % data.upgrade


func set_addresses(addresses: PackedStringArray) -> void:
	address_options.clear()
	for address: String in addresses:
		address_options.add_item(address)
	if address_options.item_count > 0:
		address_options.select(0)


func update_view(state: Dictionary, screen: int, local_id: int, status: String,
	is_host: bool, muted: bool, practice_mode: bool) -> void:
	menu_layer.visible = screen < 2
	game_layer.visible = screen == 2
	if screen < 2:
		menu_mute_button.text = "소리 꺼짐" if muted else "소리 켜짐"
		close_picker()
		menu_status.text = status
		host_button.disabled = screen == 1
		join_button.disabled = screen == 1
		practice_button.disabled = screen == 1
		mode_options.disabled = screen == 1
		bot_options.disabled = screen == 1
		return
	var phase: int = state.get("phase", Match.LOBBY)
	var players: Dictionary = state.get("players", {})
	var local: Dictionary = players.get(local_id, {})
	var round_no: int = state.get("round", 0)
	var remaining := ceili(state.get("left", 0.0))
	var elapsed := floori(state.get("elapsed", 0.0))
	var compact := phase in [Match.COUNTDOWN, Match.FIGHT]
	var active := 0
	var team_active := [0, 0]
	for player: Dictionary in players.values():
		active += int(player.alive)
		if player.alive and player.team >= 0:
			team_active[player.team] += 1
	var teams: bool = state.get("mode", Match.FREE_FOR_ALL) == Match.TEAM_MATCH
	var mode := ("%s 연습전" % ("팀" if teams else "개인")) if practice_mode else ("친구 팀전" if teams else "친구 개인전")
	round_badge.text = "%s    %02d / %02d" % [mode, round_no, Rules.ROUNDS] if round_no else mode
	var survival := "블루 %d · 오렌지 %d" % team_active if teams else "%d명 생존" % active
	phase_badge.text = ["대기실", "정비 시간  ·  %02d초" % remaining, "시작까지  %d" % remaining,
		"%02d:%02d  ·  %s" % [elapsed / 60, elapsed % 60, survival], "최종 결과"][phase]
	team_score_badge.visible = teams and round_no > 0
	team_score_badge.text = "라운드  %d : %d" % state.get("team_wins", [0, 0])
	mute_button.text = "소리 꺼짐" if muted else "소리 켜짐"
	sidebar.visible = not compact
	var feed: Array = state.get("feed", [])
	for index in range(combat_feed.size()):
		var line := combat_feed[index]
		line.visible = phase == Match.FIGHT and index < feed.size()
		if line.visible:
			line.text = feed[index]
	arena_hint.text = "WASD 이동  ·  마우스 조준" if phase == Match.FIGHT else "안전선 밖에서는 체력이 감소합니다."
	var local_pos: Vector2 = local.get("p", Vector2.ZERO)
	var outside: bool = phase == Match.FIGHT and local.get("alive", false) and Rules.square_extent(local_pos) > state.half_side
	if outside:
		arena_hint.text = "장외  ·  안전선 안으로 복귀하세요."
	arena_hint.add_theme_color_override("font_color", AMBER if outside else SUBTLE)
	gear_hint.visible = phase == Match.FIGHT and local.get("alive", false) and not local.equipment.is_empty()
	if gear_hint.visible:
		var names := PackedStringArray()
		for choice: int in local.equipment:
			var name_text: String = Rules.skill(Rules.GEAR, choice).name
			if choice == Rules.EMERGENCY_GEAR:
				name_text += " %.1f초" % local.gear_time if local.gear_time > 0.0 else (" 소진" if local.gear_used else " 대기")
			if choice == Rules.SHIELD_GEAR:
				name_text += " 소진" if local.shield_used else " 대기"
			names.append(name_text)
		gear_hint.text = " · ".join(names)
	center_box.position.x = 485.0 if compact else 305.0
	center_box.visible = phase != Match.FIGHT or not local.get("alive", false)
	character_picker.visible = phase == Match.LOBBY and not local.is_empty()
	if character_picker.visible:
		for choice in range(character_buttons.size()):
			var selected: bool = local.character == choice
			character_buttons[choice].disabled = selected
			character_buttons[choice].text = Rules.CHARACTER_NAMES[choice] + (" · 선택됨" if selected else "")
	match phase:
		Match.LOBBY:
			center_title.text = "대기실"
			center_detail.text = "양 팀에 인원이 있고 인원 차이가 1명 이하면 시작합니다." if teams else "2명 이상 모이면 호스트가 시작할 수 있습니다."
		Match.SHOP:
			var winner: String = state.get("round_winner", "")
			center_title.text = "첫 라운드 준비" if round_no == 1 else (
				"%s 라운드 승리" % winner if not winner.is_empty() else "직전 라운드 무승부")
			center_detail.text = "Q 스킬 하나를 고르거나 장비를 구매하세요." if round_no == 1 else "직전 라운드 킬 · 피해량 순위에 따라 골드를 받았습니다."
		Match.COUNTDOWN:
			center_title.text = "%d" % remaining
			center_detail.text = "라운드 %d  ·  곧 전투가 시작됩니다." % round_no
		Match.FIGHT:
			center_title.text = "탈락 · 관전 중"
			center_detail.text = survival
		Match.RESULTS:
			var winners: Array = state.get("winners", [])
			center_title.text = "최종 우승  ·  %s" % winners[0] if winners.size() == 1 else ("공동 우승" if not winners.is_empty() else "경기 종료")
			center_detail.text = "라운드 승수 → 총 킬 → 총 피해량"
			if teams:
				center_detail.text = "상대 팀 연결 종료" if state.get("team_forfeit", false) else "블루 %d승  ·  오렌지 %d승" % state.team_wins

	var team: int = local.get("team", -1)
	self_title.text = "%s · %s" % [Rules.TEAM_NAMES[team], local.get("name", "")] if team >= 0 else local.get("name", "")
	self_title.add_theme_color_override("font_color", Rules.TEAM_COLORS[team] if team >= 0 else Rules.COLORS[local.get("color", 0)])
	var hp: float = local.get("hp", 100.0) if phase in [Match.COUNTDOWN, Match.FIGHT] else 100.0
	var impact: float = local.get("impact", 0.0) if phase in [Match.COUNTDOWN, Match.FIGHT] else 0.0
	self_stats.text = "체력 %d  /  100     충격 %d%%" % [ceili(hp), roundi(impact)]
	self_bar.size.x = 233.0 * hp / 100.0
	self_bar.color = AMBER if hp < 32.0 else MINT
	if sidebar.visible:
		update_sidebar(state, phase, players, local, is_host, status)
	update_picker(phase, local)
	if picker.visible:
		center_box.hide()
	update_skills(local, phase)
	var rows: Array = state.get("rankings", [])
	recap.visible = phase == Match.SHOP and not rows.is_empty() and not picker.visible
	if recap.visible:
		recap.size.y = 86 + rows.size() * 28
		for index in range(Rules.CAPACITY):
			recap_rows[index].visible = index < rows.size()
			if index < rows.size():
				var row: Dictionary = rows[index]
				recap_rows[index].text = "%d  %s  ·  %d / %d / +%d G" % [
					row.rank, row.name.left(9), row.kills, row.damage, row.award]


func update_sidebar(state: Dictionary, phase: int, players: Dictionary, local: Dictionary,
	is_host: bool, status: String) -> void:
	var shopping := phase == Match.SHOP
	var mode: int = state.get("mode", Match.FREE_FOR_ALL)
	var teams := mode == Match.TEAM_MATCH
	var ready: bool = local.get("ready", false)
	change_button.visible = shopping or (is_host and phase in [Match.LOBBY, Match.RESULTS])
	change_button.disabled = phase == Match.LOBBY and not Match.can_start(players, mode)
	team_button.visible = teams and phase == Match.LOBBY and not local.is_empty()
	if team_button.visible:
		var other: int = 1 - local.team
		team_button.text = "%s으로 이동" % Rules.TEAM_NAMES[other]
		team_button.disabled = Match.team_counts(players)[other] >= Rules.TEAM_SIZE
	copy_button.visible = phase == Match.LOBBY and is_host and address_options.item_count > 0
	address_options.visible = copy_button.visible
	sidebar_title.text = ["참가자", "라운드 상점", "", "", "최종 순위"][phase]
	if teams and phase == Match.RESULTS:
		sidebar_title.text = "팀전 결과"
	sidebar_meta.text = ["%d / %d명" % [players.size(), Rules.CAPACITY],
		"", "", "", " · ".join(state.get("winners", []))][phase]
	sidebar_hint.text = ""
	match phase:
		Match.LOBBY:
			change_button.text = "대전 시작"
			sidebar_hint.text = status if not status.is_empty() else (
				"친구에게 호스트 주소와 포트를 알려주세요." if copy_button.visible else
				("캐릭터를 고른 뒤 대전을 시작하세요." if is_host else "호스트가 시작하기를 기다리는 중"))
		Match.SHOP:
			change_button.text = "준비 취소" if ready else "구매 완료 · 준비"
			var ready_count := players.values().filter(func(player: Dictionary): return player.ready).size()
			sidebar_meta.text = "%d G    ·    %d/%d명 준비" % [local.get("gold", 0), ready_count, players.size()]
			var reward := ""
			for entry_data: Dictionary in state.get("rankings", []):
				if entry_data.id == game.own_id:
					reward = "직전 %d위   +%d G" % [entry_data.rank, entry_data.award]
			sidebar_hint.text = reward if not reward.is_empty() else "첫 라운드 구매 · Q 스킬 또는 장비"
		Match.RESULTS:
			change_button.text = "대기실로 돌아가기"
			var feed: Array = state.get("feed", [])
			sidebar_hint.text = feed[0] if not feed.is_empty() else "라운드 승수 기준"
	var order := players.keys()
	if phase == Match.RESULTS:
		order.sort_custom(func(a: int, b: int):
			var p: Dictionary = players[a]
			var q: Dictionary = players[b]
			if p.wins != q.wins:
				return p.wins > q.wins
			if p.total_kills != q.total_kills:
				return p.total_kills > q.total_kills
			return p.total_damage > q.total_damage)
	for index in range(Rules.CAPACITY):
		roster[index].visible = not shopping and index < order.size()
		if roster[index].visible:
			var id: int = order[index]
			var player: Dictionary = players[id]
			var team: int = player.team
			var details := ""
			if phase == Match.RESULTS:
				details = "%d승   %d킬   %d 피해" % [player.wins, player.total_kills, player.total_damage]
			elif phase == Match.LOBBY:
				details = Rules.CHARACTER_NAMES[player.character]
			if team >= 0:
				details = "%s  ·  %s" % [Rules.TEAM_NAMES[team], details]
			roster[index].text = "●  %s    ·    %s" % [player.name, details]
			roster[index].add_theme_color_override("font_color", Rules.TEAM_COLORS[team] if team >= 0 else Rules.COLORS[player.color])
	for slot in range(Rules.SLOTS.size()):
		shop_rows[slot].visible = shopping
		shop_prices[slot].visible = shopping
		if not shopping or local.is_empty():
			continue
		var group: Dictionary = Rules.SLOTS[slot]
		if slot == Rules.GEAR:
			shop_names[slot].text = group.name
			shop_names[slot].position.y = 13
			shop_details[slot].text = ""
			shop_rows[slot].accessibility_name = "장비 상점"
			shop_rows[slot].tooltip_text = "장비 구매·판매"
			shop_rows[slot].disabled = ready
			shop_prices[slot].text = "%d / %d" % [local.equipment.size(), Rules.EQUIPMENT_CAP]
			continue
		var level: int = local.levels[slot]
		var data := Rules.skill(slot, local.choices[slot])
		var cost := Rules.price(slot, level)
		var maxed := level >= Rules.level_cap(slot)
		var multiple: bool = group.options.size() > 1
		var title: String = group.name if multiple else data.name
		var detail := ""
		if level > 0:
			detail = "%s  Lv.%d" % [data.name, level] if multiple else "Lv.%d" % level
		shop_names[slot].text = title
		shop_names[slot].position.y = 13 if detail.is_empty() else 5
		shop_details[slot].text = detail
		shop_rows[slot].accessibility_name = title if detail.is_empty() else "%s %s" % [title, detail]
		var available := Rules.shop_slot_open(state.round, slot)
		shop_rows[slot].tooltip_text = ("스킬 후보 보기" if multiple else data.help) if available else "2라운드부터 구매 가능"
		shop_rows[slot].disabled = ready or not available or (not multiple and (maxed or local.gold < cost))
		shop_prices[slot].add_theme_color_override("font_color", SUBTLE if level > 0 and multiple else GOLD)
		shop_prices[slot].text = ("최대" if maxed else ("강화 ›" if multiple and level > 0 else "%d G" % cost)) if available else "2R부터"


func update_skills(local: Dictionary, phase: int) -> void:
	for slot in range(Rules.ACTIVE_SLOTS):
		var level: int = local.get("levels", Rules.BASE_LEVELS)[slot]
		var choice: int = local.get("choices", Rules.BASE_CHOICES)[slot]
		var data := Rules.skill(slot, choice)
		var cd: float = local.cooldowns[slot] if phase == Match.FIGHT and not local.is_empty() else 0.0
		var recast := Match.recast_window(local, slot) if phase == Match.FIGHT and not local.is_empty() else 0.0
		skill_names[slot].text = data.name if level else Rules.SLOTS[slot].name
		skill_tiles[slot].tooltip_text = data.help if level else "라운드 상점에서 스킬 선택"
		skill_names[slot].add_theme_color_override("font_color", TEXT if level else SUBTLE)
		skill_status[slot].text = "미구매" if level == 0 else ("%.1f초" % cd if cd > 0.0 else "Lv.%d  ·  준비" % level)
		if recast > 0.0:
			skill_status[slot].text = "재입력 %.1f초" % recast
		if phase == Match.FIGHT and level > 0:
			var blocked := Match.cast_block(local, slot)
			if not blocked.is_empty() and (blocked != "시전 중" or slot == local.get("windup_slot", -1)):
				skill_status[slot].text = blocked
			elif slot == Rules.MOVE and local.get("cloak", 0.0) > 0.0:
				skill_status[slot].text = "은신 %.1f초" % local.cloak
		skill_fill[slot].size.x = 168.0 * clampf(1.0 - cd / Rules.cooldown(slot, choice, maxi(level, 1)), 0.0, 1.0) if level else 0.0
