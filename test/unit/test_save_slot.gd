extends GdUnitTestSuite

## 저장·불러오기 검증. 스펙 §6, 단일 슬롯.
##
## 판정은 하나로 모인다. **불러온 판의 상태 해시가 저장한 판과 같은가.**
## 같으면 빠뜨린 것이 없는 것이고, 다르면 어딘가 어긋난 것이다.
##
## 이어서 돌린 뒤에도 같아야 한다. 끝 상태만 맞고 속이 어긋나 있으면 그
## 다음 틱부터 갈라진다.

const SEED := 20250901


func before_test() -> void:
    SaveSlot.clear()


func after_test() -> void:
    SaveSlot.clear()


## 무언가 실제로 일어난 판 하나. 아무 일도 없으면 아무것도 지키지 못한다.
##
## **모든 것을 명령으로 한다.** 상태를 손으로 건드리면 그것은 기록에 남지 않고,
## 불러온 판에 없다. 게임 자체가 그 규칙 위에 서 있다(CLAUDE.md).
func _played() -> Simulation:
    var sim := IslandBuilder.start(SEED)
    var here := sim.state.character.cell()

    # 나무를 베어 재료를 모은다. 손이 닿는 거리는 표현 레이어의 몫이라
    # 명령 자체에는 거리 제한이 없다.
    for trunk in [IslandBuilder.TREES[0], IslandBuilder.TREES[1]]:
        for i in IslandBuilder.TREE_HEIGHT:
            sim.submit(BreakBlockCommand.create(Vector3i(
                trunk.x, trunk.y, IslandBuilder.surface_z(trunk) + 1 + i)))
    sim.advance(4)

    sim.submit(BreakBlockCommand.create(here + Vector3i(1, 0, -1)))
    sim.advance(4)

    sim.submit(MoveCharacterCommand.create(Vector3i(1, 0, 0)))
    sim.advance(10)

    sim.submit(PlaceBlockCommand.create(here + Vector3i(1, 0, -1), BlockType.GROUND))
    sim.advance(6)

    sim.submit(CraftCommand.create(BlockType.DOOR_CLOSED))
    sim.advance(6)
    return sim


func test_a_played_game_is_written_and_read_back_the_same() -> void:
    var played := _played()
    assert_bool(SaveSlot.save(played)).is_true()

    var restored := SaveSlot.restore()
    assert_object(restored).is_not_null()
    assert_str(restored.state_hash()).is_equal(played.state_hash())


func test_the_restored_game_keeps_going_the_same_way() -> void:
    # 끝 상태만 맞고 속이 어긋나 있으면 그 다음 틱부터 갈라진다.
    var played := _played()
    SaveSlot.save(played)
    var restored := SaveSlot.restore()

    played.advance(120)
    restored.advance(120)
    assert_str(restored.state_hash()).is_equal(played.state_hash())


func test_what_was_still_waiting_is_waiting_again() -> void:
    # 아직 실행되지 않은 명령도 함께 간다. 버리면 불러온 판이 다르게 흘러간다.
    var sim := IslandBuilder.start(SEED)
    sim.submit_at(MoveCharacterCommand.create(Vector3i(0, -1, 0)), 60)
    sim.advance(10)

    SaveSlot.save(sim)
    var restored := SaveSlot.restore()
    assert_int(restored.queue.size()).is_equal(sim.queue.size())

    sim.advance(80)
    restored.advance(80)
    assert_str(restored.state_hash()).is_equal(sim.state_hash())


func test_saving_again_replaces_the_one_slot() -> void:
    var sim := _played()
    SaveSlot.save(sim)
    var first := SaveSlot.restore().state_hash()

    sim.advance(40)
    SaveSlot.save(sim)
    var second := SaveSlot.restore().state_hash()

    assert_str(second).is_not_equal(first)
    assert_str(second).is_equal(sim.state_hash())


func test_a_fresh_game_has_nothing_to_load() -> void:
    assert_bool(SaveSlot.has_save()).is_false()
    assert_object(SaveSlot.restore()).is_null()


func test_clearing_the_slot_empties_it() -> void:
    SaveSlot.save(_played())
    assert_bool(SaveSlot.has_save()).is_true()
    SaveSlot.clear()
    assert_bool(SaveSlot.has_save()).is_false()


func test_a_save_from_another_version_is_refused() -> void:
    # 모르는 판을 억지로 읽으면 조용히 다른 세상이 된다.
    var data := SaveSlot.to_dict(_played())
    data["version"] = SaveSlot.VERSION + 1
    assert_object(SaveSlot.from_text(JSON.stringify(data))).is_null()


func test_a_save_with_an_unknown_command_is_refused() -> void:
    # 모르는 명령을 조용히 건너뛰면 그 뒤가 전부 어긋난다.
    var data := SaveSlot.to_dict(_played())
    var commands: Array = data["commands"]
    commands.append({"type": "no_such_command", "tick": 1})
    assert_object(SaveSlot.from_text(JSON.stringify(data))).is_null()


func test_rubbish_is_refused() -> void:
    assert_object(SaveSlot.from_text("not json at all")).is_null()
    assert_object(SaveSlot.from_text("[1, 2, 3]")).is_null()


func test_the_scenario_actually_did_something() -> void:
    # 아무 일도 없는 판을 저장했다 불러오면 무엇이든 맞는다.
    var played := _played()
    assert_int(played.state.inventory.count_of(BlockType.DOOR_CLOSED)).is_equal(1)
    assert_int(played.state.inventory.count_of(BlockType.WOOD)).is_equal(2)
    assert_int(played.command_count()).is_greater(5)


func test_only_what_went_through_a_command_comes_back() -> void:
    # 저장은 명령 기록이다. 상태를 손으로 건드리면 기록에 남지 않는다.
    # 게임 자체가 "모든 상태 변경은 명령을 경유한다"는 규칙 위에 서 있으므로
    # 이것은 한계가 아니라 그 규칙을 드러내는 자리다.
    var sim := IslandBuilder.start(SEED)
    sim.advance(4)
    sim.state.inventory.add(BlockType.WOOD, 99)

    SaveSlot.save(sim)
    assert_int(SaveSlot.restore().state.inventory.count_of(BlockType.WOOD)).is_equal(0)


func test_the_log_grows_with_what_was_submitted() -> void:
    var sim := IslandBuilder.start(SEED)
    assert_int(sim.command_count()).is_equal(0)

    sim.submit(MoveCharacterCommand.create(Vector3i(1, 0, 0)))
    sim.submit(EatCommand.create())
    assert_int(sim.command_count()).is_equal(2)


## 저장한 글에 적힌 것은 시드와 틱 수와 명령뿐이다. 상태를 뜨지 않는다.
func test_the_slot_holds_a_replay_not_a_snapshot() -> void:
    var data := SaveSlot.to_dict(_played())
    assert_array(data.keys()).contains(["version", "seed", "tick", "commands"])
    assert_int(data.keys().size()).is_equal(4)


func test_the_written_game_is_plain_text_that_survives_a_round_trip() -> void:
    # lockstep 으로 오갈 것과 같은 형식이다. JSON 을 지나도 같아야 한다.
    var played := _played()
    var text := JSON.stringify(SaveSlot.to_dict(played))
    assert_str(SaveSlot.from_text(text).state_hash()).is_equal(played.state_hash())
