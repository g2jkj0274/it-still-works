class_name Circuit
extends RefCounted

## 월드에 놓인 회로 부품과 그 사이의 배선.
##
## 부품과 배선은 항상 정해진 차례로 늘어놓는다. 순회 순서가 흔들리면 신호가
## 실행마다 다르게 흐른다.
##
## 한 틱에 부품 하나씩 신호가 나아간다. 계산과 반영을 갈라 두어서 그렇다.

var _parts: Array[CircuitPart] = []

## 배선. 각 항목은 [출발 칸, 도착 칸] 이다.
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


func link(from: Vector3i, to: Vector3i) -> bool:
    if from == to or not has_part(from) or not has_part(to):
        return false
    if is_linked(from, to):
        return false
    _links.append([from, to])
    _links.sort_custom(_link_before)
    return true


func unlink(from: Vector3i, to: Vector3i) -> bool:
    for i in _links.size():
        if _links[i][0] == from and _links[i][1] == to:
            _links.remove_at(i)
            return true
    return false


func is_linked(from: Vector3i, to: Vector3i) -> bool:
    for link: Array in _links:
        if link[0] == from and link[1] == to:
            return true
    return false


## 한 틱 진행한다.
##
## 모든 부품이 지금 흐르는 신호만 보고 다음 신호를 정한 뒤, 한꺼번에 반영한다.
## 그래서 신호가 한 틱에 한 부품씩만 나아간다.
func tick(state: WorldState) -> void:
    for part in _parts:
        part.compute(state, _incoming(part.position))
    for part in _parts:
        part.commit()
    for part in _parts:
        part.act(state)


func to_hash_fields() -> Array:
    var fields: Array = [["circuit.parts", _parts.size()], ["circuit.links", _links.size()]]
    for part in _parts:
        fields.append_array(part.to_hash_fields())
    for i in _links.size():
        var link: Array = _links[i]
        fields.append(["circuit.link.%d" % i, "%s>%s" % [link[0], link[1]]])
    return fields


## [param pos] 로 들어오는 신호들. 배선 차례대로다.
func _incoming(pos: Vector3i) -> Array:
    var values: Array = []
    for link: Array in _links:
        if link[1] != pos:
            continue
        var source := part_at(link[0])
        if source != null:
            values.append(source.output)
    return values


func _part_before(left: CircuitPart, right: CircuitPart) -> bool:
    return _cell_before(left.position, right.position)


func _link_before(left: Array, right: Array) -> bool:
    if left[0] != right[0]:
        return _cell_before(left[0], right[0])
    return _cell_before(left[1], right[1])


func _cell_before(left: Vector3i, right: Vector3i) -> bool:
    if left.x != right.x:
        return left.x < right.x
    if left.y != right.y:
        return left.y < right.y
    return left.z < right.z
