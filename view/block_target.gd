class_name BlockTarget
extends RefCounted

## 시선이 가리키는 블록 한 칸.
##
## 격자를 훑는 일은 표현 레이어의 몫이다. 광선은 카메라와 마우스에서 나오므로
## 실수를 쓴다. 여기서 나온 결과는 칸 좌표(정수)로만 시뮬레이션에 건네진다.
##
## 광선은 격자 좌표계에서 쏜다. 칸 (i,j,k) 는
## [i,i+1] x [j,j+1] x [k,k+1] 을 차지한다.

## 캐릭터가 손댈 수 있는 거리(칸).
const REACH_CELLS := 5

## 광선을 몇 칸까지 따라갈지의 한계. 무한 반복을 막는 안전장치이기도 하다.
const MAX_STEPS := 512

var hit: bool = false
var cell: Vector3i = Vector3i.ZERO

## 맞은 면의 바깥 방향. 새 블록은 이쪽에 놓인다.
var normal: Vector3i = Vector3i.ZERO


## 이 칸에 놓을 때의 자리.
func place_cell() -> Vector3i:
    return cell + normal


## 실제로 쓸 수 있는 표적인가. 맞았고, 캐릭터 손이 닿는 거리여야 한다.
func is_usable(character_cell: Vector3i) -> bool:
    if not hit:
        return false
    var offset := cell - character_cell
    return offset.x * offset.x + offset.y * offset.y + offset.z * offset.z <= REACH_CELLS * REACH_CELLS


## [param origin] 에서 [param direction] 으로 광선을 쏴 처음 만나는 단단한 칸을 찾는다.
##
## Amanatides-Woo 격자 훑기. 칸 경계를 하나씩 넘으며 면을 정확히 짚는다.
static func raycast(grid: VoxelGrid, origin: Vector3, direction: Vector3, max_distance: float) -> BlockTarget:
    var target := BlockTarget.new()
    if direction.is_zero_approx() or max_distance <= 0.0:
        return target

    var dir := direction.normalized()
    var cell := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
    var step := Vector3i(signi(int(signf(dir.x))), signi(int(signf(dir.y))), signi(int(signf(dir.z))))

    var t_max := Vector3(
        _first_boundary(origin.x, dir.x),
        _first_boundary(origin.y, dir.y),
        _first_boundary(origin.z, dir.z),
    )
    var t_delta := Vector3(_axis_delta(dir.x), _axis_delta(dir.y), _axis_delta(dir.z))

    var travelled := 0.0
    for i in MAX_STEPS:
        if grid.is_solid(cell):
            target.hit = true
            target.cell = cell
            return target

        # 가장 가까운 경계를 넘는다. 넘은 축의 반대쪽이 맞은 면이 된다.
        if t_max.x <= t_max.y and t_max.x <= t_max.z:
            travelled = t_max.x
            t_max.x += t_delta.x
            cell.x += step.x
            target.normal = Vector3i(-step.x, 0, 0)
        elif t_max.y <= t_max.z:
            travelled = t_max.y
            t_max.y += t_delta.y
            cell.y += step.y
            target.normal = Vector3i(0, -step.y, 0)
        else:
            travelled = t_max.z
            t_max.z += t_delta.z
            cell.z += step.z
            target.normal = Vector3i(0, 0, -step.z)

        if travelled > max_distance:
            break

    target.normal = Vector3i.ZERO
    return target


## 현재 위치에서 다음 칸 경계까지의 거리.
static func _first_boundary(start: float, dir: float) -> float:
    if is_zero_approx(dir):
        return INF
    var cell_index := floorf(start)
    var edge := cell_index + 1.0 if dir > 0.0 else cell_index
    return (edge - start) / dir


## 칸 하나를 지나는 데 드는 거리.
static func _axis_delta(dir: float) -> float:
    if is_zero_approx(dir):
        return INF
    return absf(1.0 / dir)
