extends RefCounted

const ROUNDS := 5
const MAX_ROUNDS := 15
const CAPACITY := 6
const TEAM_SIZE := CAPACITY / 2
const TEAM_NAMES := ["블루 팀", "오렌지 팀"]
const TEAM_COLORS := [Color("#8dbbff"), Color("#ffaf81")]
const START_GOLD := 120
const AREA_WINDUP := 0.14
const REPEL_WINDUP := 0.33
const REPEL_RELEASE_DELAY := 0.02
const AREA_RADII := {"mark": 46.0, "repel": 68.0, "fissure": 29.0, "gravity": 64.0, "scatter": 30.0,
	"repeater": 23.0, "crossfire": 29.0, "impact_burst": 40.0}
const CROSSFIRE_OFFSET := 55.0
const TWIN_SHOT_SPREAD := 0.14
const FISSURE_STEP := 85.0
const CURVE_TIME := 1.35
const SHOP_TIME := 25.0
const HALF_SIDE := 700.0
const FINAL_HALF_SIDE := 220.0
const SHRINK_START := 26.0
const SHRINK_END := 75.0
const MAP_HALF_SIDE := 1440.0
const SPAWN_DISTANCE := 290.0
const WALK_SPEED := 105.0
const OUTSIDE_DPS := 14.0
const BODY_RADIUS := 13.0
const MAX_IMPACT := 240.0
const ATTACK_DAMAGE_SCALE := 0.60
const IMPACT_PER_DAMAGE := 1.75
const KNOCKBACK_SPEED_SCALE := 0.84
const KNOCKBACK_DECAY := 3.9
const LOW_HEALTH_KNOCKBACK_DECAY := 2.4
const PROPULSION_DECAY := 4.7
const PROJECTILE_SPEED_SCALE := 0.60
const EMERGENCY_DURATION := 2.5
const EMERGENCY_REDUCTION := 0.60
const EQUIPMENT_CAP := 3
const EMERGENCY_GEAR := 1
const SHIELD_GEAR := 8
const MAX_CHOICES := 6
const CHARACTER_NAMES := ["울트론", "아이언맨", "비전", "스파이더맨", "워 머신", "블랙 팬서"]
const COLORS := [Color("#79f2db"), Color("#ffa574"), Color("#93aaff"),
	Color("#f7dc72"), Color("#ef93c8"), Color("#adf097")]
enum { BASIC, Q, E, R, F, MOVE, GEAR }
enum { BOLT, WAVE, ORB, DISC }
enum Cue { FIRE, POWER, DASH, GUARD, MARK, HIT, START, RESULT, CLASH, DEFLECT, KNOCKOUT, STRIKE }
enum Vfx {
	NONE, GRAVITY, TACKLE_LAUNCH, TACKLE_HIT,
	WAVE, LANCE, RICOCHET, DISC, CURVE, SEEKER, SNARE,
	MARK, REPEL, FISSURE, SCATTER, LINK, REPEATER,
	HEAVY, RECOIL, WINDUP, SWAP, JAM,
	GUARD, REPAIR, CLEANSE, REFLECT, ANCHOR, SURGE, MIRROR,
	DASH, RECOVER, DOUBLE, CLOAK,
	DISC_TURN, BOUNCE_TURN, REPEATER_FIRE, WINDUP_BREAK, SWAP_PORTAL,
	REFLECT_HIT, ANCHOR_RETURN, SURGE_ACTIVE, MIRROR_BREAK,
	RECOVER_OUTSIDE, DOUBLE_RECAST, CLOAK_HIT, CLOAK_REVEAL, LINK_TICK, LINK_END,
	MUZZLE, IMPACT_BURST,
}
const SKILL_VFX := {
	"wave": Vfx.WAVE, "lance": Vfx.LANCE, "ricochet": Vfx.RICOCHET, "disc": Vfx.DISC,
	"curve": Vfx.CURVE, "seeker": Vfx.SEEKER, "snare": Vfx.SNARE,
	"mark": Vfx.MARK, "repel": Vfx.REPEL, "fissure": Vfx.FISSURE, "scatter": Vfx.SCATTER,
	"link": Vfx.LINK, "repeater": Vfx.REPEATER,
	"heavy": Vfx.HEAVY, "gravity": Vfx.GRAVITY, "recoil": Vfx.RECOIL, "windup": Vfx.WINDUP,
	"swap": Vfx.SWAP, "jam": Vfx.JAM,
	"guard": Vfx.GUARD, "repair": Vfx.REPAIR, "cleanse": Vfx.CLEANSE, "reflect": Vfx.REFLECT,
	"anchor": Vfx.ANCHOR, "surge": Vfx.SURGE, "mirror": Vfx.MIRROR,
	"dash": Vfx.DASH, "recover": Vfx.RECOVER, "tackle": Vfx.TACKLE_LAUNCH,
	"double": Vfx.DOUBLE, "cloak": Vfx.CLOAK,
	"twin_shot": Vfx.LANCE, "crossfire": Vfx.MARK, "impact_burst": Vfx.IMPACT_BURST,
	"brake": Vfx.GUARD, "backstep": Vfx.DASH,
}
enum { NO_PROC, BOUNCE, ROOT, LINK, SWAP, JAM }
const LINK_RANGE := 360.0
const LINK_INTERVAL := 0.65
const REPEATER_FIRST_SHOT := 0.40
const REPEATER_INTERVAL := 0.32
const SEEKER_GUIDANCE := {"start": 0.22, "end": 1.38, "distance": 250.0, "cone": 0.70, "rate": 1.05}
const REPEATER_GUIDANCE := {"start": 0.10, "end": 0.48, "distance": 180.0, "cone": 0.32, "rate": 0.38}
const ACTIVE_SLOTS := GEAR
const BASE_LEVELS := [1, 0, 0, 0, 0, 0]
const BASE_CHOICES := [0, 0, 0, 0, 0, 0]
const SLOTS := [
	{"key": "LMB", "name": "기본 공격", "color": Color("#79f2db"), "price": 90, "options": [
		{"id": "pulse", "name": "펄스 탄", "cd": 4.0, "help": "빠른 직선탄", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 640.0, "size": 9.0, "damage": 10, "gain": 3, "force": 255.0, "style": BOLT}},
	]},
	{"key": "Q", "name": "투사체 견제", "color": Color("#ffa574"), "price": 120, "options": [
		{"id": "wave", "name": "충격파", "cd": 6.5, "help": "넓고 느린 직선 파동\n첫 상대만 강하게 밀어냄", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 430.0, "size": 16.0, "damage": 15, "gain": 4, "force": 380.0, "style": WAVE}},
		{"id": "lance", "name": "관통창", "cd": 6.8, "help": "가는 고속 투사체\n일렬로 선 여러 상대를 관통", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 775.0, "size": 6.0, "damage": 16, "gain": 4, "force": 345.0, "style": BOLT, "pierce": true}},
		{"id": "ricochet", "name": "연쇄 도탄", "cd": 8.0, "help": "맞힌 뒤 주변 새 상대에게\n약해진 탄이 최대 두 번 튐", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 565.0, "size": 7.0, "damage": 13, "gain": 3, "force": 280.0, "style": ORB, "proc": BOUNCE}},
		{"id": "disc", "name": "회수 디스크", "cd": 8.0, "help": "좁은 궤도로 왕복\n돌아올 때 피해 감소", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 540.0, "size": 7.0, "damage": 13, "gain": 3, "force": 285.0, "style": DISC,
				"pierce": true, "turn_distance": 219.0}},
		{"id": "curve", "name": "궤도 탄", "cd": 7.2, "help": "왼쪽으로 휘어 날아가는\n굵은 투사체", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 570.0, "size": 10.0, "damage": 14, "gain": 3, "force": 320.0, "style": BOLT, "curve": 1.18}},
		{"id": "seeker", "name": "추적 신호탄", "cd": 8.6, "help": "가까운 정면의 적을 잠깐\n따라간 뒤 직진하는 탄", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 485.0, "size": 5.0, "damage": 11, "gain": 3, "force": 240.0, "style": BOLT,
				"guidance": SEEKER_GUIDANCE}},
		{"id": "snare", "name": "구속탄", "cd": 8.6, "help": "맞은 상대의 이동과 Space를\n잠시 봉쇄. 넉백은 적용", "upgrade": "구속 지속 시간 증가",
			"shot": {"speed": 535.0, "size": 7.0, "damage": 6, "gain": 0, "force": 105.0, "style": BOLT, "proc": ROOT}},
		{"id": "twin_shot", "name": "쌍발 탄", "cd": 7.8, "help": "조준 방향 양쪽으로\n두 발을 동시에 발사", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 600.0, "size": 6.0, "damage": 10, "gain": 2, "force": 160.0, "style": BOLT}},
	]},
	{"key": "E", "name": "범위 공격", "color": Color("#93aaff"), "price": 125, "options": [
		{"id": "mark", "name": "낙뢰 표식", "cd": 9.0, "help": "조준 지점에 지연 폭발", "upgrade": "피해와 폭발 반경 증가"},
		{"id": "repel", "name": "반발 고리", "cd": 8.2, "help": "짧은 준비 후 내 위치에서\n주변 상대를 밀어냄", "upgrade": "피해와 파동 반경 증가"},
		{"id": "fissure", "name": "균열선", "cd": 9.3, "help": "조준 방향의 세 지점이\n순서대로 폭발", "upgrade": "피해와 폭발 반경 증가"},
		{"id": "scatter", "name": "분열 표식", "cd": 9.8, "help": "표식에서 조준 방향 기준\n네 방향으로 작은 탄 발사", "upgrade": "분열탄 피해와 넉백 증가",
			"shot": {"speed": 565.0, "size": 5.0, "damage": 10, "gain": 2, "force": 255.0, "style": BOLT}},
		{"id": "link", "name": "방전 연결", "cd": 9.6, "help": "맞은 상대와 연결해 3회 방전\n멀리 떨어지면 연결이 끊김", "upgrade": "방전 피해 증가",
			"shot": {"speed": 565.0, "size": 6.0, "damage": 5, "gain": 0, "force": 115.0, "style": BOLT, "proc": LINK}},
		{"id": "repeater", "name": "연사 포대", "cd": 10.2, "cd_per_level": 0.60,
			"help": "조준 지점에 포대를 설치\n전방의 적을 약하게 유도하는 탄 3발", "upgrade": "피해·넉백 증가, 쿨타임 0.6초 감소",
			"shot": {"speed": 490.0, "size": 7.0, "damage": 12, "gain": 2, "force": 170.0, "style": BOLT,
				"guidance": REPEATER_GUIDANCE}},
		{"id": "crossfire", "name": "양익 폭발", "cd": 9.1, "help": "조준 지점 양옆에서\n지연 폭발 두 번 동시 발동", "upgrade": "피해와 폭발 반경 증가"},
	]},
	{"key": "R", "name": "결정타", "color": Color("#ff8584"), "price": 145, "options": [
		{"id": "heavy", "name": "중격탄", "cd": 10.0, "help": "느리고 무거운 탄\n피격 시 강한 넉백", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 335.0, "size": 20.0, "damage": 26, "gain": 4, "force": 620.0, "style": ORB}},
		{"id": "gravity", "name": "중력 붕괴", "cd": 11.0, "help": "폭발 중심으로 상대를 당김\n범위 안 투사체의 궤도 변경", "upgrade": "피해와 폭발 반경 증가"},
		{"id": "recoil", "name": "반동포", "cd": 9.8, "help": "강한 직선탄\n발사 반동으로 뒤로 이동", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 660.0, "size": 8.0, "damage": 25, "gain": 4, "force": 555.0, "style": BOLT}},
		{"id": "windup", "name": "과충전 볼트", "cd": 10.8, "help": "방향을 고정하고 0.65초 충전\n피격 시 발사 취소", "upgrade": "피해와 넉백 증가",
			"shot": {"speed": 660.0, "size": 9.0, "damage": 70, "gain": 8, "force": 590.0, "style": BOLT}},
		{"id": "swap", "name": "교대 탄", "cd": 11.5, "help": "탄이 상대를 맞히면\n서로 위치를 바꾸고 관성 제거", "upgrade": "명중 피해 증가",
			"shot": {"speed": 490.0, "size": 7.0, "damage": 5, "gain": 2, "force": 0.0, "style": DISC, "proc": SWAP}},
		{"id": "jam", "name": "회로 교란탄", "cd": 10.8, "help": "굵은 고속탄으로 적의 스킬 봉쇄\n이동과 기본 공격은 가능", "upgrade": "피해와 교란 지속 시간 증가",
			"shot": {"speed": 680.0, "size": 11.0, "damage": 24, "gain": 4, "force": 165.0, "style": BOLT, "proc": JAM}},
		{"id": "impact_burst", "name": "충격 기폭", "cd": 11.8, "help": "조준 지점에 지연 폭발\n충격이 높은 적에게 최대 18 추가 피해", "upgrade": "기본 피해와 폭발 반경 증가"},
	]},
	{"key": "F", "name": "유틸리티", "color": Color("#f7dc72"), "price": 105, "options": [
		{"id": "guard", "name": "고정장", "cd": 7.5, "help": "잠시 받는 넉백 70% 감소", "upgrade": "지속 시간 증가"},
		{"id": "repair", "name": "응급 수리", "cd": 11.5, "help": "즉시 체력 16 회복", "upgrade": "회복량 증가"},
		{"id": "cleanse", "name": "충격 정화", "cd": 9.0, "help": "충격 32%p 제거\n현재 넉백 감소", "upgrade": "제거하는 충격량 증가"},
		{"id": "reflect", "name": "반사막", "cd": 10.8, "help": "짧은 시간 첫 투사체 반사\n반사된 탄은 피해 감소", "upgrade": "반사 대기 시간 증가"},
		{"id": "anchor", "name": "회귀 앵커", "cd": 11.0, "help": "현재 위치를 표시\n2초 안에 F 재입력으로 복귀", "upgrade": "복귀 가능 시간 증가"},
		{"id": "surge", "name": "가속 저장기", "cd": 9.2, "help": "준비 중 피격되면\n잠시 이동속도 24% 증가", "upgrade": "가속 지속 시간 증가"},
		{"id": "mirror", "name": "잔상 편대", "cd": 10.4, "help": "움직임을 따라 하는 분신 둘\n각각 탄 한 발에 사라짐", "upgrade": "분신 지속 시간 증가"},
		{"id": "brake", "name": "관성 제동", "cd": 9.6, "help": "현재 넉백을 즉시 멈추고\n잠시 받는 넉백을 줄임", "upgrade": "넉백 저항 지속 시간 증가"},
	]},
	{"key": "Space", "name": "이동기", "color": Color("#79bcff"), "price": 135, "options": [
		{"id": "dash", "name": "점멸 추진", "cd": 4.4, "help": "조준 방향으로 빠르게 돌진\n재사용 대기시간이 짧음", "upgrade": "돌진 거리 증가"},
		{"id": "recover", "name": "긴급 복귀", "cd": 7.6, "help": "경기장 안쪽으로 추진\n장외에서는 더 멀리 이동", "upgrade": "추진 거리 증가"},
		{"id": "tackle", "name": "몸통박치기", "cd": 8.4, "help": "빠르게 부딪힐수록 강함\n피격 시 박치기 중단", "upgrade": "피해와 돌진 거리 증가"},
		{"id": "double", "name": "이중 도약", "cd": 8.1, "help": "짧게 돌진한 뒤 0.9초 안에\nSpace로 방향을 바꿔 재돌진", "upgrade": "두 돌진의 이동 거리 증가"},
		{"id": "cloak", "name": "은폐 질주", "cd": 9.8, "help": "은신·이동속도 22% 증가\n첫 적 충돌 시 피해·넉백 후 해제", "upgrade": "은신 지속 시간 증가"},
		{"id": "backstep", "name": "후방 도약", "cd": 4.0, "help": "짧은 재사용 대기시간\n조준 반대 방향으로 짧게 도약", "upgrade": "도약 거리 증가"},
	]},
	{"key": "", "name": "장비", "color": Color("#adf097"), "options": [
		{"id": "coil", "name": "절연 코일", "price": 90, "outside": 0.75, "help": "장외 피해 25% 감소"},
		{"id": "capsule", "name": "비상 캡슐", "price": 110, "emergency": true, "help": "라운드 첫 장외 진입 시\n2.5초간 장외 피해 60% 감소"},
		{"id": "light", "name": "경량 프레임", "price": 115, "walk": 1.12, "knockback": 1.20, "help": "이동속도 12% 증가\n받는 넉백 20% 증가"},
		{"id": "heavy_frame", "name": "중량 프레임", "price": 120, "knockback": 0.82, "shot_speed": 0.85, "help": "받는 넉백 18% 감소\n투사체 속도 15% 감소"},
		{"id": "damper", "name": "충격 완충기", "price": 105, "impact": 0.80, "walk": 0.95, "help": "피격 시 충격 누적 20% 감소\n이동속도 5% 감소"},
		{"id": "mantle", "name": "재생 망토", "price": 115, "regen": 1.5, "help": "피격 3초 후 안전선 안에서\n초당 체력 1.5 회복"},
		{"id": "warden", "name": "완충 흉갑", "price": 125, "damage_offset": -2, "help": "주고받는 직접 피해 2 감소\n타격당 최소 피해 1"},
		{"id": "siphon", "name": "흡수 가면", "price": 130, "lifesteal": 0.20, "incoming": 1.10, "help": "입힌 직접 피해의 20% 회복\n받는 직접 피해 10% 증가"},
		{"id": "shield_cell", "name": "차폐 전지", "price": 140, "help": "라운드 첫 피격의 직접 피해\n및 넉백을 40% 감소"},
		{"id": "accelerator", "name": "가속 총열", "price": 110, "shot_speed": 1.18, "walk": 0.94,
			"help": "투사체 속도 18% 증가\n이동속도 6% 감소"},
		{"id": "recharge", "name": "재충전 모듈", "price": 125, "utility_cooldown": 0.86,
			"help": "F와 Space 스킬의\n재사용 대기시간 14% 감소"},
		{"id": "stabilizer", "name": "자세 안정기", "price": 120, "kick_decay": 1.20,
			"help": "피격 넉백 속도가\n20% 더 빠르게 감소"},
	]},
]

static func level_cap(slot: int) -> int:
	return 1 if slot == GEAR else 3

static func shop_slot_open(round_no: int, slot: int) -> bool:
	return round_no != 1 or slot in [Q, GEAR]

static func cast_delay(slot: int, choice: int) -> float:
	if slot == E and skill(slot, choice).id == "repel":
		return REPEL_WINDUP
	if slot == R and skill(slot, choice).id == "windup":
		return 0.65
	return [0.10, 0.14, AREA_WINDUP, 0.20, 0.0, 0.0][slot]

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

static func equipment_amount(player: Dictionary, stat: String) -> float:
	var amount := 0.0
	for choice: int in player.get("equipment", []):
		amount += skill(GEAR, choice).get(stat, 0.0)
	return amount

static func resale(choice: int) -> int:
	return floori(price(GEAR, 0, choice) * 0.5)

static func cooldown(slot: int, choice: int, level: int, player: Dictionary = {}) -> float:
	var data := skill(slot, choice)
	var reduction: float = data.get("cd_per_level", 0.33 if slot == MOVE else 0.09)
	var seconds: float = data.cd - (level - 1) * reduction
	return seconds * equipment_factor(player, "utility_cooldown") if slot in [F, MOVE] else seconds

static func attack_damage(base_damage: int) -> int:
	return roundi(base_damage * ATTACK_DAMAGE_SCALE)

static func half_side_at(elapsed: float) -> float:
	var progress := clampf(inverse_lerp(SHRINK_START, SHRINK_END, elapsed), 0.0, 1.0)
	return lerpf(HALF_SIDE, FINAL_HALF_SIDE, progress)

static func square_extent(point: Vector2) -> float:
	return maxf(absf(point.x), absf(point.y))

static func knockback_multiplier(impact: float) -> float:
	var progress := clampf(impact / MAX_IMPACT, 0.0, 1.0)
	return lerpf(2.30, 3.70, progress)

static func knockback_decay(health: float) -> float:
	var low_health := clampf(inverse_lerp(60.0, 15.0, health), 0.0, 1.0)
	return lerpf(KNOCKBACK_DECAY, LOW_HEALTH_KNOCKBACK_DECAY, low_health)

static func award(rank: int, last_place: bool) -> int:
	return 130 if last_place else maxi(135, 145 - (rank - 1) * 5)
