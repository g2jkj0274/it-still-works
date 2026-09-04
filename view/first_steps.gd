class_name FirstSteps
extends Node

## 처음 켠 사람에게 **첫 동사 하나씩만** 알려준다.
##
## 튜토리얼이 아니다. 막지 않고, 시키지 않고, 순서를 강요하지 않는다(스펙 §1
## "목표를 강제하지 않음"). 무엇을 눌러야 아무 일이라도 일어나는지만 알려준다.
##
## 처음 화면에는 전부 0 인 핫바 열한 칸과 얼굴 없는 흰 공뿐이었다. 조작 안내는
## 숨겨져 있고 그것을 여는 키가 H 라는 사실을 알려 주는 것도 없었다. 첫 60초가
## 통째로 손해였다.
##
## **회로가 왜 안 도는지는 여기서도 말하지 않는다.** 그건 만든 사람이 알아낼
## 몫이다. 여기서 말하는 것은 키 이름뿐이다.

## 한 줄이 화면에 머무는 시간. 다음 줄은 이것이 지난 뒤에 나온다.
const SECONDS := 4.0

## 무엇을 손에 쥐면 다음 줄로 넘어가는가.
const PARTS: Array[int] = [
    BlockType.DETECTOR, BlockType.ACTUATOR, BlockType.REPEATER,
    BlockType.BOX, BlockType.BRANCH,
]

var _simulation: Simulation
var _notice: Notice
var _step: int = 0


func bind(simulation: Simulation, notice: Notice) -> void:
    _simulation = simulation
    _notice = notice


## 다 알려 주었는가.
func is_done() -> bool:
    return _step >= line_count()


func step() -> int:
    return _step


static func line_count() -> int:
    return 3


## 그 차례에 보일 말.
static func line_at(index: int) -> String:
    match index:
        0:
            return "부수기 Q · 놓기 E · 조작 안내 H"
        1:
            return "만들 수 있는 것은 아래 한 줄에 적혀 있다 · 만들기 C"
        2:
            return "부품 둘을 차례로 R 로 누르면 이어진다"
        _:
            return ""


## 지금 차례로 넘어갈 때가 되었는가.
func is_ready(index: int) -> bool:
    if _simulation == null:
        return false
    var inventory := _simulation.state.inventory
    match index:
        0:
            return true
        1:
            return inventory.total() > 0
        2:
            for part_type in PARTS:
                if inventory.count_of(part_type) > 0:
                    return true
            return false
        _:
            return false


## 표현 레이어의 프레임 루프에서 부른다. 조건이 차면 한 줄 알린다.
func check() -> void:
    if is_done() or _notice == null:
        return
    # 앞 줄이 아직 떠 있으면 겹치지 않게 기다린다.
    if _notice.visible:
        return
    if not is_ready(_step):
        return

    _notice.say(line_at(_step), SECONDS)
    _step += 1


## 처음부터 다시 알려준다. 새 판을 시작하거나 불러왔을 때 쓴다.
func restart() -> void:
    _step = 0
