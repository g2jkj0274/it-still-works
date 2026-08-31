class_name SimCommandQueue
extends RefCounted

## 접수된 명령을 틱 단위로 내주는 큐.
##
## 소비 순서는 (실행 틱, 접수 순서) 로 완전히 정해진다.
## 접수 순서는 큐가 부여하는 단조 증가 정수라 두 명령이 같은 순위를 갖는 일이 없다.
## 따라서 정렬 결과는 정렬 알고리즘의 안정성과 무관하게 항상 같다.

var _pending: Array[SimCommand] = []
var _next_order: int = 0


## [param command] 를 [param at_tick] 에 실행하도록 접수한다.
## 접수한 명령을 그대로 돌려준다. null 은 무시하고 null 을 돌려준다.
func submit(command: SimCommand, at_tick: int) -> SimCommand:
    if command == null:
        return null
    command.tick = at_tick
    command.order = _next_order
    _next_order += 1
    _pending.append(command)
    return command


## [param tick] 까지 실행해야 할 명령을 순서대로 꺼낸다. 꺼낸 명령은 큐에서 사라진다.
##
## 이미 지나간 틱으로 접수된 명령도 함께 나온다. 버리면 접수한 입력이 조용히
## 사라져 재생과 실제 진행이 어긋나기 때문이다.
func take_due(tick: int) -> Array[SimCommand]:
    var due: Array[SimCommand] = []
    var rest: Array[SimCommand] = []
    for command in _pending:
        if command.tick <= tick:
            due.append(command)
        else:
            rest.append(command)

    _pending = rest
    due.sort_custom(_is_before)
    return due


func size() -> int:
    return _pending.size()


func is_empty() -> bool:
    return _pending.is_empty()


func clear() -> void:
    _pending.clear()


## (실행 틱, 접수 순서) 사전식 비교.
func _is_before(left: SimCommand, right: SimCommand) -> bool:
    if left.tick != right.tick:
        return left.tick < right.tick
    return left.order < right.order
