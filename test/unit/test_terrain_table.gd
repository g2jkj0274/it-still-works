extends GdUnitTestSuite

## 지형 규칙 표 검증: 기본 표 로드, 원문 거부, digest, Dictionary 미보관, Node 아님.


func _registry() -> BlockRegistry:
    return BlockRegistry.load_default()


## 기본 표와 같은 내용의 딕셔너리. 거부 케이스는 이것을 조금씩 망가뜨린다.
func _table() -> Dictionary:
    return {
        "under_zones": [2, 1],
        "ground_zones": [0, 3],
        "ground_scatter": [
            {"id": 5, "per_256": 20},
            {"id": 2, "per_256": 6},
            {"id": 4, "per_256": 4},
        ],
    }


## 키 순서를 보존한 채 원문으로 만든다 (sort_keys=false).
func _text(table: Variant, indent: String = "") -> String:
    return JSON.stringify(table, indent, false)


func _parse(table: Variant) -> TerrainTable:
    return TerrainTable.from_text(_text(table), _registry())


# --- 기본 표 ---

func test_load_default_reads_the_initial_table() -> void:
    var table := TerrainTable.load_default(_registry())
    assert_object(table).is_not_null()
    assert_int(table.under_zone_count()).is_equal(2)
    assert_int(table.under_zone(0)).is_equal(2)
    assert_int(table.under_zone(1)).is_equal(1)
    assert_int(table.ground_zone_count()).is_equal(2)
    assert_int(table.ground_zone(0)).is_equal(0)
    assert_int(table.ground_zone(1)).is_equal(3)
    assert_int(table.scatter_count()).is_equal(3)
    assert_int(table.scatter_id(0)).is_equal(5)
    assert_int(table.scatter_per_256(0)).is_equal(20)
    assert_int(table.scatter_id(1)).is_equal(2)
    assert_int(table.scatter_per_256(1)).is_equal(6)
    assert_int(table.scatter_id(2)).is_equal(4)
    assert_int(table.scatter_per_256(2)).is_equal(4)
    var total := 0
    for i in table.scatter_count():
        total += table.scatter_per_256(i)
    assert_int(total).is_equal(30)


func test_default_table_matches_inline_copy() -> void:
    assert_str(TerrainTable.load_default(_registry()).digest()).is_equal(_parse(_table()).digest())


func test_out_of_range_accessors_return_zero() -> void:
    var table := _parse(_table())
    assert_int(table.under_zone(-1)).is_equal(0)
    assert_int(table.under_zone(2)).is_equal(0)
    assert_int(table.ground_zone(-1)).is_equal(0)
    assert_int(table.ground_zone(2)).is_equal(0)
    assert_int(table.scatter_id(-1)).is_equal(0)
    assert_int(table.scatter_id(3)).is_equal(0)
    assert_int(table.scatter_per_256(-1)).is_equal(0)
    assert_int(table.scatter_per_256(3)).is_equal(0)


# --- from_text 수용 ---

func test_accepts_well_formed_table_preserving_order() -> void:
    var table := _table()
    table["under_zones"] = [1, 2, 4]
    var parsed := _parse(table)
    assert_object(parsed).is_not_null()
    assert_int(parsed.under_zone_count()).is_equal(3)
    assert_int(parsed.under_zone(0)).is_equal(1)
    assert_int(parsed.under_zone(1)).is_equal(2)
    assert_int(parsed.under_zone(2)).is_equal(4)


func test_accepts_per_256_boundaries() -> void:
    var table := _table()
    table["ground_scatter"] = [{"id": 5, "per_256": 0}, {"id": 2, "per_256": 256}]
    assert_object(_parse(table)).is_not_null()


# --- from_text 거부 ---

func test_rejects_invalid_json() -> void:
    assert_object(TerrainTable.from_text("{", _registry())).is_null()


func test_rejects_null_registry() -> void:
    assert_object(TerrainTable.from_text(_text(_table()), null)).is_null()


func test_rejects_top_level_array() -> void:
    assert_object(_parse([_table()])).is_null()


func test_rejects_missing_key() -> void:
    for key: String in ["under_zones", "ground_zones", "ground_scatter"]:
        var table := _table()
        table.erase(key)
        assert_object(_parse(table)).override_failure_message("'%s' 없는 표를 받아들였다" % key).is_null()


func test_rejects_extra_key() -> void:
    var table := _table()
    table["upper_zones"] = [0]
    assert_object(_parse(table)).is_null()


func test_rejects_empty_list() -> void:
    for key: String in ["under_zones", "ground_zones", "ground_scatter"]:
        var table := _table()
        table[key] = []
        assert_object(_parse(table)).override_failure_message("'%s' 가 빈 표를 받아들였다" % key).is_null()


func test_rejects_non_array_list() -> void:
    var table := _table()
    table["under_zones"] = 2
    assert_object(_parse(table)).is_null()


func test_rejects_id_out_of_registry_range() -> void:
    var count := _registry().count()
    var table := _table()
    table["under_zones"] = [count]
    assert_object(_parse(table)).is_null()
    table = _table()
    table["ground_zones"] = [0, count]
    assert_object(_parse(table)).is_null()
    table = _table()
    table["ground_scatter"] = [{"id": count, "per_256": 1}]
    assert_object(_parse(table)).is_null()
    table = _table()
    table["under_zones"] = [-1]
    assert_object(_parse(table)).is_null()


func test_rejects_air_in_under_zones() -> void:
    var table := _table()
    table["under_zones"] = [2, 0]
    assert_object(_parse(table)).is_null()


func test_rejects_non_solid_in_under_zones() -> void:
    # 두 행짜리 레지스트리에 solid 아닌 블록을 하나 둔다.
    var rows: Array = []
    for id in 3:
        var row: Dictionary = {"id": id, "name": "b%d" % id, "durability": 1 if id > 0 else 0}
        for attr in BlockRegistry.ATTRIBUTES:
            row[attr] = (attr == "solid" and id == 1)
        rows.append(row)
    var registry := BlockRegistry.from_text(JSON.stringify(rows))
    assert_object(registry).is_not_null()
    assert_bool(registry.has_at(2, BlockRegistry.ATTR_SOLID)).is_false()
    var table := {"under_zones": [1], "ground_zones": [0, 1], "ground_scatter": [{"id": 1, "per_256": 1}]}
    assert_object(TerrainTable.from_text(_text(table), registry)).is_not_null()
    table["under_zones"] = [1, 2]
    assert_object(TerrainTable.from_text(_text(table), registry)).is_null()
    table["under_zones"] = [1]
    table["ground_zones"] = [0, 2]
    assert_object(TerrainTable.from_text(_text(table), registry)).is_null()
    table["ground_zones"] = [0, 1]
    table["ground_scatter"] = [{"id": 2, "per_256": 1}]
    assert_object(TerrainTable.from_text(_text(table), registry)).is_null()


func test_rejects_air_in_scatter() -> void:
    var table := _table()
    table["ground_scatter"] = [{"id": 0, "per_256": 5}]
    assert_object(_parse(table)).is_null()


func test_rejects_per_256_above_256() -> void:
    var table := _table()
    table["ground_scatter"] = [{"id": 5, "per_256": 257}]
    assert_object(_parse(table)).is_null()


func test_rejects_negative_per_256() -> void:
    var table := _table()
    table["ground_scatter"] = [{"id": 5, "per_256": -1}]
    assert_object(_parse(table)).is_null()


func test_rejects_per_256_sum_above_256() -> void:
    var table := _table()
    table["ground_scatter"] = [{"id": 5, "per_256": 200}, {"id": 2, "per_256": 100}]
    assert_object(_parse(table)).is_null()


func test_rejects_fractional_values() -> void:
    var table := _table()
    table["ground_scatter"][1]["per_256"] = 6.5
    assert_object(_parse(table)).is_null()
    table = _table()
    table["under_zones"] = [2.5]
    assert_object(_parse(table)).is_null()
    table = _table()
    table["ground_scatter"][0]["id"] = 5.5
    assert_object(_parse(table)).is_null()


func test_rejects_non_number_id() -> void:
    var table := _table()
    table["under_zones"] = ["stone"]
    assert_object(_parse(table)).is_null()


func test_rejects_scatter_entry_with_extra_key() -> void:
    var table := _table()
    table["ground_scatter"][0]["name"] = "grass"
    assert_object(_parse(table)).is_null()


func test_rejects_scatter_entry_with_missing_key() -> void:
    var table := _table()
    table["ground_scatter"][0].erase("per_256")
    assert_object(_parse(table)).is_null()


func test_rejects_non_dictionary_scatter_entry() -> void:
    var table := _table()
    table["ground_scatter"] = [5]
    assert_object(_parse(table)).is_null()


# --- digest ---

func test_digest_is_fixed_length_hex() -> void:
    var digest := TerrainTable.load_default(_registry()).digest()
    assert_str(digest).has_length(64)
    assert_bool(digest.is_valid_hex_number(false)).is_true()


func test_same_content_same_digest() -> void:
    assert_str(_parse(_table()).digest()).is_equal(_parse(_table()).digest())


func test_digest_changes_when_one_value_changes() -> void:
    var base := _parse(_table()).digest()
    var table := _table()
    table["ground_scatter"][0]["per_256"] = 21
    assert_str(_parse(table).digest()).is_not_equal(base)
    table = _table()
    table["under_zones"] = [1, 2]
    assert_str(_parse(table).digest()).is_not_equal(base)
    table = _table()
    table["ground_zones"] = [0, 3, 1]
    assert_str(_parse(table).digest()).is_not_equal(base)


func test_digest_ignores_whitespace_and_key_order() -> void:
    var plain := _parse(_table())
    var reversed: Dictionary = {}
    var keys := _table().keys()
    keys.reverse()
    for key: String in keys:
        reversed[key] = _table()[key]
    # 흩뿌림 항목의 키 순서도 뒤집는다.
    var scatter: Array = []
    for entry: Dictionary in reversed["ground_scatter"]:
        scatter.append({"per_256": entry["per_256"], "id": entry["id"]})
    reversed["ground_scatter"] = scatter
    var indented := TerrainTable.from_text(_text(reversed, "\t"), _registry())
    assert_object(indented).is_not_null()
    assert_str(indented.digest()).is_equal(plain.digest())


func test_digest_is_built_from_ordered_lists() -> void:
    var table := _parse(_table())
    var fields: Array = []
    fields.append(["under.count", table.under_zone_count()])
    for i in table.under_zone_count():
        fields.append(["under.%d" % i, table.under_zone(i)])
    fields.append(["ground.count", table.ground_zone_count()])
    for i in table.ground_zone_count():
        fields.append(["ground.%d" % i, table.ground_zone(i)])
    fields.append(["scatter.count", table.scatter_count()])
    for i in table.scatter_count():
        fields.append(["scatter.%d.id" % i, table.scatter_id(i)])
        fields.append(["scatter.%d.per_256" % i, table.scatter_per_256(i)])
    assert_str(table.digest()).is_equal(SimHash.hash_fields(fields))


# --- Dictionary 미보관 ---

func test_table_keeps_no_dictionary() -> void:
    var table := _parse(_table())
    var script_variables := 0
    for property: Dictionary in table.get_property_list():
        if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
            continue
        script_variables += 1
        assert_int(property["type"]).override_failure_message(
            "스크립트 변수 '%s' 가 Dictionary 다" % property["name"]
        ).is_not_equal(TYPE_DICTIONARY)
    assert_int(script_variables).is_greater(0)


# --- Node 아님 ---

func test_table_is_not_a_node() -> void:
    var table: Variant = TerrainTable.new()
    assert_str(table.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(table.get_class(), "Node")).is_false()
    assert_bool(table is Node).is_false()
    assert_bool(table is RefCounted).is_true()
