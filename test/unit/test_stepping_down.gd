extends GdUnitTestSuite

## 내려가는 걸음 검증.
##
## 오르는 것만큼 내려가는 것도 걸음이다. **한 칸 턱은 내려선다.** 그보다 깊으면
## 걸어 나간 뒤 떨어진다.
##
## 여기가 조용히 깨져 있었다. 걸음은 같은 높이로 나가고 낙하는 시뮬레이션이
## 뒤이어 맡는 구조인데, 이동 키를 누르고 있으면 한 걸음이 끝나는 바로 그 틱에
## 다음 걸음이 들어와 낙하가 한 번도 차례를 얻지 못했다. 단에서 내려오려던
## 사람이 그 높이 그대로 허공을 걸어갔다.

const PLATFORM := 8


## x <= 3 을 [param height] 칸 더 쌓은 격자. 단 위는 z=height+1, 아래는 z=1 에 선다.
func _ledge(height: int) -> VoxelGrid:
    var grid := VoxelGrid.new()
    for y in PLATFORM:
        for x in PLATFORM:
            grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
            if x >= 4:
                continue
            for z in range(1, height + 1):
                grid.set_block(Vector3i(x, y, z), BlockType.GROUND)
    return grid


func _sim_on_ledge(height: int, at: Vector3i) -> Simulation:
    var sim := Simulation.new(1)
    var grid := _ledge(height)
    for z in VoxelGrid.SIZE_Z:
        for y in PLATFORM:
            for x in PLATFORM:
                var cell := Vector3i(x, y, z)
                sim.state.grid.set_block(cell, grid.get_block(cell))
    sim.state.character.place_at(at)
    return sim


## 이동 키를 누르고 있는 것과 같이 [constant InputController.REPEAT_TICKS] 마다
## 걸음을 넣으면서 진행한다. 지나온 칸을 모두 돌려준다.
func _hold_key(sim: Simulation, direction: Vector3i, ticks: int) -> Array[Vector3i]:
    var visited: Array[Vector3i] = []
    for tick in ticks:
        if tick % InputController.REPEAT_TICKS == 0:
            sim.submit(MoveCharacterCommand.create(direction))
        sim.step()
        var cell := sim.state.character.cell()
        if visited.is_empty() or visited[-1] != cell:
            visited.append(cell)
    return visited


func test_a_one_cell_drop_is_part_of_the_step() -> void:
    # 한 칸 턱은 오른다. 내려서는 것도 마찬가지여야 오르내리는 손맛이 같다.
    var grid := _ledge(1)
    var start := Vector3i(3, 4, 2)
    assert_bool(MovementRules.resolve_walk(grid, start, Vector3i(1, 0, 0)) == Vector3i(4, 4, 1)).is_true()


func test_a_diagonal_steps_down_one_cell_too() -> void:
    var grid := _ledge(1)
    var start := Vector3i(3, 4, 2)
    assert_bool(MovementRules.resolve_walk(grid, start, Vector3i(1, 1, 0)) == Vector3i(4, 5, 1)).is_true()


func test_a_deeper_drop_walks_out_before_falling() -> void:
    # 두 칸 아래는 턱이 아니라 벼랑이다. 걸어 나간 뒤 떨어진다.
    var grid := _ledge(3)
    var start := Vector3i(3, 4, 4)
    assert_bool(MovementRules.resolve_walk(grid, start, Vector3i(1, 0, 0)) == Vector3i(4, 4, 4)).is_true()


func test_no_step_begins_while_the_feet_are_in_the_air() -> void:
    # 떨어지는 중에 걸음이 받아지면 그 높이로 허공을 걸어간다.
    var grid := _ledge(3)
    var midair := Vector3i(4, 4, 4)
    assert_bool(MovementRules.is_falling(grid, midair)).is_true()
    assert_bool(MovementRules.resolve_walk(grid, midair, Vector3i(1, 0, 0)) == midair).is_true()


func test_standing_on_the_ground_is_not_falling() -> void:
    var grid := _ledge(1)
    assert_bool(MovementRules.is_falling(grid, Vector3i(3, 4, 2))).is_false()
    assert_bool(MovementRules.is_falling(grid, Vector3i(5, 4, 1))).is_false()


func test_the_grid_floor_never_counts_as_falling() -> void:
    # 지반층에서는 더 내려갈 곳이 없다. 여기서 걸음을 막으면 갇힌다.
    var grid := VoxelGrid.new()
    var floor_cell := Vector3i(3, 3, VoxelGrid.BEDROCK_Z)
    assert_bool(MovementRules.is_falling(grid, floor_cell)).is_false()


func test_holding_the_key_does_not_carry_you_across_the_drop() -> void:
    var sim := _sim_on_ledge(3, Vector3i(3, 4, 4))
    var visited := _hold_key(sim, Vector3i(1, 0, 0), 80)

    for cell in visited:
        # 단은 x <= 3 뿐이다. 그 높이로 x=5 까지 갔다면 허공을 걸은 것이다.
        if cell.z >= 4:
            assert_int(cell.x).is_less_equal(4)
    assert_int(sim.state.character.cell().z).is_equal(1)


func test_holding_the_key_down_a_one_cell_step_keeps_walking() -> void:
    # 내려선 뒤에도 걸음이 이어져야 한다. 한 칸마다 멈추면 비탈이 계단이 된다.
    var sim := _sim_on_ledge(1, Vector3i(3, 4, 2))
    _hold_key(sim, Vector3i(1, 0, 0), 40)
    assert_int(sim.state.character.cell().z).is_equal(1)
    assert_int(sim.state.character.cell().x).is_greater(4)


func test_stepping_down_takes_as_long_as_stepping_up() -> void:
    var character := CharacterState.new()
    character.place_at(Vector3i(0, 0, 2))
    character.walk_to(Vector3i(1, 0, 1))

    var ticks := 0
    while character.is_moving() and ticks < 100:
        character.advance()
        ticks += 1
    assert_int(ticks).is_equal(CharacterState.SUBUNITS / CharacterState.WALK_SPEED)


func test_a_straight_fall_is_still_faster_than_walking() -> void:
    var character := CharacterState.new()
    character.place_at(Vector3i(0, 0, 4))
    character.walk_to(Vector3i(0, 0, 3))

    var ticks := 0
    while character.is_moving() and ticks < 100:
        character.advance()
        ticks += 1
    assert_int(ticks).is_equal(CharacterState.SUBUNITS / CharacterState.FALL_SPEED)


func test_a_threat_does_not_float_after_leaving_a_ledge() -> void:
    # 위협은 사람을 쫓아 단에서 내려온다. 내려오지 않으면 허공에 뜬 채 맴돈다.
    var sim := _sim_on_ledge(3, Vector3i(6, 4, 1))
    var threat := Threat.create(0, Vector3i(3, 4, 4))

    for i in 4 * Threat.STEP_TICKS:
        threat.advance(sim.state)
        assert_bool(MovementRules.is_falling(sim.state.grid, threat.position)).is_false()
    assert_int(threat.position.z).is_equal(1)


func test_a_threat_falls_when_the_ground_under_it_is_taken_away() -> void:
    var sim := _sim_on_ledge(3, Vector3i(6, 4, 1))
    var threat := Threat.create(0, Vector3i(2, 4, 4))

    for z in range(1, 4):
        sim.state.grid.set_block(Vector3i(2, 4, z), BlockType.EMPTY)
    threat.advance(sim.state)
    assert_int(threat.position.z).is_equal(1)
