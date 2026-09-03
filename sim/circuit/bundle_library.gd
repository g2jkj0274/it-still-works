class_name BundleLibrary
extends RefCounted

## 이 월드에서 만들어진 묶음 설계도들.
##
## 번호는 만든 차례대로 0 부터 붙는다. 한 번 붙은 번호는 바뀌지 않는다.
## 인벤토리와 놓인 부품이 그 번호로 설계도를 찾는다.
##
## **묶음은 자기 자신을 품을 수 없다.** 새 묶음의 번호는 늘 지금까지 만든
## 어떤 것보다 크므로, 품고 있는 번호가 자기 번호보다 작기만 하면 된다.
## 그것만 지키면 묶음이 서로를 물고 도는 일 자체가 생기지 않는다.

var _blueprints: Array[BundleBlueprint] = []


## 설계도를 등록하고 번호를 돌려준다. 받을 수 없으면 -1.
func define(blueprint: BundleBlueprint) -> int:
    if blueprint == null or blueprint.part_count() == 0:
        return -1

    var id := _blueprints.size()
    for referenced in blueprint.references():
        if referenced < 0 or referenced >= id:
            return -1

    _blueprints.append(blueprint)
    return id


func count() -> int:
    return _blueprints.size()


func has(id: int) -> bool:
    return id >= 0 and id < _blueprints.size()


func blueprint_of(id: int) -> BundleBlueprint:
    if not has(id):
        return null
    return _blueprints[id]


## 묶음 안에 든 부품 수. 안에 든 묶음까지 펼쳐서 센다.
func total_parts_of(id: int) -> int:
    var blueprint := blueprint_of(id)
    if blueprint == null:
        return 0

    var total := 0
    for entry: Array in blueprint.parts():
        if int(entry[0]) != BlockType.BUNDLE:
            total += 1
            continue
        var values: PackedInt32Array = entry[2]
        total += total_parts_of(values[0] if values.size() > 0 else -1)
    return total


func to_hash_fields() -> Array:
    var fields: Array = [["bundles.count", _blueprints.size()]]
    for i in _blueprints.size():
        fields.append_array(_blueprints[i].to_hash_fields("bundle.%d" % i))
    return fields
