extends GdUnitTestSuite

## 생존 흐름 검증. 밤·위협·굶주림·되살아남.


func _sim() -> Simulation:
    var sim := Simulation.new(20250901)
    IslandBuilder.populate(sim.state)
    return sim


## 밤이 시작되는 틱까지 나아간다.
func _to_nightfall(sim: Simulation) -> void:
    sim.advance(DayCycle.DAY_TICKS + 1)


func test_no_threats_walk_in_daylight() -> void:
    var sim := _sim()
    sim.advance(100)
    assert_bool(DayCycle.is_night(sim.current_tick())).is_false()
    assert_int(sim.state.threats.count()).is_equal(0)


func test_threats_come_out_at_night() -> void:
    var sim := _sim()
    _to_nightfall(sim)
    assert_bool(DayCycle.is_night(sim.current_tick())).is_true()
    assert_int(sim.state.threats.count()).is_greater(0)


func test_threats_are_gone_by_morning() -> void:
    var sim := _sim()
    _to_nightfall(sim)
    sim.advance(DayCycle.NIGHT_TICKS + 1)
    assert_bool(DayCycle.is_night(sim.current_tick())).is_false()
    assert_int(sim.state.threats.count()).is_equal(0)


func test_threats_keep_their_distance_when_they_arrive() -> void:
    # 나오자마자 붙으면 피할 틈이 없다.
    var sim := _sim()
    _to_nightfall(sim)
    var here := sim.state.character.cell()
    for threat in sim.state.threats.threats():
        var offset := threat.position - here
        assert_int(offset.x * offset.x + offset.y * offset.y).is_greater_equal(
            ThreatField.MIN_CLEARANCE * ThreatField.MIN_CLEARANCE)


func test_threats_arrive_close_enough_to_be_seen_coming() -> void:
    # 멀리서 다가오는 것을 몇 초 보는 것이 밤의 긴장 전부다. 화면 밖에서
    # 나오면 밤이 아무 일도 없는 삼 분으로 시작해서 등 뒤에서 물리는 것으로
    # 끝난다.
    var sim := _sim()
    _to_nightfall(sim)
    var here := sim.state.character.cell()
    assert_int(sim.state.threats.count()).is_greater(0)
    for threat in sim.state.threats.threats():
        var offset := threat.position - here
        assert_int(offset.x * offset.x + offset.y * offset.y).is_less_equal(
            ThreatField.MAX_CLEARANCE * ThreatField.MAX_CLEARANCE)


func test_threats_stand_on_something() -> void:
    var sim := _sim()
    _to_nightfall(sim)
    for threat in sim.state.threats.threats():
        assert_bool(sim.state.grid.is_solid(threat.position - VoxelGrid.UP)).is_true()


func test_a_threat_walks_towards_the_player() -> void:
    var sim := _sim()
    _to_nightfall(sim)
    var here := sim.state.character.cell()

    var before: Array = []
    for threat in sim.state.threats.threats():
        before.append(_flat_distance(threat.position, here))

    sim.advance(Threat.STEP_TICKS * 6)

    var closed_in := false
    var after := sim.state.threats.threats()
    for i in after.size():
        if _flat_distance(after[i].position, here) < before[i]:
            closed_in = true
    assert_bool(closed_in).is_true()


func test_a_threat_hurts_what_it_touches() -> void:
    var sim := _sim()
    _to_nightfall(sim)
    var threat := sim.state.threats.threats()[0]
    sim.state.character.place_at(threat.position + Vector3i(1, 0, 0))

    var before := sim.state.vitals.health
    sim.advance(3)
    assert_int(sim.state.vitals.health).is_less(before)


func test_hunger_wears_the_player_down_over_a_long_day() -> void:
    var sim := _sim()
    sim.advance(Vitals.FULLNESS_DECAY_TICKS * 3)
    assert_int(sim.state.vitals.fullness).is_less(Vitals.MAX_FULLNESS)


func test_falling_returns_the_player_to_the_start() -> void:
    var sim := _sim()
    sim.state.character.place_at(IslandBuilder.SPAWN + Vector3i(4, 0, 0))
    sim.state.vitals.damage(Vitals.MAX_HEALTH)
    sim.advance(2)

    assert_bool(sim.state.character.cell() == IslandBuilder.SPAWN).is_true()
    assert_int(sim.state.vitals.health).is_equal(Vitals.MAX_HEALTH)


func test_falling_costs_half_of_what_was_carried() -> void:
    # 시작 지급이 켜져 있을 수 있으므로 쓰러지기 직전 개수에서 재어 본다.
    var sim := _sim()
    sim.state.inventory.add(BlockType.WOOD, 8)
    sim.state.inventory.add(BlockType.STONE, 3)
    var wood := sim.state.inventory.count_of(BlockType.WOOD)
    var stone := sim.state.inventory.count_of(BlockType.STONE)

    sim.state.vitals.damage(Vitals.MAX_HEALTH)
    sim.advance(2)

    assert_int(sim.state.inventory.count_of(BlockType.WOOD)).is_equal(wood / 2)
    assert_int(sim.state.inventory.count_of(BlockType.STONE)).is_equal(stone / 2)


func test_what_was_built_survives_a_fall() -> void:
    # 실패는 가볍다. 만든 것은 남는다.
    var sim := _sim()
    var built := IslandBuilder.SPAWN + Vector3i(2, 0, 0)
    sim.state.grid.set_block(built, BlockType.STONE)
    sim.state.vitals.damage(Vitals.MAX_HEALTH)
    sim.advance(2)
    assert_int(sim.state.grid.get_block(built)).is_equal(BlockType.STONE)


func test_a_time_detector_wakes_at_night() -> void:
    var sim := _sim()
    var at := IslandBuilder.SPAWN + Vector3i(3, 0, 0)
    sim.state.grid.set_block(at, BlockType.DETECTOR)
    sim.state.circuit.add_part(DetectorPart.create(at, DetectorPart.TARGET_TIME))

    sim.advance(5)
    assert_bool(sim.state.circuit.part_at(at).output.is_present()).is_false()

    _to_nightfall(sim)
    sim.advance(2)
    assert_bool(sim.state.circuit.part_at(at).output.is_present()).is_true()


func test_a_threat_detector_reports_a_distance() -> void:
    var sim := _sim()
    _to_nightfall(sim)
    var threat := sim.state.threats.threats()[0]
    var at := threat.position + Vector3i(1, 0, 0)
    sim.state.grid.set_block(at, BlockType.DETECTOR)
    sim.state.circuit.add_part(DetectorPart.create(at, DetectorPart.TARGET_THREAT))

    sim.advance(2)
    var reading: SignalValue = sim.state.circuit.part_at(at).output
    assert_bool(reading.is_present()).is_true()
    assert_int(reading.as_int()).is_between(0, DetectorPart.SENSE_RADIUS)


func _flat_distance(a: Vector3i, b: Vector3i) -> int:
    return absi(a.x - b.x) + absi(a.y - b.y)
