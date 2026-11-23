extends SceneTree

const Scene = preload("res://main.tscn")
const Match = preload("res://match.gd")
const Arena = preload("res://arena.gd")
const Rules = preload("res://rules.gd")


func _initialize() -> void:
	run.call_deferred()


func capture(name: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var output := root.get_texture().get_image().save_png("res://build/%s.png" % name)
	assert(output == OK)


func run() -> void:
	create_timer(12.0).timeout.connect(func(): quit(1))
	var game := Scene.instantiate()
	root.add_child(game)
	await capture("menu-preview")
	game.practice("파일럿")
	await capture("shop-preview")
	assert(game.hud.sidebar.is_visible_in_tree() and game.hud.shop_rows[0].is_visible_in_tree())
	game.hud.shop_rows[Rules.GEAR].pressed.emit()
	await capture("gear-shop-preview")
	assert(game.hud.option_cards[4].is_visible_in_tree() and "110 G" in game.hud.option_actions[1].text)
	game.hud.picker_tabs[1].pressed.emit()
	await capture("combat-gear-shop-preview")
	assert(game.hud.option_names[3].text == "차폐 전지" and not game.hud.option_cards[4].is_visible_in_tree())
	game.hud.option_actions[3].pressed.emit()
	await process_frame
	assert(Rules.SHIELD_GEAR in game.sim.players[1].equipment)
	game.hud.option_actions[3].pressed.emit()
	await process_frame
	assert(game.sim.players[1].equipment.is_empty())
	game.sim.players[1].gold = Rules.START_GOLD
	game.hud.shop_rows[Rules.Q].pressed.emit()
	await capture("disc-picker-preview")
	assert(game.hud.option_cards[5].is_visible_in_tree() and game.hud.option_names[2].text == "연쇄 도탄")
	game.hud.picker_tabs[1].pressed.emit()
	await capture("snare-picker-preview")
	assert(game.hud.option_names[0].text == "구속탄" and not game.hud.option_cards[1].is_visible_in_tree())
	game.hud.shop_rows[Rules.MOVE].pressed.emit()
	await capture("skill-picker-preview")
	assert(game.hud.picker.is_visible_in_tree() and "몸통박치기" in game.hud.option_names[2].text)
	assert(game.hud.option_cards[4].is_visible_in_tree() and not game.hud.option_cards[5].is_visible_in_tree())
	game.hud.option_actions[2].pressed.emit()
	game.buy_slot(Rules.Q)
	assert(game.sim.players[1].choices[Rules.MOVE] == 2)
	game.hud.shop_rows[Rules.MOVE].pressed.emit()
	await capture("skill-picker-locked-preview")
	assert(game.hud.option_actions[0].disabled and "장착 중" in game.hud.option_meta[2].text)
	game.hud.close_picker()
	game.primary_action()
	await create_timer(0.10).timeout
	assert(game.sim.phase == Match.COUNTDOWN and not game.hud.sidebar.is_visible_in_tree())
	assert(game.arena.offscreen_markers().is_empty())
	await create_timer(3.12).timeout
	game.sim.cast(1, 0, game.sim.players[-1].p)
	await create_timer(0.25).timeout
	await capture("combat-preview")
	assert(not game.hud.sidebar.is_visible_in_tree() and not game.hud.shop_rows[0].is_visible_in_tree())
	assert(is_equal_approx(game.arena.scale.x, 1.12))
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space)
	assert(game.sim.players[1].cooldowns[Rules.MOVE] > 0.0 and game.sim.players[1].charge > 0.0)
	var shot := InputEventMouseButton.new()
	shot.button_index = MOUSE_BUTTON_LEFT
	shot.pressed = true
	shot.position = Vector2(1180, 430)
	game.sim.players[1].cooldowns[0] = 0.0
	game._unhandled_input(shot)
	assert(game.sim.players[1].cooldowns[0] > 0.0)
	var half := Rules.HALF_SIDE
	game.sim.players[1].kick = Vector2.ZERO
	game.sim.players[1].p = Vector2(half - 7, -half + 7)
	game.sim.players[-1].p = Vector2(half - 300, -half + 140)
	await create_timer(0.20).timeout
	await capture("combat-edge-preview")
	var shown: Vector2 = game.arena.to_global(game.arena.fighter_positions[1])
	assert(shown.is_equal_approx(Arena.COMBAT_VIEW.get_center()))
	assert(game.arena.to_global(Vector2.ZERO).y > Arena.COMBAT_VIEW.end.y)
	assert(game.arena.offscreen_markers().is_empty())
	game.sim.players[-1].p = Vector2(-450, -half + 60)
	await create_timer(0.20).timeout
	await capture("offscreen-arrow-preview")
	var markers: Array = game.arena.offscreen_markers()
	assert(markers.size() == 1 and is_equal_approx(markers[0].point.x, Arena.ARROW_FRAME.position.x))
	assert(markers[0].direction.x < -0.95 and markers[0].color == Rules.COLORS[1])
	game.sim.players[-1].cloak = 0.60
	await process_frame
	await process_frame
	assert(game.arena.offscreen_markers().is_empty() and not game.arena.fighter_positions.has(-1))
	game.sim.players[-1].cloak = 0.0
	game.sim.players[1].p = Vector2(Rules.MAP_HALF_SIDE - 90.0, -half)
	await create_timer(0.25).timeout
	await capture("outer-map-edge-preview")
	game.sim.players[-1].alive = false
	assert(game.arena.offscreen_markers().is_empty())
	game.leave_game()
	game.hud.mode_options.select(1)
	game.hud.mode_options.item_selected.emit(1)
	assert(game.hud.bot_options.item_count == 3 and game.hud.bot_options.get_selected_id() == 3)
	game.hud.bot_options.select(2)
	await capture("team-menu-preview")
	game.hud.practice_button.pressed.emit()
	await capture("team-shop-preview")
	assert(game.sim.mode == Match.TEAM_MATCH and Match.team_counts(game.sim.players) == [3, 3])
	game.primary_action()
	game.sim.advance(0.05)
	game.sim.advance(3.0)
	game.show_state()
	await capture("team-combat-preview")
	assert(game.hud.team_score_badge.is_visible_in_tree() and "블루 3 · 오렌지 3" in game.hud.phase_badge.text)
	print("RIMFALL SQUARE CAMERA, OFFSCREEN ARROWS, SHOP VISIBILITY AND RIGHT-SIDE INPUT PASSED")
	quit()
