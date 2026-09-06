class_name ChestField
extends RefCounted

## 월드에 놓인 궤짝들과 그 안에 든 것.
##
## 궤짝은 격자에 놓인 블록이고, 그 안은 여기서 들고 있는다. 격자는 종류만
## 담을 수 있어서 무엇이 얼마나 들었는지까지는 담지 못한다.
##
## 자리 순으로 늘어놓는다. 순회 순서가 흔들리면 상태 해시가 흔들린다.
##
## **손이 모자라야 왕복에 값이 붙는다.** 그런데 넣어 둘 곳이 없으면 그건
## 살림이 아니라 짜증이다. 궤짝이 그 짝이다.

## 궤짝 하나에 든 칸 수.
const CHEST_SLOTS := 27

var _cells: Array[Vector3i] = []
var _holds: Array[Inventory] = []


func count() -> int:
    return _cells.size()


func cells() -> Array[Vector3i]:
    return _cells.duplicate()


func has_chest(cell: Vector3i) -> bool:
    return _cells.has(cell)


## 그 자리의 궤짝 안. 없으면 null.
func inside(cell: Vector3i) -> Inventory:
    var at := _cells.find(cell)
    if at < 0:
        return null
    return _holds[at]


## 궤짝을 놓는다. 이미 있으면 아무 일도 하지 않는다.
func place(cell: Vector3i) -> bool:
    if has_chest(cell):
        return false
    _cells.append(cell)
    _holds.append(Inventory.new(CHEST_SLOTS))
    _sort()
    return true


## 궤짝을 걷어낸다. 안에 든 것이 있으면 걷어내지 못한다.
##
## 부수면 안의 것이 조용히 사라지는 편이 나쁘다. 비우고 나서 부순다.
func remove(cell: Vector3i) -> bool:
    var at := _cells.find(cell)
    if at < 0 or _holds[at].total() > 0:
        return false
    _cells.remove_at(at)
    _holds.remove_at(at)
    return true


## 안에 든 것이 있는가.
func is_empty(cell: Vector3i) -> bool:
    var held := inside(cell)
    return held == null or held.total() <= 0


func to_hash_fields() -> Array:
    var fields: Array = [["chests.count", _cells.size()]]
    for i in _cells.size():
        var key := "chest.%d" % i
        fields.append([key + ".at", str(_cells[i])])
        for field: Array in _holds[i].to_hash_fields():
            fields.append(["%s.%s" % [key, field[0]], field[1]])
    return fields


func _sort() -> void:
    var order: Array[int] = []
    for i in _cells.size():
        order.append(i)
    order.sort_custom(func(left: int, right: int) -> bool:
        return Circuit.cell_before(_cells[left], _cells[right]))

    var cells: Array[Vector3i] = []
    var holds: Array[Inventory] = []
    for i in order:
        cells.append(_cells[i])
        holds.append(_holds[i])
    _cells = cells
    _holds = holds
