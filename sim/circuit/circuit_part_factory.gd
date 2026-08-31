class_name CircuitPartFactory
extends RefCounted

## 블록 종류에서 부품 알맹이를 만든다.
##
## 부품이 스스로를 만들면 부품끼리 서로를 알아야 해서 얽힌다. 만드는 곳을
## 한 군데로 모아 둔다.


static func create(part_type: int, at: Vector3i, values: PackedInt32Array) -> CircuitPart:
    var part := _bare(part_type, at)
    if part == null:
        return null
    part.position = at
    part.configure(values)
    return part


static func _bare(part_type: int, at: Vector3i) -> CircuitPart:
    if part_type == BlockType.DETECTOR:
        return DetectorPart.create(at, DetectorPart.TARGET_PLAYER)
    if part_type == BlockType.ACTUATOR:
        return ActuatorPart.create(at)
    if part_type == BlockType.REPEATER:
        return RepeaterPart.create(at)
    if part_type == BlockType.BOX:
        return BoxPart.create(at)
    return null
