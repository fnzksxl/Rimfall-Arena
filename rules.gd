extends RefCounted

const ROUNDS := 5
const CAPACITY := 6
const START_GOLD := 220
const SHOP_TIME := 25.0
const HALF_SIDE := 700.0
const SPAWN_DISTANCE := 290.0
const WALK_SPEED := 105.0
const OUTSIDE_DPS := 14.0
const OVERLOAD_DPS := 12.0
const BODY_RADIUS := 14.0
const MAX_IMPACT := 240.0
const ATTACK_DAMAGE_SCALE := 0.75
const PROJECTILE_SPEED_SCALE := 0.60
const EMERGENCY_DURATION := 2.5
const EMERGENCY_REDUCTION := 0.60
const EQUIPMENT_CAP := 3
const EMERGENCY_GEAR := 1
const MAX_CHOICES := 6
const COLORS := [Color("#79f2db"), Color("#ffa574"), Color("#93aaff"),
	Color("#f7dc72"), Color("#ef93c8"), Color("#adf097")]
enum { BASIC, Q, E, R, F, MOVE, GEAR }
enum { BOLT, WAVE, ORB, DISC }
const ACTIVE_SLOTS := GEAR
const BASE_LEVELS := [1, 0, 0, 0, 0, 0]
const BASE_CHOICES := [0, 0, 0, 0, 0, 0]
const SLOTS := [
	{"key": "LMB", "name": "기본 공격", "color": Color("#79f2db"), "price": 90, "options": [
		{"id": "pulse", "name": "펄스 탄", "cd": 4.0, "help": "빠른 직선탄", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 640.0, "size": 9.0, "life": 0.85, "damage": 10, "gain": 3, "force": 255.0, "style": BOLT}},
	]},
	{"key": "Q", "name": "투사체 견제", "color": Color("#ffa574"), "price": 120, "options": [
		{"id": "wave", "name": "충격파", "cd": 6.5, "help": "짧게 뻗는 파동\n여러 상대를 밀어냄", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 430.0, "size": 16.0, "life": 0.60, "damage": 15, "gain": 4, "force": 340.0, "style": WAVE, "pierce": true}},
		{"id": "lance", "name": "관통창", "cd": 6.8, "help": "가는 장거리 투사체\n상대를 관통", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 775.0, "size": 6.0, "life": 0.91, "damage": 16, "gain": 4, "force": 345.0, "style": BOLT, "pierce": true}},
		{"id": "fan", "name": "삼연탄", "cd": 7.3, "help": "부채꼴로 작은 탄 3발 발사", "upgrade": "각 탄의 피해와 넉백 증가",
			"shot": {"speed": 555.0, "size": 4.0, "life": 0.57, "damage": 8, "gain": 2, "force": 215.0, "style": BOLT}},
		{"id": "disc", "name": "회수 디스크", "cd": 8.0, "help": "좁은 궤도로 왕복\n돌아올 때 피해 감소", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 540.0, "size": 7.0, "life": 0.81, "damage": 13, "gain": 3, "force": 285.0, "style": DISC,
				"pierce": true, "returns": true}},
		{"id": "curve", "name": "궤도 탄", "cd": 7.2, "help": "발사 방향에서 왼쪽으로\n휘어 날아가는 좁은 탄", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 570.0, "size": 6.0, "life": 0.83, "damage": 14, "gain": 3, "force": 320.0, "style": BOLT, "curve": 1.18}},
		{"id": "seeker", "name": "추적 신호탄", "cd": 8.6, "help": "전방의 가까운 상대를\n천천히 따라가는 탄", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 485.0, "size": 5.0, "life": 1.02, "damage": 11, "gain": 3, "force": 265.0, "style": BOLT, "seeks": true}},
	]},
	{"key": "E", "name": "범위 공격", "color": Color("#93aaff"), "price": 125, "options": [
		{"id": "mark", "name": "낙뢰 표식", "cd": 9.0, "help": "조준 지점에 지연 폭발", "upgrade": "피해와 폭발 반경 증가"},
		{"id": "repel", "name": "반발 고리", "cd": 8.2, "help": "발밑에서 파동 발생\n주변 상대를 밀어냄", "upgrade": "피해와 파동 반경 증가"},
		{"id": "fissure", "name": "균열선", "cd": 9.3, "help": "조준 방향의 세 지점이\n순서대로 폭발", "upgrade": "피해와 폭발 반경 증가"},
		{"id": "scatter", "name": "분열 표식", "cd": 9.8, "help": "표식에서 조준 방향 기준\n네 방향으로 작은 탄 발사", "upgrade": "분열탄 피해와 넉백 증가",
			"shot": {"speed": 565.0, "size": 5.0, "life": 0.48, "damage": 10, "gain": 2, "force": 255.0, "style": BOLT}},
	]},
	{"key": "R", "name": "결정타", "color": Color("#ff8584"), "price": 145, "options": [
		{"id": "heavy", "name": "중격탄", "cd": 10.0, "help": "느리고 무거운 탄\n피격 시 강한 넉백", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 335.0, "size": 20.0, "life": 1.22, "damage": 26, "gain": 4, "force": 620.0, "style": ORB}},
		{"id": "gravity", "name": "중력 붕괴", "cd": 11.0, "help": "폭발 중심으로 상대를 당김\n범위 안 투사체의 궤도 변경", "upgrade": "피해와 폭발 반경 증가"},
		{"id": "recoil", "name": "반동포", "cd": 9.8, "help": "강한 직선탄\n발사 반동으로 뒤로 이동", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 660.0, "size": 8.0, "life": 0.75, "damage": 25, "gain": 4, "force": 555.0, "style": BOLT}},
		{"id": "windup", "name": "과충전 볼트", "cd": 10.8, "help": "방향을 고정하고 0.75초 충전\n피격 시 발사 취소", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 660.0, "size": 9.0, "life": 0.90, "damage": 30, "gain": 4, "force": 590.0, "style": BOLT}},
	]},
	{"key": "F", "name": "유틸리티", "color": Color("#f7dc72"), "price": 105, "options": [
		{"id": "guard", "name": "고정장", "cd": 7.5, "help": "잠시 받는 넉백 70% 감소", "upgrade": "지속 시간 증가"},
		{"id": "repair", "name": "응급 수리", "cd": 11.5, "help": "즉시 체력 16 회복", "upgrade": "회복량 증가"},
		{"id": "cleanse", "name": "충격 정화", "cd": 9.0, "help": "충격 32%p 제거\n현재 넉백 감소", "upgrade": "제거하는 충격량 증가"},
		{"id": "reflect", "name": "반사막", "cd": 10.8, "help": "짧은 시간 첫 투사체 반사\n반사된 탄은 피해 감소", "upgrade": "반사 대기 시간 증가"},
		{"id": "anchor", "name": "회귀 앵커", "cd": 11.0, "help": "현재 위치를 표시\n2초 안에 F 재입력으로 복귀", "upgrade": "복귀 가능 시간 증가"},
		{"id": "surge", "name": "가속 저장기", "cd": 9.2, "help": "준비 중 피격되면\n잠시 이동속도 24% 증가", "upgrade": "가속 지속 시간 증가"},
	]},
	{"key": "Space", "name": "이동기", "color": Color("#79bcff"), "price": 100, "options": [
		{"id": "dash", "name": "점멸 추진", "cd": 5.2, "help": "조준 방향으로 돌진", "upgrade": "돌진 거리 증가"},
		{"id": "recover", "name": "긴급 복귀", "cd": 7.6, "help": "경기장 안쪽으로 추진\n장외에서는 더 멀리 이동", "upgrade": "추진 거리 증가"},
		{"id": "tackle", "name": "몸통박치기", "cd": 8.4, "help": "빠르게 부딪힐수록 강함\n피격 시 박치기 중단", "upgrade": "피해와 돌진 거리 증가"},
		{"id": "double", "name": "이중 도약", "cd": 8.1, "help": "짧게 돌진한 뒤 0.9초 안에\nSpace로 방향을 바꿔 재돌진", "upgrade": "두 돌진의 이동 거리 증가"},
	]},
	{"key": "", "name": "장비", "color": Color("#adf097"), "options": [
		{"id": "coil", "name": "절연 코일", "price": 90, "outside": 0.75, "help": "장외 피해 25% 감소"},
		{"id": "capsule", "name": "비상 캡슐", "price": 110, "emergency": true, "help": "라운드 첫 장외 진입 시\n2.5초간 장외 피해 60% 감소"},
		{"id": "light", "name": "경량 프레임", "price": 115, "walk": 1.12, "knockback": 1.20, "help": "이동속도 12% 증가\n받는 넉백 20% 증가"},
		{"id": "heavy_frame", "name": "중량 프레임", "price": 120, "knockback": 0.82, "range": 0.85, "help": "받는 넉백 18% 감소\n투사체 사거리 15% 감소"},
		{"id": "damper", "name": "충격 완충기", "price": 105, "impact": 0.80, "walk": 0.95, "help": "피격 시 충격 누적 20% 감소\n이동속도 5% 감소"},
		{"id": "optics", "name": "장거리 조준기", "price": 115, "range": 1.18, "shot_speed": 0.90, "help": "투사체 사거리 18% 증가\n투사체 속도 10% 감소"},
	]},
]

static func level_cap(slot: int) -> int:
	return 1 if slot == GEAR else 3

static func price(slot: int, level: int, choice := 0) -> int:
	if slot == GEAR:
		return skill(slot, choice).price
	return SLOTS[slot].price + maxi(0, level - int(slot == BASIC)) * 45

static func skill(slot: int, choice: int) -> Dictionary:
	return SLOTS[slot].options[choice]

static func equipment_factor(player: Dictionary, stat: String) -> float:
	var factor := 1.0
	for choice: int in player.get("equipment", []):
		factor *= skill(GEAR, choice).get(stat, 1.0)
	return factor

static func resale(choice: int) -> int:
	return floori(price(GEAR, 0, choice) * 0.5)

static func cooldown(slot: int, choice: int, level: int) -> float:
	return skill(slot, choice).cd - (level - 1) * (0.33 if slot == MOVE else 0.09)

static func attack_damage(base_damage: int) -> int:
	return roundi(base_damage * ATTACK_DAMAGE_SCALE)

static func half_side_at(elapsed: float) -> float:
	return maxf(68.0, HALF_SIDE - maxf(0.0, elapsed - 26.0) * 15.7)

static func square_extent(point: Vector2) -> float:
	return maxf(absf(point.x), absf(point.y))

static func knockback_multiplier(impact: float) -> float:
	return 1.0 + impact / 145.0

static func award(rank: int) -> int:
	return 100 + maxi(0, 45 - (rank - 1) * 15)
