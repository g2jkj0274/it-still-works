extends GdUnitTestSuite

## 자리에 남아 있는 것은 화면에도 남아 있어야 한다.
##
## 오래 숨어 있던 결함이 여기 있었다. [method VoxelGrid.is_exposed] 가
## "통과할 수 있는가"([method BlockType.is_solid])를 물어 왔기 때문에
## **열린 문이 한 번도 그려지지 않았다.** 메시는 서른여섯 꼭짓점으로 만들어져
## 있는데 화면에 나간 적이 없다.
##
## 그래서 자동문이 열리면 문이 열린 것이 아니라 **사라진 것**으로 보였다.
## 스펙 §5 의 첫 장치이자 §8 이 조작감을 판정하라고 지목한 자리이고,
## 코어 루프의 유일한 보상이 그 그림이다. 스펙 §3.1 도 "열린 문은 지나갈 수
## 있지만 자리에 남아 있다. 빈 칸과 다르다"고 적는다.


func _grid_with(block_type: int) -> VoxelGrid:
    var grid := VoxelGrid.new()
    grid.set_block(Vector3i(5, 5, 1), BlockType.GROUND)
    grid.set_block(Vector3i(5, 5, 2), block_type)
    return grid


func test_an_open_door_is_drawn() -> void:
    var grid := _grid_with(BlockType.DOOR_OPEN)
    assert_bool(grid.is_exposed(Vector3i(5, 5, 2))).override_failure_message(
        "열린 문이 그려지지 않는다. 문이 열린 것이 아니라 사라진 것으로 보인다"
        ).is_true()


func test_a_torch_is_drawn() -> void:
    var grid := _grid_with(BlockType.TORCH)
    assert_bool(grid.is_exposed(Vector3i(5, 5, 2))).is_true()


func test_everything_that_stays_in_place_is_drawn() -> void:
    # 지나갈 수 있는지와 그려지는지는 다른 물음이다. 빈 칸과 손에만 드는 것만
    # 그려지지 않는다.
    for type in BlockType.COUNT:
        var drawn := BlockType.is_drawn(type)
        var wanted := type != BlockType.EMPTY and not BlockType.is_handheld(type)
        assert_bool(drawn).override_failure_message(
            "%s 의 그려짐 판정이 어긋난다" % BlockType.name_of(type)).is_equal(wanted)


func test_things_that_are_drawn_all_have_a_mesh() -> void:
    # 그린다고 해 놓고 메시가 비면 빈 칸과 다를 것이 없다.
    for type in BlockType.COUNT:
        if not BlockType.is_drawn(type):
            continue
        var vertices: PackedVector3Array = BlockMeshes.for_block(type).surface_get_arrays(
            0)[Mesh.ARRAY_VERTEX]
        assert_int(vertices.size()).override_failure_message(
            "%s 에 그릴 것이 없다" % BlockType.name_of(type)).is_greater(0)


func test_a_buried_block_is_still_skipped() -> void:
    # 속에 묻힌 것을 걸러 내는 본래 일은 그대로여야 한다.
    var grid := VoxelGrid.new()
    for z in 3:
        for y in 3:
            for x in 3:
                grid.set_block(Vector3i(x + 4, y + 4, z + 1), BlockType.ROCK)
    assert_bool(grid.is_exposed(Vector3i(5, 5, 2))).is_false()
