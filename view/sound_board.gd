class_name SoundBoard
extends Node

## 소리를 낸다.
##
## **시뮬레이션은 소리를 모른다.** 여기서 하는 일은 상태를 보고 있다가 바뀐
## 것을 발견하면 울리는 것이다. 시뮬레이션에서 재생 함수를 부르면 그 순간
## 헤드리스 단독 실행이 깨진다(스펙 §2-4).
##
## 그래서 "명령을 넣었으니 울린다"가 아니라 **"세상이 실제로 바뀌었으니
## 울린다"** 이다. 재료가 없어 못 놓았으면 소리도 나지 않는다. 화면과 소리가
## 같은 것을 말한다.
##
## 스펙 §8 이 판정 지점으로 잡은 "조작감"의 절반이 소리다. 나무를 부수는 것이
## 이 게임의 첫 30초인데 그동안 갈색 기둥 한 칸이 조용히 사라질 뿐이었다.
##
## 소리는 Kenney (CC0). `assets/kenney_audio/README.md` 참조.

const DIR := "res://assets/kenney_audio/"

## 한 번에 겹쳐 낼 수 있는 소리의 수. 모자라면 가장 오래된 것을 끊는다.
const VOICES := 8

## 갈래별 소리와 크기(dB). 크기는 서로 묻히지 않게 손으로 맞췄다.
const SOUNDS: Dictionary[StringName, Array] = {
    &"break": ["impactMining_000.ogg", -4.0],
    &"place": ["impactPlank_medium_000.ogg", -6.0],
    &"step_a": ["footstep_grass_000.ogg", -16.0],
    &"step_b": ["footstep_grass_002.ogg", -16.0],
    &"door_open": ["doorOpen_1.ogg", -6.0],
    &"door_close": ["doorClose_1.ogg", -6.0],
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
var _next_voice: int = 0
var _played: Array[StringName] = []
var _watching: bool = false

var _last_stock: int = 0
var _last_cell: Vector3i = Vector3i.ZERO
var _last_open_doors: int = 0
var _last_live_wires: int = 0
var _last_burnt: int = 0
var _last_health: int = 0
var _last_fullness: int = 0
var _last_night: bool = false
var _last_links: int = 0
var _step_flip: bool = false


func _ready() -> void:
    for i in VOICES:
        var player := AudioStreamPlayer.new()
        player.name = "Voice_%d" % i
        add_child(player)
        _players.append(player)


func bind(simulation: Simulation) -> void:
    _simulation = simulation
    _watching = false


## 한 소리를 낸다. 갈래를 모르면 아무 일도 하지 않는다.
func play(kind: StringName) -> void:
    _played.append(kind)
    if not SOUNDS.has(kind) or _players.is_empty():
        return

    var entry: Array = SOUNDS[kind]
    var stream: AudioStream = load(DIR + String(entry[0]))
    if stream == null:
        return

    var player := _players[_next_voice]
    _next_voice = (_next_voice + 1) % _players.size()
    player.stream = stream
    player.volume_db = float(entry[1])
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
    var stock := state.inventory.total()
    var cell := state.character.cell()
    var open_doors := _count_open_doors(state)
    var live := _count_live_wires(state)
    var burnt := _count_burnt(state)
    var links := state.circuit.link_count()
    var night := DayCycle.is_night(state.tick)

    if not _watching:
        # 처음 붙는 판에서는 아무것도 울리지 않는다. 견줄 앞이 없다.
        _remember(stock, cell, open_doors, live, burnt, links, state, night)
        _watching = true
        return

    if state.vitals.health < _last_health:
        play(&"hurt")
    if state.vitals.fullness > _last_fullness:
        play(&"eat")
    if open_doors > _last_open_doors:
        play(&"door_open")
    elif open_doors < _last_open_doors:
        play(&"door_close")
    if burnt > _last_burnt:
        play(&"burn")
    if links > _last_links:
        play(&"link")
    if night != _last_night:
        play(&"chime")
    if live > _last_live_wires:
        play(&"signal")

    _sound_for_stock(stock)
    if cell != _last_cell:
        play(&"step_a" if _step_flip else &"step_b")
        _step_flip = not _step_flip

    _remember(stock, cell, open_doors, live, burnt, links, state, night)


## 손에 든 것이 늘었는지 줄었는지로 부순 것과 놓은 것을 가른다.
##
## 만든 것은 재료가 줄고 만든 것이 느는데, 드는 재료가 하나보다 많으므로
## 손에 든 총량이 준다. 그래서 놓은 것과 겹치지 않는다.
func _sound_for_stock(stock: int) -> void:
    if stock > _last_stock:
        play(&"break")
    elif stock < _last_stock:
        play(&"place")


## 만들었다는 것을 따로 알린다. 명령이 아니라 결과를 보고 부른다.
func note_crafted() -> void:
    play(&"craft")


func _remember(
    stock: int, cell: Vector3i, open_doors: int, live: int, burnt: int,
    links: int, state: WorldState, night: bool
) -> void:
    _last_stock = stock
    _last_cell = cell
    _last_open_doors = open_doors
    _last_live_wires = live
    _last_burnt = burnt
    _last_links = links
    _last_health = state.vitals.health
    _last_fullness = state.vitals.fullness
    _last_night = night


func _count_open_doors(state: WorldState) -> int:
    var open := 0
    for part in state.circuit.parts():
        if part.kind() != BlockType.ACTUATOR:
            continue
        for offset in VoxelGrid.NEIGHBOURS:
            if state.grid.get_block(part.anchor + offset) == BlockType.DOOR_OPEN:
                open += 1
    return open


func _count_live_wires(state: WorldState) -> int:
    var live := 0
    for link: Array in state.circuit.links():
        var source := state.circuit.part_at(link[0])
        if source != null and source.output_at(link[2]).is_present():
            live += 1
    return live


func _count_burnt(state: WorldState) -> int:
    var burnt := 0
    for part in state.circuit.parts():
        if part is RepeaterPart and (part as RepeaterPart).is_burnt():
            burnt += 1
    return burnt
