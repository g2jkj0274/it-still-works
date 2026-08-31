@abstract class_name SimCommand
extends RefCounted

## 월드 상태를 바꾸는 유일한 통로.
##
## 입력은 명령을 만들 뿐 월드를 직접 수정하지 않는다.
## 입력 → 명령 생성 → 명령 큐 → 시뮬레이션이 틱 단위로 소비. 이 경로만 허용한다.
##
## 명령은 직렬화 가능해야 한다. 나중에 lockstep 멀티플레이에서 그대로 전송된다.

## 이 명령을 실행할 틱.
var tick: int = 0

## 같은 틱에 접수된 명령들 사이의 정렬 키. [SimCommandQueue] 가 접수 순서대로 부여한다.
var order: int = 0


## 직렬화와 식별에 쓰이는 고유 종류 이름.
@abstract func get_type() -> StringName


## 상태를 바꾼다. 시뮬레이션이 틱 처리 중에만 호출한다.
@abstract func apply(state: WorldState) -> void


## 전송·저장 가능한 형태로 펼친다.
func to_dict() -> Dictionary:
    var data: Dictionary = {
        "type": String(get_type()),
        "tick": tick,
    }
    write_payload(data)
    return data


## 하위 클래스 고유 필드를 [param data] 에 채운다.
func write_payload(_data: Dictionary) -> void:
    pass


## 하위 클래스 고유 필드를 [param data] 에서 읽는다.
## JSON 을 거치면 수가 실수로 돌아오므로 여기서 정수로 되돌린다.
func read_payload(_data: Dictionary) -> void:
    pass
