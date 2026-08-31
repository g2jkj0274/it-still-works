extends GdUnitTestSuite

## 수작업 배치된 섬의 모양과 재현성 검증.


func _built() -> VoxelGrid:
    var grid := VoxelGrid.new()
    IslandBuilder.build(grid)
    return grid


func test_build_is_reproducible() -> void:
    assert_str(_built().digest()).is_equal(_built().digest())


func test_build_consumes_no_randomness() -> void:
    # 수작업 배치다. 난수를 건드리면 섬 배치가 이후 모든 뽑기를 밀어낸다.
    var state := WorldState.new(SimRng.new(7))
    var before := state.rng.get_state()
    IslandBuilder.populate(state)
    assert_int(state.rng.get_state()).is_equal(before)


func test_island_centre_is_ground() -> void:
    var grid := _built()
    assert_int(grid.get_block(Vector3i(32, 32, 0))).is_equal(BlockType.GROUND)
    assert_int(grid.get_block(Vector3i(32, 32, IslandBuilder.GROUND_TOP_Z))).is_equal(BlockType.GROUND)


func test_island_corners_are_open_water() -> void:
    var grid := _built()
    for corner in [Vector3i(0, 0, 0), Vector3i(63, 0, 0), Vector3i(0, 63, 0), Vector3i(63, 63, 0)]:
        assert_bool(grid.is_solid(corner)).is_false()


func test_island_fits_inside_the_grid() -> void:
    var grid := _built()
    for z in VoxelGrid.SIZE_Z:
        for i in VoxelGrid.SIZE_X:
            assert_bool(grid.is_solid(Vector3i(i, 0, z))).is_false()
            assert_bool(grid.is_solid(Vector3i(i, VoxelGrid.SIZE_Y - 1, z))).is_false()
            assert_bool(grid.is_solid(Vector3i(0, i, z))).is_false()
            assert_bool(grid.is_solid(Vector3i(VoxelGrid.SIZE_X - 1, i, z))).is_false()


func test_nothing_reaches_the_ceiling() -> void:
    var grid := _built()
    for y in VoxelGrid.SIZE_Y:
        for x in VoxelGrid.SIZE_X:
            assert_bool(grid.is_solid(Vector3i(x, y, VoxelGrid.SIZE_Z - 1))).is_false()


func test_spawn_is_standable() -> void:
    var grid := _built()
    var spawn := IslandBuilder.SPAWN
    assert_bool(grid.is_solid(spawn - VoxelGrid.UP)).is_true()
    for offset in CharacterState.HEIGHT:
        assert_bool(grid.is_free(spawn + VoxelGrid.UP * offset)).is_true()


func test_populate_places_the_character_at_spawn() -> void:
    var state := WorldState.new(SimRng.new(1))
    IslandBuilder.populate(state)
    assert_bool(state.character.position == IslandBuilder.SPAWN).is_true()
    assert_bool(state.grid.is_solid(Vector3i(32, 32, 0))).is_true()


func test_hill_rises_above_the_plain() -> void:
    var grid := _built()
    var hill := IslandBuilder.HILL_CENTER
    assert_bool(grid.is_solid(Vector3i(hill.x, hill.y, IslandBuilder.GROUND_TOP_Z + 1))).is_true()
    assert_bool(grid.is_solid(Vector3i(32, 32, IslandBuilder.GROUND_TOP_Z + 1))).is_false()


func test_ore_sites_hold_stone() -> void:
    var grid := _built()
    for site in IslandBuilder.ORE_SITES:
        assert_int(grid.get_block(Vector3i(site.x, site.y, IslandBuilder.GROUND_TOP_Z + 1))).is_equal(BlockType.STONE)


func test_ore_sites_are_away_from_spawn() -> void:
    # 왕복 거리가 있어야 자동 운반 장치의 동기가 생긴다.
    for site in IslandBuilder.ORE_SITES:
        var offset := site - Vector2i(IslandBuilder.SPAWN.x, IslandBuilder.SPAWN.y)
        assert_int(offset.x * offset.x + offset.y * offset.y).is_greater(100)


func test_trees_are_wood_and_stand_on_ground() -> void:
    var grid := _built()
    var planted := 0
    for trunk in IslandBuilder.TREES:
        var base := Vector3i(trunk.x, trunk.y, IslandBuilder.GROUND_TOP_Z + 1)
        if grid.get_block(base) != BlockType.WOOD:
            continue
        planted += 1
        assert_bool(grid.is_solid(base - VoxelGrid.UP)).is_true()
        for offset in IslandBuilder.TREE_HEIGHT:
            assert_int(grid.get_block(base + VoxelGrid.UP * offset)).is_equal(BlockType.WOOD)
    assert_int(planted).is_equal(IslandBuilder.TREES.size())


func test_island_is_neither_empty_nor_full() -> void:
    var grid := _built()
    var solid := 0
    for z in VoxelGrid.SIZE_Z:
        for y in VoxelGrid.SIZE_Y:
            for x in VoxelGrid.SIZE_X:
                if grid.is_solid(Vector3i(x, y, z)):
                    solid += 1
    assert_int(solid).is_greater(1000)
    assert_int(solid).is_less(VoxelGrid.CELL_COUNT)
