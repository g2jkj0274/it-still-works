class_name SaveSlot
extends RefCounted

## 판 하나를 담아 두는 자리. 단일 슬롯이다(스펙 §6).
##
## **상태를 통째로 뜨지 않는다.** 시드와 명령 기록과 틱 수만 적는다. 불러올 때는
## 같은 시드로 섬을 세우고 같은 명령을 같은 차례로 넣은 뒤 그만큼 다시 돌린다.
##
## 이 게임의 뿌리 규칙이 "같은 시드 + 같은 명령 → 같은 상태"이므로(스펙 §2)
## 그 규칙 자체가 저장 형식이 된다. 스냅숏은 필드 하나만 빠뜨려도 조용히
## 어긋나지만, 이쪽은 규칙이 깨지면 결정론 회귀 테스트가 먼저 운다.
##
## 대가는 불러오는 데 걸리는 시간이다. 재어 보면 30분 분량이 281ms 다. 판이
## 아주 길어져 이것이 거슬리면 그때 스냅숏을 얹는다. 그때도 이 기록은
## 남겨 두는 편이 낫다. 어긋났을 때 견줄 것이 있어야 한다.

const PATH := "user://save.json"

## 적어 둔 형식의 판. 규칙이 바뀌면 올린다. 모르는 판은 불러오지 않는다.
const VERSION := 1


static func has_save() -> bool:
    return FileAccess.file_exists(PATH)


static func clear() -> void:
    if has_save():
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## 지금 판을 적어 둔다. 적지 못하면 false.
static func save(simulation: Simulation) -> bool:
    if simulation == null:
        return false

    var file := FileAccess.open(PATH, FileAccess.WRITE)
    if file == null:
        return false

    file.store_string(JSON.stringify(to_dict(simulation)))
    file.close()
    return true


## 적어 둔 판을 되살린다. 없거나 읽을 수 없으면 null.
static func restore() -> Simulation:
    if not has_save():
        return null

    var file := FileAccess.open(PATH, FileAccess.READ)
    if file == null:
        return null

    var text := file.get_as_text()
    file.close()
    return from_text(text)


static func to_dict(simulation: Simulation) -> Dictionary:
    return {
        "version": VERSION,
        "seed": simulation.state.rng.get_seed(),
        "tick": simulation.state.tick,
        "commands": simulation.command_log(),
    }


## 적어 둔 글에서 판을 되살린다. 형식이 어긋나면 null.
static func from_text(text: String) -> Simulation:
    var parsed: Variant = JSON.parse_string(text)
    if not (parsed is Dictionary):
        return null
    return from_dict(parsed)


static func from_dict(data: Dictionary) -> Simulation:
    if int(data.get("version", 0)) != VERSION:
        return null

    var simulation := IslandBuilder.start(int(data.get("seed", 0)))

    # 명령을 먼저 다 넣고 나서 돌린다. 적힌 틱이 그대로 실행될 틱이 된다.
    for entry in data.get("commands", []) as Array:
        if not (entry is Dictionary):
            continue
        var command := SimCommandCodec.from_dict(entry)
        if command == null:
            # 모르는 명령을 조용히 건너뛰면 그 뒤가 전부 어긋난다.
            return null
        simulation.submit_at(command, int((entry as Dictionary).get("tick", 0)))

    simulation.advance(int(data.get("tick", 0)))
    return simulation
