class_name BundlePart
extends CircuitPart

## 묶음. 회로 하나를 통째로 담은 부품.
##
## 격자 한 칸을 차지한다. 안에 무엇이 들었는지는 밖에서 보이지 않는다.
## 배선도 밖에서 안으로 이어지지 않는다. 값은 정해 둔 들어오는 자리로만 들어가고
## 나가는 자리로만 나온다.
##
## **안쪽 상태는 놓인 것마다 따로다.** 같은 묶음을 열 개 놓으면 상자도 열 개다.
## 설계도는 하나를 나눠 보지만 굴러가는 것은 저마다의 것이다.
##
## 안쪽 회로도 한 틱에 한 부품씩 나아간다. 묶음이 한 틱을 더 먹지는 않는다.
## 신호가 들어온 그 틱에 안쪽 첫 부품까지 닿는다.
##
## 안에 든 감지기와 작동기는 **묶음이 놓인 칸**에서 세상을 만난다. 묶음은 한
## 칸짜리 부품이므로 그 안이 어디에 그려져 있었는지는 세상과 상관이 없다.

var bundle_id: int = -1

var _library: BundleLibrary = null
var _blueprint: BundleBlueprint = null
var _inner: Circuit = null
var _outputs: Array[SignalValue] = []


## 설계도를 아직 고르지 않은 빈 묶음. [method configure] 가 채운다.
static func create(at: Vector3i, library: BundleLibrary) -> BundlePart:
    var part := BundlePart.new()
    part.position = at
    part._library = library
    return part


func kind() -> int:
    return BlockType.BUNDLE


func parameters() -> PackedInt32Array:
    return PackedInt32Array([bundle_id])


func configure(values: PackedInt32Array) -> void:
    if values.size() >= 1:
        _adopt(values[0])


## 설계도를 골랐는가. 고르지 못한 묶음은 놓이지 않는다.
func is_filled() -> bool:
    return _inner != null


## 묶음 안에 든 부품 수. 화면에 몇 개짜리인지 보일 때 쓴다.
func inner_part_count() -> int:
    if _inner == null:
        return 0
    return _inner.part_count()


func pin_anchor(cell: Vector3i) -> void:
    super(cell)
    if _inner == null:
        return
    for part in _inner.parts():
        part.pin_anchor(cell)


func output_count() -> int:
    if _blueprint == null or _blueprint.output_count() == 0:
        return 1
    return _blueprint.output_count()


func output_at(port: int) -> SignalValue:
    if port < 0 or port >= _outputs.size():
        return SignalValue.none()
    return _outputs[port]


## 안에 타 버린 것이 하나라도 있으면 묶음째로 돌아오지 않는다.
func yields_material() -> bool:
    if _inner == null:
        return true
    for part in _inner.parts():
        if not part.yields_material():
            return false
    return true


func extra_hash_fields() -> Array:
    var fields: Array = [["bundle", bundle_id]]
    if _inner == null:
        return fields
    for field: Array in _inner.to_hash_fields():
        fields.append(["inner." + str(field[0]), field[1]])
    return fields


func compute(state: WorldState, incoming: Array) -> void:
    _next_output = SignalValue.none()
    if _inner == null:
        return
    _inner.tick_compute(state, _entering(incoming))


func commit() -> void:
    _outputs.clear()
    if _inner == null:
        output = SignalValue.none()
        return

    _inner.tick_commit()
    for cell in _blueprint.outputs():
        var part := _inner.part_at(cell)
        _outputs.append(part.output if part != null else SignalValue.none())

    output = _outputs[0] if not _outputs.is_empty() else SignalValue.none()


func act(state: WorldState) -> void:
    if _inner == null:
        return
    _inner.tick_act(state)


## 바깥 배선이 안쪽 어느 자리에 닿는지. 이어진 차례대로다.
##
## 배선이 자리보다 적으면 남는 자리에는 아무것도 들어가지 않는다.
## 신호가 없는 배선도 자리를 차지한다. 그래야 어느 배선이 어느 자리로
## 가는지가 신호의 있고 없음에 따라 흔들리지 않는다.
func _entering(incoming: Array) -> Array:
    var external: Array = []
    var cells := _blueprint.inputs()
    for i in mini(cells.size(), incoming.size()):
        external.append([cells[i], incoming[i]])
    return external


## 설계도대로 안쪽 회로를 짓는다. 번호가 없거나 모르는 번호면 비운다.
func _adopt(id: int) -> void:
    bundle_id = id
    _blueprint = null
    _inner = null
    _outputs.clear()

    if _library == null or not _library.has(id):
        return

    _blueprint = _library.blueprint_of(id)
    _inner = Circuit.new()

    for entry: Array in _blueprint.parts():
        var part := CircuitPartFactory.create(int(entry[0]), entry[1], entry[2], _library)
        if part == null:
            # 설계도가 성립하지 않으면 통째로 비운다. 반쯤 지어진 묶음은 두지 않는다.
            _blueprint = null
            _inner = null
            return
        part.pin_anchor(anchor)
        _inner.add_part(part)

    for link: Array in _blueprint.links():
        _inner.link(link[0], link[1], int(link[2]))
