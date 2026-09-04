class_name BlockMeshes
extends RefCounted

## 블록 종류마다의 생김새.
##
## 지금까지는 모두 같은 큐브였다. 그래서 색만이 종류를 가르는 단서였는데,
## 파스텔은 쓸 수 있는 폭이 좁아 열 종이 넘어가면 색만으로는 구별이 흐려진다.
## **모양을 주면 색이 비슷해도 알아볼 수 있다.**
##
## 특히 문은 열린 것과 닫힌 것이 같은 색이라 화면에서 구별되지 않았다.
## 자동문은 스펙 §5 의 첫 장치인데 그 결과가 보이지 않았던 것이다.
## 열린 문은 한쪽으로 물러난 얇은 판으로 그려 지나갈 자리가 눈에 보이게 한다.
##
## 면마다 밝기를 달리 굽는다. 빛 하나만으로는 윗면과 옆면의 차이가 약해
## 쌓아 올린 것이 덩어리로 보인다. 이 값은 칸마다 주는 명도 변주
## ([method Palette.varied]) 와 곱해진다.

## 면 밝기. 윗면이 가장 밝고 바닥이 가장 어둡다.
## 밝기와 함께 면의 **색**도 여기서 구워 둔다 — 흙은 위가 풀, 옆이 흙이다.
## 아이소메트릭에서는 옆면 두 쪽이 함께 보이므로 그 둘도 서로 다르게 둔다.
const FACE_TOP := 1.00
const FACE_SIDE_X := 0.82
const FACE_SIDE_Z := 0.91
const FACE_BOTTOM := 0.66

## 열린 문이 물러나 있는 두께. 지나갈 자리가 비어 보여야 한다.
const OPEN_DOOR_THICKNESS := 0.22

## 닫힌 문의 두께. 칸을 막고 있다는 것이 보여야 한다.
const CLOSED_DOOR_THICKNESS := 0.86

const _CELL := SimViewCoords.CELL_SIZE


## 그 블록을 그릴 메시. 종류마다 한 번만 만들어 쓴다.
##
## 면의 색까지 여기서 구워 둔다. 칸마다 주는 명암은 인스턴스 쪽에서 곱해진다.
static func for_block(block_type: int) -> ArrayMesh:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    _top = Palette.of_block(block_type)
    _side = Palette.side_of(block_type)
    _shape_of(tool, block_type)
    return tool.commit()


## 지금 굽고 있는 블록의 윗면·옆면 색. [method for_block] 이 채운다.
static var _top: Color = Color.WHITE
static var _side: Color = Color.WHITE


## 종류별 생김새. 모두 한 칸 안에 들어간다.
##
## 한 칸이 화면에서 사십 픽셀 남짓이다. 잔 무늬는 그 크기에서 사라지므로
## **키와 바닥 넓이로** 가른다. 낮게 깔린 것, 층층이 쌓인 것, 둘로 갈린 것,
## 뚜껑이 넓은 것 — 실루엣만으로 알아볼 수 있어야 한다.
static func _shape_of(tool: SurfaceTool, block_type: int) -> void:
    match block_type:
        BlockType.DOOR_CLOSED:
            # 칸을 가로막은 두꺼운 판. 키가 칸을 꽉 채운다.
            _box(tool, Vector3.ZERO, Vector3(_CELL, _CELL, CLOSED_DOOR_THICKNESS))
        BlockType.DOOR_OPEN:
            # 한쪽으로 물러난 얇은 판. 남은 자리가 지나갈 자리다.
            var shift := (_CELL - OPEN_DOOR_THICKNESS) * 0.5
            _box(tool, Vector3(0.0, 0.0, -shift),
                Vector3(_CELL, _CELL, OPEN_DOOR_THICKNESS))
        BlockType.FIELD:
            # 갈아 놓은 두둑. 밟고 다니는 곳이라 가장 낮다.
            _box(tool, Vector3(0.0, -0.32, 0.0), Vector3(_CELL, 0.36, _CELL))
        BlockType.CROP:
            # 작물 포기. 밑동에서 이삭이 두 갈래로 솟는다.
            # 땅에 난 것은 부숴서 먹고, 이것이 첫날을 넘기는 유일한 길이다.
            _box(tool, Vector3(0.0, -0.40, 0.0), Vector3(0.44, 0.20, 0.44))
            _box(tool, Vector3(-0.10, -0.12, 0.0), Vector3(0.16, 0.44, 0.16))
            _box(tool, Vector3(0.12, -0.04, 0.06), Vector3(0.16, 0.56, 0.16))
            _box(tool, Vector3(0.0, 0.18, 0.0), Vector3(0.30, 0.18, 0.30))
        BlockType.DETECTOR:
            # 눈. 몸통 위로 렌즈가 곧게 솟았다. 부품 가운데 가장 키가 크다.
            _box(tool, Vector3(0.0, -0.22, 0.0), Vector3(0.80, 0.56, 0.80))
            _box(tool, Vector3(0.0, 0.16, 0.0), Vector3(0.44, 0.40, 0.44))
            _box(tool, Vector3(0.0, 0.38, 0.0), Vector3(0.24, 0.10, 0.24))
        BlockType.ACTUATOR:
            # 손. 좁은 몸통 위에 넓은 판이 얹혔다. 버섯처럼 위가 넓다.
            _box(tool, Vector3(0.0, -0.26, 0.0), Vector3(0.62, 0.48, 0.62))
            _box(tool, Vector3(0.0, 0.06, 0.0), Vector3(0.94, 0.20, 0.94))
            _box(tool, Vector3(0.0, 0.26, 0.0), Vector3(0.34, 0.20, 0.34))
        BlockType.REPEATER:
            # 되풀이. 같은 것이 층층이 좁아지며 올라간다.
            _box(tool, Vector3(0.0, -0.36, 0.0), Vector3(0.98, 0.28, 0.98))
            _box(tool, Vector3(0.0, -0.06, 0.0), Vector3(0.72, 0.32, 0.72))
            _box(tool, Vector3(0.0, 0.24, 0.0), Vector3(0.44, 0.28, 0.44))
        BlockType.BOX:
            # 상자. 몸통보다 뚜껑이 넓게 나와 턱을 만든다.
            _box(tool, Vector3(0.0, -0.20, 0.0), Vector3(0.82, 0.60, 0.82))
            _box(tool, Vector3(0.0, 0.18, 0.0), Vector3(0.98, 0.16, 0.98))
            _box(tool, Vector3(0.0, 0.32, 0.0), Vector3(0.26, 0.12, 0.26))
        BlockType.BRANCH:
            # 갈림길. 낮은 바닥에서 길이 둘로 갈려 올라간다. 사이가 비어 있다.
            _box(tool, Vector3(0.0, -0.38, 0.0), Vector3(0.94, 0.24, 0.94))
            _box(tool, Vector3(-0.26, 0.06, 0.0), Vector3(0.36, 0.64, 0.56))
            _box(tool, Vector3(0.26, 0.06, 0.0), Vector3(0.36, 0.64, 0.56))
        BlockType.BUNDLE:
            # 묶음. 끈으로 열십자로 동여맨 꾸러미.
            _box(tool, Vector3(0.0, -0.14, 0.0), Vector3(0.84, 0.72, 0.84))
            _box(tool, Vector3(0.0, -0.10, 0.0), Vector3(0.96, 0.22, 0.26))
            _box(tool, Vector3(0.0, -0.10, 0.0), Vector3(0.26, 0.22, 0.96))
            _box(tool, Vector3(0.0, 0.30, 0.0), Vector3(0.30, 0.20, 0.30))
        _:
            # 지형은 칸을 꽉 채운다. 이어 붙였을 때 틈이 보이면 안 된다.
            _box(tool, Vector3.ZERO, Vector3.ONE * _CELL)


## 면마다 밝기를 구운 상자 하나를 보탠다.
##
## 바깥에서 볼 때 앞이 되도록 감는다. 다만 재질에서 뒷면 자르기를 꺼 두므로
## 감는 방향이 어긋나도 안이 비쳐 보이지는 않는다. 빛은 여기서 준 법선을
## 따르므로 어느 쪽에서 보아도 같은 밝기다.
static func _box(tool: SurfaceTool, centre: Vector3, size: Vector3) -> void:
    var h := size * 0.5
    for face: Array in _faces():
        var normal: Vector3 = face[0]
        var shade: float = face[1]
        var right: Vector3 = face[2]
        var up: Vector3 = face[3]

        var face_colour: Color = _top if absf(normal.y) > 0.5 else _side
        var middle := centre + normal * h
        var across := right * h
        var along := up * h

        var corners: Array[Vector3] = [
            middle - across - along,
            middle + across - along,
            middle + across + along,
            middle - across + along,
        ]
        _quad(tool, corners, normal, face_colour * shade)


## 여섯 면. [법선, 밝기, 가로축, 세로축].
static func _faces() -> Array:
    return [
        [Vector3.UP, FACE_TOP, Vector3.RIGHT, Vector3.BACK],
        [Vector3.DOWN, FACE_BOTTOM, Vector3.RIGHT, Vector3.FORWARD],
        [Vector3.RIGHT, FACE_SIDE_X, Vector3.BACK, Vector3.UP],
        [Vector3.LEFT, FACE_SIDE_X, Vector3.FORWARD, Vector3.UP],
        [Vector3.BACK, FACE_SIDE_Z, Vector3.LEFT, Vector3.UP],
        [Vector3.FORWARD, FACE_SIDE_Z, Vector3.RIGHT, Vector3.UP],
    ]


static func _quad(tool: SurfaceTool, corners: Array[Vector3], normal: Vector3, colour: Color) -> void:
    for index in [0, 1, 2, 0, 2, 3]:
        tool.set_normal(normal)
        tool.set_color(colour)
        tool.add_vertex(corners[index])
