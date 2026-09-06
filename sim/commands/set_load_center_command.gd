class_name SetLoadCenterCommand
extends SimCommand

## 로드 중심 목표(청크 좌표)를 상태에 적는다.
##
## 청크 로드·언로드 자체는 하지 않는다 — `chunks.set_center` 는 Simulation.step() 의
## 동기화 단계만 부른다. M1-6 에서 플레이어 위치가 이 명령을 대신하기 전까지의 발판.

const TYPE := &"set_load_center"

var cx: int = 0
var cy: int = 0


static func create(p_cx: int, p_cy: int) -> SetLoadCenterCommand:
    var command := SetLoadCenterCommand.new()
    command.cx = p_cx
    command.cy = p_cy
    return command


func get_type() -> StringName:
    return TYPE


func apply(state: WorldState) -> void:
    state.load_center = Vector2i(cx, cy)
    state.has_load_center = true


func write_payload(data: Dictionary) -> void:
    data["cx"] = cx
    data["cy"] = cy


func read_payload(data: Dictionary) -> void:
    cx = int(data.get("cx", 0))
    cy = int(data.get("cy", 0))
