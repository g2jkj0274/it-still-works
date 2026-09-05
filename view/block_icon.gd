class_name BlockIcon
extends Control

## 손에 든 것을 그림으로 그린다.
##
## **칸에 이름이 적혀 있었다.** "되풀이" 라고 쓰인 회색 네모 아홉 개가 화면
## 아래에 늘어서 있었고, 무엇을 들고 있는지 알려면 매번 읽어야 했다. 마인크래프트
## 는 아홉 칸을 눈으로 훑는다. 읽는 것과 보는 것은 속도가 다르다.
##
## 3D 를 작은 화면에 따로 렌더해서 굽지 않는다. 세상에 세우는 것과 **같은
## 상자 표**([method BlockMeshes.boxes_of])를 읽어 아이소메트릭으로 그린다.
## 그래야 인벤토리에서 본 실루엣과 땅에 놓은 실루엣이 같다. 표를 두 벌 두면
## 언젠가 어긋나고, 어긋난 그림은 없느니만 못하다.
##
## 렌더러가 없어도 그려진다. 헤드리스에서도 자리와 모양을 잴 수 있다.

## 아이소메트릭 눕힘. 세상 화면과 같은 각이라 실루엣이 낯설지 않다.
const ACROSS := 0.866
const DOWN := 0.5

## 칸 하나가 그림에서 차지하는 크기의 배수. 여백을 남긴다.
const FIT := 0.78

## 면 밝기는 세상과 같은 값을 쓴다.
const FACE_TOP := BlockMeshes.FACE_TOP
const FACE_SIDE_X := BlockMeshes.FACE_SIDE_X
const FACE_SIDE_Z := BlockMeshes.FACE_SIDE_Z

## 테두리. 밝은 바탕에서 흰 블록이 사라지지 않게 한다.
const OUTLINE := Color(0.12, 0.14, 0.18, 0.35)

var _block_type: int = BlockType.EMPTY


func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


## 무엇을 그릴지 정한다. 같은 것이면 다시 그리지 않는다.
func show_block(block_type: int) -> void:
    if block_type == _block_type:
        return
    _block_type = block_type
    queue_redraw()


func block_type() -> int:
    return _block_type


func is_empty() -> bool:
    return _block_type == BlockType.EMPTY


func _draw() -> void:
    if is_empty():
        return

    var top := Palette.of_block(_block_type)
    var side := Palette.side_of(_block_type)
    var scale := minf(size.x, size.y) * FIT * 0.5
    var middle := size * 0.5

    for shape: Array in _sorted_boxes():
        _draw_box(shape[0], shape[1], middle, scale, top, side)


## 뒤에 있는 상자부터 그린다. 앞의 것이 뒤의 것을 덮어야 한다.
##
## 보는 눈이 +X +Y +Z 쪽에 있으므로 세 축의 합이 클수록 앞이다.
func _sorted_boxes() -> Array[Array]:
    var boxes := BlockMeshes.boxes_of(_block_type)
    boxes.sort_custom(func(a: Array, b: Array) -> bool:
        var one: Vector3 = a[0]
        var other: Vector3 = b[0]
        return one.x + one.y + one.z < other.x + other.y + other.z)
    return boxes


## 상자 하나. 밖에서 보이는 세 면만 그린다.
func _draw_box(
    centre: Vector3, box_size: Vector3, middle: Vector2, scale: float,
    top: Color, side: Color
) -> void:
    var h := box_size * 0.5
    var faces: Array[Array] = [
        # [법선, 색, 가로축, 세로축]
        [Vector3.UP, top * FACE_TOP, Vector3.RIGHT, Vector3.BACK],
        [Vector3.RIGHT, side * FACE_SIDE_X, Vector3.BACK, Vector3.UP],
        [Vector3.BACK, side * FACE_SIDE_Z, Vector3.LEFT, Vector3.UP],
    ]

    for face: Array in faces:
        var normal: Vector3 = face[0]
        var across: Vector3 = face[2] * h
        var along: Vector3 = face[3] * h
        var face_middle := centre + normal * h

        var corners := PackedVector2Array()
        for corner: Vector3 in [
            face_middle - across - along,
            face_middle + across - along,
            face_middle + across + along,
            face_middle - across + along,
        ]:
            corners.append(middle + flatten(corner) * scale)

        var colour: Color = face[1]
        colour.a = 1.0
        draw_colored_polygon(corners, colour)
        draw_polyline(corners + PackedVector2Array([corners[0]]), OUTLINE, 1.0)


## 세상의 한 점을 그림 위의 한 점으로 눕힌다. Y 가 위다.
static func flatten(point: Vector3) -> Vector2:
    return Vector2(
        (point.x - point.z) * ACROSS,
        (point.x + point.z) * DOWN - point.y)


## 그려진 그림이 차지하는 자리. 칸 안에 들어오는지 잴 때 쓴다.
func drawn_bounds() -> Rect2:
    if is_empty():
        return Rect2()

    var scale := minf(size.x, size.y) * FIT * 0.5
    var middle := size * 0.5
    var bounds := Rect2()
    var started := false

    for shape: Array in BlockMeshes.boxes_of(_block_type):
        var centre: Vector3 = shape[0]
        var h: Vector3 = shape[1] * 0.5
        for sx in [-1.0, 1.0]:
            for sy in [-1.0, 1.0]:
                for sz in [-1.0, 1.0]:
                    var corner := centre + Vector3(h.x * sx, h.y * sy, h.z * sz)
                    var point := middle + flatten(corner) * scale
                    if started:
                        bounds = bounds.expand(point)
                    else:
                        bounds = Rect2(point, Vector2.ZERO)
                        started = true
    return bounds
