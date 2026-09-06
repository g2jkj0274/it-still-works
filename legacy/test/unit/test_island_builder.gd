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


func test_the_surface_is_soil_and_below_it_is_rock() -> void:
    # 지표 가까이는 흙, 그 아래는 돌이다. 파고 내려가면 달라지는 것이 보여야 한다.
    var grid := _built()
    var column := IslandBuilder.SPAWN_COLUMN
    var top := IslandBuilder.surface_z(column)

    assert_int(grid.get_block(Vector3i(column.x, column.y, top))).is_equal(BlockType.GROUND)
    assert_int(grid.get_block(Vector3i(column.x, column.y, VoxelGrid.BEDROCK_Z))).is_equal(
        BlockType.ROCK)


func test_there_is_room_to_dig() -> void:
    # 예전에는 지면이 두 층뿐이고 바닥층은 부술 수 없어 **팔 수 있는 땅이 한
    # 층**이었다. 파고 내려갈 곳이 없으면 캐는 일이 성립하지 않는다.
    var column := IslandBuilder.SPAWN_COLUMN
    var diggable := IslandBuilder.surface_z(column) - VoxelGrid.BEDROCK_Z
    assert_int(diggable).is_greater_equal(6)


func test_the_island_can_be_walked_from_end_to_end() -> void:
    # 두 칸 턱은 오르지 못한다(스펙 §3.3). 지형이 사람을 가두면 안 된다.
    var grid := _built()
    var reached := _walk_from(grid, IslandBuilder.spawn_cell())

    var land := 0
    var missed := 0
    for y in VoxelGrid.SIZE_Y:
        for x in VoxelGrid.SIZE_X:
            if IslandBuilder.surface_z(Vector2i(x, y)) < 0:
                continue
            land += 1
            if not reached.has(Vector2i(x, y)):
                missed += 1

    assert_int(land).is_greater(2000)
    # 광석 더미 꼭대기처럼 한 칸 쌓아야 오르는 자리는 남겨 둔다.
    assert_int(missed * 100).is_less(land)


## 시작 자리에서 걸어 닿는 기둥들.
func _walk_from(grid: VoxelGrid, start: Vector3i) -> Dictionary:
    var seen := {start: true}
    var columns := {Vector2i(start.x, start.y): true}
    var queue: Array[Vector3i] = []
    queue.append(start)

    while not queue.is_empty():
        var here: Vector3i = queue.pop_back()
        for offset: Vector3i in [
            Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0),
        ]:
            for lift in [1, 0, -1, -2, -3, -4]:
                var there: Vector3i = here + offset + Vector3i(0, 0, int(lift))
                if seen.has(there):
                    break
                if not MovementRules.can_occupy(grid, there):
                    continue
                if not MovementRules.is_supported(grid, there):
                    continue
                seen[there] = true
                columns[Vector2i(there.x, there.y)] = true
                queue.append(there)
                break
    return columns


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
    var spawn := IslandBuilder.spawn_cell()
    assert_bool(grid.is_solid(spawn - VoxelGrid.UP)).is_true()
    for offset in CharacterState.HEIGHT:
        assert_bool(grid.is_free(spawn + VoxelGrid.UP * offset)).is_true()


func test_populate_places_the_character_at_spawn() -> void:
    var state := WorldState.new(SimRng.new(1))
    IslandBuilder.populate(state)
    assert_bool(state.character.cell() == IslandBuilder.spawn_cell()).is_true()
    assert_bool(state.grid.is_solid(Vector3i(32, 32, 0))).is_true()


func test_hill_rises_above_what_is_around_it() -> void:
    var hill := IslandBuilder.HILL_CENTER
    var peak := IslandBuilder.surface_z(hill)
    var foot := IslandBuilder.surface_z(hill + Vector2i(IslandBuilder.HILL_RADIUS + 3, 0))
    assert_int(peak).is_greater(foot)


func test_the_ground_never_rises_by_more_than_one_at_a_time() -> void:
    # 두 칸 턱은 오르지 못한다. 여기저기 절벽이 생기는 것은 괜찮지만
    # 그것이 흔해지면 섬이 걸어 다닐 수 없는 곳이 된다.
    var steep := 0
    var columns := 0
    for y in VoxelGrid.SIZE_Y:
        for x in VoxelGrid.SIZE_X:
            var here := IslandBuilder.surface_z(Vector2i(x, y))
            if here < 0:
                continue
            columns += 1
            for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
                var there := IslandBuilder.surface_z(Vector2i(x, y) + offset)
                if there >= 0 and absi(there - here) > 1:
                    steep += 1
    assert_int(steep * 20).is_less(columns)


func test_ore_sites_stand_on_the_surface() -> void:
    var grid := _built()
    for site in IslandBuilder.ORE_SITES:
        var top := IslandBuilder.surface_z(site)
        assert_int(grid.get_block(Vector3i(site.x, site.y, top + 1))).is_equal(BlockType.ORE)


func test_ore_hides_deep_and_not_at_the_surface() -> void:
    # 얕은 곳에서 나오면 내려갈 이유가 없다.
    var grid := _built()
    var deep := 0
    var shallow := 0
    for y in VoxelGrid.SIZE_Y:
        for x in VoxelGrid.SIZE_X:
            for z in VoxelGrid.SIZE_Z:
                if grid.get_block(Vector3i(x, y, z)) != BlockType.ORE:
                    continue
                if z <= IslandBuilder.VEIN_TOP_Z:
                    deep += 1
                else:
                    shallow += 1
    assert_int(deep).is_greater(200)
    assert_int(deep).is_greater(shallow)


func test_there_are_hollows_under_the_ground() -> void:
    # 파고 내려갈 이유이고, 광맥이 드러나는 자리다.
    var grid := _built()
    var hollow := 0
    for y in VoxelGrid.SIZE_Y:
        for x in VoxelGrid.SIZE_X:
            var top := IslandBuilder.surface_z(Vector2i(x, y))
            if top < 0:
                continue
            for z in range(VoxelGrid.BEDROCK_Z + 1, top - IslandBuilder.SOIL_DEPTH):
                if not grid.is_solid(Vector3i(x, y, z)):
                    hollow += 1
    assert_int(hollow).is_greater(500)


func test_ore_sites_are_away_from_spawn() -> void:
    # 왕복 거리가 있어야 자동 운반 장치의 동기가 생긴다.
    for site in IslandBuilder.ORE_SITES:
        var offset := site - Vector2i(IslandBuilder.SPAWN_COLUMN.x, IslandBuilder.SPAWN_COLUMN.y)
        assert_int(offset.x * offset.x + offset.y * offset.y).is_greater(100)


func test_trees_are_wood_and_stand_on_ground() -> void:
    var grid := _built()
    var planted := 0
    for trunk in IslandBuilder.TREES:
        var base := Vector3i(trunk.x, trunk.y, IslandBuilder.surface_z(trunk) + 1)
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


func test_ore_shows_on_the_walls_of_the_hollows() -> void:
    # **땅속에 들어갈 까닭이 있어야 한다.** 광맥이 바위 속에만 들면 굴을 파도
    # 회색 벽뿐이고, 어디를 파야 할지 몰라 아무 데나 파게 된다. 드러난 벽에
    # 광석이 박혀 있어야 눈이 목적지를 잡는다.
    var grid := _built()
    var bare := 0
    var bare_ore := 0

    for z in range(VoxelGrid.BEDROCK_Z + 1, IslandBuilder.VEIN_TOP_Z + 1):
        for y in VoxelGrid.SIZE_Y:
            for x in VoxelGrid.SIZE_X:
                var cell := Vector3i(x, y, z)
                var block := grid.get_block(cell)
                if block != BlockType.ROCK and block != BlockType.ORE:
                    continue
                if not _is_bare(grid, cell):
                    continue
                bare += 1
                if block == BlockType.ORE:
                    bare_ore += 1

    assert_int(bare).is_greater(100)
    # 드러난 벽 스무 칸에 하나쯤은 광석이어야 눈에 걸린다.
    assert_int(bare_ore * 20).is_greater(bare)


func test_ore_is_not_only_on_the_walls() -> void:
    # 벽에만 나면 캐고 나서 더 파고 들어갈 까닭이 없다.
    var grid := _built()
    var buried := 0
    for z in range(VoxelGrid.BEDROCK_Z + 1, IslandBuilder.VEIN_TOP_Z + 1):
        for y in VoxelGrid.SIZE_Y:
            for x in VoxelGrid.SIZE_X:
                var cell := Vector3i(x, y, z)
                if grid.get_block(cell) == BlockType.ORE and not _is_bare(grid, cell):
                    buried += 1
    assert_int(buried).is_greater(50)


func _is_bare(grid: VoxelGrid, cell: Vector3i) -> bool:
    for step: Vector3i in [
        Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
        Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
    ]:
        if grid.get_block(cell + step) == BlockType.EMPTY:
            return true
    return false
