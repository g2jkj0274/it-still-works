extends GdUnitTestSuite

## 소리 검증.
##
## 시뮬레이션은 소리를 모른다. 여기서 하는 일은 상태를 보고 있다가 바뀐 것을
## 발견하면 울리는 것이다. 그래서 **"명령을 넣었으니 울린다"가 아니라 "세상이
## 실제로 바뀌었으니 울린다"** 이다. 재료가 없어 못 놓았으면 소리도 없다.

const HERE := Vector3i(10, 10, 2)


func _sim() -> Simulation:
    var sim := Simulation.new(9)
    for y in range(8, 14):
        for x in range(8, 14):
            sim.state.grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
            sim.state.grid.set_block(Vector3i(x, y, 1), BlockType.GROUND)
    sim.state.character.place_at(HERE)
    return sim


func _board(sim: Simulation) -> SoundBoard:
    var board: SoundBoard = auto_free(SoundBoard.new())
    add_child(board)
    board.bind(sim)
    # 첫 번째 sync 는 견줄 앞을 기억할 뿐 울리지 않는다.
    board.sync()
    board.forget()
    return board


func test_every_sound_has_a_file_that_loads() -> void:
    for kind in SoundBoard.SOUNDS:
        var entry: Array = SoundBoard.SOUNDS[kind]
        assert_object(load(SoundBoard.DIR + String(entry[0]))).override_failure_message(
            "%s 의 소리 파일을 읽지 못한다" % kind).is_not_null()


func test_nothing_rings_on_the_very_first_look() -> void:
    var sim := _sim()
    var board: SoundBoard = auto_free(SoundBoard.new())
    add_child(board)
    board.bind(sim)
    board.sync()
    assert_array(board.played()).is_empty()


func test_a_quiet_world_stays_quiet() -> void:
    var sim := _sim()
    var board := _board(sim)
    for i in 5:
        sim.step()
        board.sync()
    assert_array(board.played()).is_empty()


func test_breaking_something_rings() -> void:
    var sim := _sim()
    var board := _board(sim)

    sim.submit(BreakBlockCommand.create(HERE - VoxelGrid.UP))
    sim.step()
    board.sync()
    assert_array(board.played()).contains([&"break"])


func test_placing_something_rings_differently() -> void:
    var sim := _sim()
    sim.state.inventory.add(BlockType.WOOD, 1)
    var board := _board(sim)

    sim.submit(PlaceBlockCommand.create(HERE + Vector3i(1, 0, 0), BlockType.WOOD))
    sim.step()
    board.sync()
    assert_array(board.played()).contains([&"place"])
    assert_array(board.played()).not_contains([&"break"])


func test_harvesting_never_sounds_like_mining() -> void:
    # 손에 든 것의 총량으로 짐작하던 때에는 밭을 거두어도 곡괭이 소리가 났다.
    var sim := _sim()
    var board := _board(sim)

    sim.state.inventory.add(BlockType.CROP, 2)
    board.sync()
    assert_array(board.played()).not_contains([&"break"])


func test_making_something_never_sounds_like_placing() -> void:
    var sim := _sim()
    sim.state.inventory.add(BlockType.WOOD, 4)
    var board := _board(sim)

    sim.submit(CraftCommand.create(BlockType.DOOR_CLOSED))
    sim.step()
    board.sync()
    assert_array(board.played()).not_contains([&"place"])


func test_a_lamp_and_a_door_have_their_own_sounds() -> void:
    var sim := _sim()
    var board := _board(sim)

    sim.state.grid.set_block(HERE + Vector3i(1, 0, 0), BlockType.LAMP_DARK)
    board.sync()
    board.forget()

    sim.state.grid.set_block(HERE + Vector3i(1, 0, 0), BlockType.LAMP_LIT)
    board.sync()
    assert_array(board.played()).contains([&"lamp"])
    assert_array(board.played()).not_contains([&"place"])


func test_a_place_that_never_happened_makes_no_sound() -> void:
    # 재료가 없으면 놓이지 않는다. 화면과 소리가 같은 것을 말해야 한다.
    var sim := _sim()
    var board := _board(sim)

    sim.submit(PlaceBlockCommand.create(HERE + Vector3i(1, 0, 0), BlockType.WOOD))
    sim.step()
    board.sync()
    assert_array(board.played()).is_empty()


func test_walking_rings_a_footstep_when_the_cell_changes() -> void:
    var sim := _sim()
    var board := _board(sim)

    sim.submit(MoveCharacterCommand.create(Vector3i(1, 0, 0)))
    for i in 10:
        sim.step()
        board.sync()
    assert_bool(sim.state.character.cell() != HERE).is_true()

    var heard := board.played()
    assert_bool(heard.has(&"step_a") or heard.has(&"step_b")).is_true()


func test_footsteps_alternate() -> void:
    var board := _board(_sim())
    board.play(&"step_a")
    board.play(&"step_b")
    assert_array(board.played()).is_equal([&"step_a", &"step_b"])


func test_a_signal_rings_every_time_it_turns_on() -> void:
    # 흐르는 배선의 총 개수만 보면 계속 켜져 있는 회로는 처음 한 번 울고
    # 영영 조용하다. 신호가 부품을 지날 때 나는 소리가 이 장르의 정체성이다.
    var sim := _sim()
    var first := HERE + Vector3i(1, 0, 0)
    var second := HERE + Vector3i(2, 0, 0)
    var box := BoxPart.create(first)
    sim.state.circuit.add_part(box)
    sim.state.circuit.add_part(ActuatorPart.create(second))
    sim.state.circuit.link(first, second)

    var board := _board(sim)
    for turn in 3:
        box.compute(sim.state, [SignalValue.of_bool(true)])
        box.commit()
        board.forget()
        board.sync()
        assert_array(board.played()).override_failure_message(
            "%d 번째 켜짐에 소리가 없다" % (turn + 1)).contains([&"signal"])

        box.compute(sim.state, [])
        box.commit()
        # 상자는 담긴 값을 늘 내보낸다. 부품을 지워 흐름을 끊는다.
        sim.state.circuit.remove_part(first)
        board.forget()
        board.sync()

        sim.state.circuit.add_part(BoxPart.create(first))
        sim.state.circuit.link(first, second)
        box = sim.state.circuit.part_at(first) as BoxPart
        board.forget()
        board.sync()


func test_joining_two_parts_rings() -> void:
    var sim := _sim()
    sim.state.inventory.add(BlockType.DETECTOR, 1)
    sim.state.inventory.add(BlockType.ACTUATOR, 1)
    var first := HERE + Vector3i(1, 0, 0)
    var second := HERE + Vector3i(2, 0, 0)
    sim.submit(PlacePartCommand.create(first, BlockType.DETECTOR))
    sim.submit(PlacePartCommand.create(second, BlockType.ACTUATOR))
    sim.step()

    var board := _board(sim)
    sim.submit(ConnectPartsCommand.create(first, second))
    sim.step()
    board.sync()
    assert_array(board.played()).contains([&"link"])


func test_getting_hit_rings() -> void:
    var sim := _sim()
    var board := _board(sim)
    sim.state.vitals.damage(1)
    board.sync()
    assert_array(board.played()).contains([&"hurt"])


func test_eating_rings() -> void:
    var sim := _sim()
    # 배가 가득 차 있으면 먹어도 늘지 않는다. 먼저 비운다.
    sim.state.vitals.damage(0)
    sim.state.vitals.fullness = Vitals.MAX_FULLNESS - 8
    sim.state.inventory.add(BlockType.CROP, 1)

    var board := _board(sim)
    sim.submit(EatCommand.create())
    sim.step()
    board.sync()
    assert_array(board.played()).contains([&"eat"])


func test_an_unknown_sound_is_ignored() -> void:
    var board := _board(_sim())
    board.play(&"no_such_sound")
    assert_array(board.played()).contains([&"no_such_sound"])
