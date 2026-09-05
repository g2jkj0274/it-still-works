class_name SoundBoard
extends Node

## 소리를 낸다.
##
## **시뮬레이션은 소리를 모른다.** 여기서 하는 일은 상태를 보고 있다가 바뀐
## 것을 발견하면 울리는 것이다. 시뮬레이션에서 재생 함수를 부르면 그 순간
## 헤드리스 단독 실행이 깨진다(스펙 §2-4).
##
## 그래서 "명령을 넣었으니 울린다"가 아니라 **"세상이 실제로 바뀌었으니
## 울린다"** 이다. 재료가 없어 못 놓았으면 소리도 나지 않는다.
##
## **무엇이 바뀌었는지는 격자에게 직접 묻는다.** 손에 든 것의 총량이 늘고
## 줄었는지로 짐작하던 때에는, 밭을 거두어도 곡괭이 소리가 나고 무언가를
## 만들어도 널빤지 놓는 소리가 겹쳤다. 화면과 소리가 다른 것을 말했다.
##
## 소리는 나는 자리에서 난다. 섬 반대편 회로가 발밑과 같은 크기로 들리면
## 어디서 무슨 일이 나는지 알 수 없다.
##
## 소리는 Kenney (CC0). `assets/kenney_audio/README.md` 참조.

const DIR := "res://assets/kenney_audio/"

## 한 번에 겹쳐 낼 수 있는 소리의 수. 모자라면 가장 오래된 것을 끊는다.
const VOICES := 8

## 자리를 가진 소리가 들리는 거리(칸).
const EARSHOT := 26.0

## 갈래별 소리와 크기(dB). 크기는 서로 묻히지 않게 손으로 맞췄다.
const SOUNDS: Dictionary[StringName, Array] = {
    &"break": ["impactMining_000.ogg", -4.0],
    &"place": ["impactPlank_medium_000.ogg", -6.0],
    &"step_a": ["footstep_grass_000.ogg", -16.0],
    &"step_b": ["footstep_grass_002.ogg", -16.0],
    &"door_open": ["doorOpen_1.ogg", -6.0],
    &"door_close": ["doorClose_1.ogg", -6.0],
    &"lamp": ["pluck_001.ogg", -12.0],
    &"link": ["pluck_001.ogg", -6.0],
    &"signal": ["tick_002.ogg", -20.0],
    &"craft": ["confirmation_002.ogg", -8.0],
    &"burn": ["impactMetal_heavy_000.ogg", -3.0],
    &"hurt": ["impactPunch_medium_000.ogg", -3.0],
    &"eat": ["handleSmallLeather.ogg", -8.0],
    &"chime": ["bong_001.ogg", -10.0],
}

var _simulation: Simulation
var _players: Array[AudioStreamPlayer] = []
var _placed: Array[AudioStreamPlayer3D] = []
var _next_voice: int = 0
var _next_placed: int = 0
var _played: Array[StringName] = []
var _watching: bool = false

var _seen_version: int = 0
var _last_cell: Vector3i = Vector3i.ZERO
var _last_burnt: int = 0
var _last_health: int = 0
var _last_fullness: int = 0
var _last_night: bool = false
var _last_links: int = 0
var _step_flip: bool = false

## 배선마다 지금 흐르고 있는지. 총 개수가 아니라 하나하나를 들고 있어야
## 하나 켜지고 하나 꺼지는 순간에도 소리가 난다.
var _live: Dictionary[String, bool] = {}


func _ready() -> void:
    for i in VOICES:
        var player := AudioStreamPlayer.new()
        player.name = "Voice_%d" % i
        add_child(player)
        _players.append(player)

        var placed := AudioStreamPlayer3D.new()
        placed.name = "Placed_%d" % i
        placed.max_distance = EARSHOT
        add_child(placed)
        _placed.append(placed)


func bind(simulation: Simulation) -> void:
    _simulation = simulation
    _watching = false
    _live.clear()


## 한 소리를 낸다. 갈래를 모르면 아무 일도 하지 않는다.
func play(kind: StringName) -> void:
    _played.append(kind)
    var stream := _stream_of(kind)
    if stream == null or _players.is_empty():
        return

    var player := _players[_next_voice]
    _next_voice = (_next_voice + 1) % _players.size()
    player.stream = stream
    player.volume_db = float(SOUNDS[kind][1])
    player.play()


## 그 칸에서 나는 소리. 멀면 작게 들린다.
func play_at(kind: StringName, cell: Vector3i) -> void:
    _played.append(kind)
    var stream := _stream_of(kind)
    if stream == null or _placed.is_empty():
        return

    var player := _placed[_next_placed]
    _next_placed = (_next_placed + 1) % _placed.size()
    player.stream = stream
    player.volume_db = float(SOUNDS[kind][1])
    player.position = SimViewCoords.cell_to_world(cell)
    player.play()


## 이번 프레임에 울린 것들. 테스트가 읽는다.
func played() -> Array[StringName]:
    return _played.duplicate()


func forget() -> void:
    _played.clear()


## 상태를 보고 바뀐 것을 울린다. 표현 레이어의 프레임 루프에서 부른다.
func sync() -> void:
    if _simulation == null:
        return

    var state := _simulation.state
    if not _watching:
        # 처음 붙는 판에서는 아무것도 울리지 않는다. 견줄 앞이 없다.
        _remember(state)
        _watching = true
        return

    for change: Array in state.grid.changes_since(_seen_version):
        _sound_for(change[0], int(change[1]), int(change[2]))

    if state.vitals.health < _last_health:
        play(&"hurt")
    if state.vitals.fullness > _last_fullness:
        play(&"eat")
    if _count_burnt(state) > _last_burnt:
        play(&"burn")
    if state.circuit.link_count() > _last_links:
        play(&"link")
    if DayCycle.is_night(state.tick) != _last_night:
        play(&"chime")

    _sound_for_signals(state)

    var cell := state.character.cell()
    if cell != _last_cell:
        play_at(&"step_a" if _step_flip else &"step_b", cell)
        _step_flip = not _step_flip

    _remember(state)


## 칸 하나가 달라졌을 때 나는 소리.
func _sound_for(cell: Vector3i, was: int, now: int) -> void:
    if BlockType.is_door(was) and BlockType.is_door(now):
        play_at(&"door_open" if now == BlockType.DOOR_OPEN else &"door_close", cell)
        return
    if BlockType.is_lamp(was) and BlockType.is_lamp(now):
        play_at(&"lamp", cell)
        return
    if now == BlockType.EMPTY and was != BlockType.EMPTY:
        play_at(&"break", cell)
        return
    if was == BlockType.EMPTY and now != BlockType.EMPTY:
        play_at(&"place", cell)


## 배선마다 꺼짐에서 켜짐으로 넘어간 순간을 잡는다.
##
## 흐르는 배선의 총 개수만 보면, 하나 켜지고 하나 꺼지는 순간은 조용하고
## 계속 켜져 있는 회로는 처음 한 번 울고 영영 조용하다. 신호가 부품을 지날
## 때 나는 소리가 이 장르의 정체성이라고 스펙이 적어 두었다.
func _sound_for_signals(state: WorldState) -> void:
    var seen: Dictionary[String, bool] = {}
    for link: Array in state.circuit.links():
        var key := "%s>%s@%d" % [link[0], link[1], link[2]]
        seen[key] = true

        var source := state.circuit.part_at(link[0])
        var live := source != null and source.output_at(link[2]).is_present()
        if live and not _live.get(key, false):
            play_at(&"signal", link[1])
        _live[key] = live

    for key in _live.keys():
        if not seen.has(key):
            _live.erase(key)


## 만들었다는 것을 따로 알린다. 세상이 아니라 손이 바뀌는 일이다.
func note_crafted() -> void:
    play(&"craft")


func _stream_of(kind: StringName) -> AudioStream:
    if not SOUNDS.has(kind):
        return null
    return load(DIR + String(SOUNDS[kind][0]))


func _remember(state: WorldState) -> void:
    _seen_version = state.grid.version()
    _last_cell = state.character.cell()
    _last_burnt = _count_burnt(state)
    _last_links = state.circuit.link_count()
    _last_health = state.vitals.health
    _last_fullness = state.vitals.fullness
    _last_night = DayCycle.is_night(state.tick)


func _count_burnt(state: WorldState) -> int:
    var burnt := 0
    for part in state.circuit.parts():
        if part is RepeaterPart and (part as RepeaterPart).is_burnt():
            burnt += 1
    return burnt
