class_name Circuit
extends RefCounted

## 월드에 놓인 회로 부품과 그 사이의 배선.
##
## 부품과 배선은 항상 정해진 차례로 늘어놓는다. 순회 순서가 흔들리면 신호가
## 실행마다 다르게 흐른다.
##
## 한 틱에 부품 하나씩 신호가 나아간다. 계산과 반영을 갈라 두어서 그렇다.

var _parts: Array[CircuitPart] = []

## 배선. 각 항목은 [출발 칸, 도착 칸, 출구 번호] 이다.
##
## 출구 번호는 출발 부품의 어느 구멍에서 나오는지를 가리킨다. 갈림길만 구멍이
## 둘이고 나머지는 0번 하나뿐이다.
var _links: Array = []


func part_count() -> int:
    return _parts.size()


func link_count() -> int:
    return _links.size()


## 위치 순으로 늘어놓은 부품들. 읽기용 사본이다.
func parts() -> Array[CircuitPart]:
    return _parts.duplicate()


func links() -> Array:
    return _links.duplicate(true)


func part_at(pos: Vector3i) -> CircuitPart:
    for part in _parts:
        if part.position == pos:
            return part
    return null


func has_part(pos: Vector3i) -> bool:
    return part_at(pos) != null


func add_part(part: CircuitPart) -> bool:
    if part == null or has_part(part.position):
        return false
    _parts.append(part)
    _parts.sort_custom(_part_before)
    return true


## 부품을 걷어내면 거기 이어진 배선도 함께 사라진다.
func remove_part(pos: Vector3i) -> bool:
    var part := part_at(pos)
    if part == null:
        return false

    _parts.erase(part)
    var kept: Array = []
    for link: Array in _links:
        if link[0] != pos and link[1] != pos:
            kept.append(link)
    _links = kept
    return true


func link(from: Vector3i, to: Vector3i, port: int = 0) -> bool:
    if from == to or not has_part(from) or not has_part(to):
        return false
    if port < 0 or port >= part_at(from).output_count():
        return false
    if is_linked(from, to, port):
        return false
    _links.append([from, to, port])
    _links.sort_custom(_link_before)
    return true


func unlink(from: Vector3i, to: Vector3i, port: int = 0) -> bool:
    for i in _links.size():
        if _links[i][0] == from and _links[i][1] == to and _links[i][2] == port:
            _links.remove_at(i)
            return true
    return false


func is_linked(from: Vector3i, to: Vector3i, port: int = 0) -> bool:
    for link: Array in _links:
        if link[0] == from and link[1] == to and link[2] == port:
            return true
    return false


## 한 틱 진행한다.
##
## 모든 부품이 지금 흐르는 신호만 보고 다음 신호를 정한 뒤, 한꺼번에 반영한다.
## 그래서 신호가 한 틱에 한 부품씩만 나아간다.
##
## [param external] 은 배선이 아니라 바깥에서 들어오는 신호다. 바깥에서
## 안쪽 회로를 돌릴 때 쓴다. 항목은 [닿는 칸, 신호] 이고 순서가 있다.
func tick(state: WorldState, external: Array = []) -> void:
    tick_compute(state, external)
    tick_commit()
    tick_act(state)


## 계산만 한다. 부품이 내보내는 신호는 아직 바뀌지 않는다.
func tick_compute(state: WorldState, external: Array = []) -> void:
    for part in _parts:
        part.compute(state, _incoming(part.position, external))


## 계산해 둔 신호를 한꺼번에 내보낸다.
func tick_commit() -> void:
    for part in _parts:
        part.commit()


## 세상을 바꾼다.
func tick_act(state: WorldState) -> void:
    for part in _parts:
        part.act(state)


func to_hash_fields() -> Array:
    var fields: Array = [["circuit.parts", _parts.size()], ["circuit.links", _links.size()]]
    for part in _parts:
        fields.append_array(part.to_hash_fields())
    for i in _links.size():
        var link: Array = _links[i]
        fields.append(["circuit.link.%d" % i, "%s>%s@%d" % [link[0], link[1], link[2]]])
    return fields


## [param pos] 로 들어오는 신호들.
##
## 바깥에서 들어오는 것이 먼저고 배선을 타고 오는 것이 그 다음이다.
## 둘 다 순서가 정해져 있어야 실행마다 같은 쪽이 이긴다.
func _incoming(pos: Vector3i, external: Array = []) -> Array:
    var values: Array = []
    for entry: Array in external:
        if entry[0] == pos:
            values.append(entry[1])
    for link: Array in _links:
        if link[1] != pos:
            continue
        var source := part_at(link[0])
        if source != null:
            values.append(source.output_at(link[2]))
    return values


## 칸의 정해진 차례. 순회 순서가 흔들리지 않게 한 곳에서만 정한다.
static func cell_before(left: Vector3i, right: Vector3i) -> bool:
    if left.x != right.x:
        return left.x < right.x
    if left.y != right.y:
        return left.y < right.y
    return left.z < right.z


func _part_before(left: CircuitPart, right: CircuitPart) -> bool:
    return cell_before(left.position, right.position)


func _link_before(left: Array, right: Array) -> bool:
    if left[0] != right[0]:
        return cell_before(left[0], right[0])
    if left[1] != right[1]:
        return cell_before(left[1], right[1])
    return left[2] < right[2]
