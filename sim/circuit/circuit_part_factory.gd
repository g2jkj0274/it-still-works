class_name CircuitPartFactory
extends RefCounted

## 블록 종류에서 부품 알맹이를 만든다.
##
## 부품이 스스로를 만들면 부품끼리 서로를 알아야 해서 얽힌다. 만드는 곳을
## 한 군데로 모아 둔다.
##
## 묶음만 설계도 목록을 함께 받아야 한다. 종류 번호만으로는 안에 무엇이
## 들었는지 알 수 없기 때문이다.


static func create(
    part_type: int,
    at: Vector3i,
    values: PackedInt32Array,
    library: BundleLibrary = null,
) -> CircuitPart:
    var part := _bare(part_type, at, library)
    if part == null:
        return null
    part.position = at
    part.configure(values)

    # 설계도를 찾지 못한 묶음은 부품이 되지 못한다.
    if part is BundlePart and not (part as BundlePart).is_filled():
        return null
    return part


static func _bare(part_type: int, at: Vector3i, library: BundleLibrary) -> CircuitPart:
    if part_type == BlockType.DETECTOR:
        return DetectorPart.create(at, DetectorPart.TARGET_PLAYER)
    if part_type == BlockType.ACTUATOR:
        return ActuatorPart.create(at)
    if part_type == BlockType.REPEATER:
        return RepeaterPart.create(at)
    if part_type == BlockType.BOX:
        return BoxPart.create(at)
    if part_type == BlockType.BRANCH:
        return BranchPart.create(at)
    if part_type == BlockType.BUNDLE:
        return BundlePart.create(at, library) if library != null else null
    return null
