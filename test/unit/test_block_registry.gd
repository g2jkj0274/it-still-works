extends GdUnitTestSuite

## 블록 속성 표 검증: 기본 표 로드, 범위 밖 id, 원문 거부, digest, Dictionary 미보관, sim 이름 비교 가드.


## 테스트용 행. [param on] 에 든 속성만 true.
func _row(id: int, name: String, durability: int, on: Array = []) -> Dictionary:
    var row: Dictionary = {"id": id, "name": name, "durability": durability}
    for attr in BlockRegistry.ATTRIBUTES:
        row[attr] = on.has(attr)
    return row


## 두 행짜리 작은 표. 거부 케이스는 이것을 조금씩 망가뜨린다.
func _rows() -> Array:
    return [_row(0, "air", 0), _row(1, "dirt", 8, ["solid"])]


## 키 순서를 보존한 채 원문으로 만든다 (sort_keys=false).
func _text(rows: Array, indent: String = "") -> String:
    return JSON.stringify(rows, indent, false)


# --- 기본 표 ---

func test_load_default_reads_the_initial_table() -> void:
    var registry := BlockRegistry.load_default()
    assert_object(registry).is_not_null()
    assert_int(registry.count()).is_equal(6)
    assert_bool(registry.has(1, &"solid")).is_true()
    assert_bool(registry.has(0, &"solid")).is_false()
    assert_bool(registry.has_at(3, BlockRegistry.ATTR_GRAVITY)).is_true()
    assert_bool(registry.has_at(4, BlockRegistry.ATTR_FLAMMABLE)).is_true()
    assert_bool(registry.has_at(1, BlockRegistry.ATTR_GRAVITY)).is_false()
    assert_int(registry.max_durability(2)).is_equal(20)
    assert_bool(registry.is_breakable(0)).is_false()
    assert_bool(registry.is_breakable(1)).is_true()
    assert_str(registry.name_of(0)).is_equal("air")


func test_attribute_indices_match_column_order() -> void:
    assert_int(BlockRegistry.ATTRIBUTES.size()).is_equal(8)
    assert_str(BlockRegistry.ATTRIBUTES[BlockRegistry.ATTR_SOLID]).is_equal("solid")
    assert_str(BlockRegistry.ATTRIBUTES[BlockRegistry.ATTR_PUSHABLE]).is_equal("pushable")
    assert_str(BlockRegistry.ATTRIBUTES[BlockRegistry.ATTR_CONDUCTIVE]).is_equal("conductive")
    assert_str(BlockRegistry.ATTRIBUTES[BlockRegistry.ATTR_CONTAINER]).is_equal("container")
    assert_str(BlockRegistry.ATTRIBUTES[BlockRegistry.ATTR_EMITS_SOUND]).is_equal("emits_sound")
    assert_str(BlockRegistry.ATTRIBUTES[BlockRegistry.ATTR_GRAVITY]).is_equal("gravity")
    assert_str(BlockRegistry.ATTRIBUTES[BlockRegistry.ATTR_FLAMMABLE]).is_equal("flammable")
    assert_str(BlockRegistry.ATTRIBUTES[BlockRegistry.ATTR_LIQUID]).is_equal("liquid")


func test_has_by_name_and_by_index_agree() -> void:
    var registry := BlockRegistry.load_default()
    for id in registry.count():
        for attr_index in BlockRegistry.ATTRIBUTES.size():
            var attr := StringName(BlockRegistry.ATTRIBUTES[attr_index])
            assert_bool(registry.has(id, attr)).is_equal(registry.has_at(id, attr_index))


# --- 범위 밖 ---

func test_out_of_range_id_is_false_zero_empty() -> void:
    var registry := BlockRegistry.load_default()
    for id: int in [-1, 6, 1000]:
        assert_bool(registry.has(id, &"solid")).is_false()
        assert_bool(registry.has_at(id, BlockRegistry.ATTR_SOLID)).is_false()
        assert_int(registry.max_durability(id)).is_equal(0)
        assert_bool(registry.is_breakable(id)).is_false()
        assert_str(registry.name_of(id)).is_equal("")


func test_unknown_attribute_is_false() -> void:
    var registry := BlockRegistry.load_default()
    assert_bool(registry.has(1, &"flamable")).is_false()
    assert_bool(registry.has_at(1, -1)).is_false()
    assert_bool(registry.has_at(1, BlockRegistry.ATTRIBUTES.size())).is_false()


# --- from_text 수용 ---

func test_from_text_accepts_a_well_formed_table() -> void:
    var registry := BlockRegistry.from_text(_text(_rows()))
    assert_object(registry).is_not_null()
    assert_int(registry.count()).is_equal(2)
    assert_bool(registry.has_at(1, BlockRegistry.ATTR_SOLID)).is_true()
    assert_int(registry.max_durability(1)).is_equal(8)


# --- from_text 거부 ---

func test_rejects_invalid_json() -> void:
    assert_object(BlockRegistry.from_text("[{")).is_null()


func test_rejects_top_level_object() -> void:
    assert_object(BlockRegistry.from_text(JSON.stringify({"id": 0}))).is_null()


func test_rejects_non_dictionary_row() -> void:
    assert_object(BlockRegistry.from_text("[1]")).is_null()


func test_rejects_id_not_equal_to_index() -> void:
    var rows := _rows()
    rows[1]["id"] = 2
    assert_object(BlockRegistry.from_text(_text(rows))).is_null()


func test_rejects_negative_id() -> void:
    var rows := _rows()
    rows[0]["id"] = -1
    assert_object(BlockRegistry.from_text(_text(rows))).is_null()


func test_rejects_missing_key() -> void:
    var rows := _rows()
    rows[1].erase("liquid")
    assert_object(BlockRegistry.from_text(_text(rows))).is_null()


func test_rejects_unknown_key() -> void:
    var rows := _rows()
    rows[1]["flamable"] = rows[1]["flammable"]
    rows[1].erase("flammable")
    assert_object(BlockRegistry.from_text(_text(rows))).is_null()


func test_rejects_extra_key() -> void:
    var rows := _rows()
    rows[1]["color"] = "brown"
    assert_object(BlockRegistry.from_text(_text(rows))).is_null()


func test_rejects_fractional_durability() -> void:
    var rows := _rows()
    rows[1]["durability"] = 6.5
    assert_object(BlockRegistry.from_text(_text(rows))).is_null()


func test_rejects_negative_durability() -> void:
    var rows := _rows()
    rows[1]["durability"] = -3
    assert_object(BlockRegistry.from_text(_text(rows))).is_null()


func test_rejects_durability_above_255() -> void:
    # Chunk 는 현재 내구도를 한 바이트에 담는다. 초기값이 그 폭을 넘으면 표 자체를 거부한다.
    var rows := _rows()
    rows[1]["durability"] = 255
    assert_object(BlockRegistry.from_text(_text(rows))).is_not_null()
    rows[1]["durability"] = 256
    assert_object(BlockRegistry.from_text(_text(rows))).is_null()


func test_rejects_more_than_256_rows() -> void:
    # Chunk 의 셀 id 는 한 바이트다. 256 행은 받고 257 행은 거부한다.
    var rows: Array = []
    for id in 256:
        rows.append(_row(id, "b%d" % id, 1))
    assert_object(BlockRegistry.from_text(_text(rows))).is_not_null()
    rows.append(_row(256, "b256", 1))
    assert_object(BlockRegistry.from_text(_text(rows))).is_null()


func test_rejects_number_in_boolean_slot() -> void:
    var rows := _rows()
    rows[1]["solid"] = 0
    assert_object(BlockRegistry.from_text(_text(rows))).is_null()


func test_rejects_string_in_boolean_slot() -> void:
    var rows := _rows()
    rows[1]["solid"] = "true"
    assert_object(BlockRegistry.from_text(_text(rows))).is_null()


func test_rejects_empty_name() -> void:
    var rows := _rows()
    rows[1]["name"] = ""
    assert_object(BlockRegistry.from_text(_text(rows))).is_null()


func test_rejects_non_string_name() -> void:
    var rows := _rows()
    rows[1]["name"] = 7
    assert_object(BlockRegistry.from_text(_text(rows))).is_null()


# --- digest ---

func test_digest_is_fixed_length_hex() -> void:
    var digest := BlockRegistry.load_default().digest()
    assert_str(digest).has_length(64)
    assert_bool(digest.is_valid_hex_number(false)).is_true()


func test_digest_ignores_whitespace_and_key_order() -> void:
    var plain := BlockRegistry.from_text(_text(_rows()))
    # 같은 표를 들여쓰기하고 키 순서를 뒤집는다.
    var reversed: Array = []
    for row: Dictionary in _rows():
        var keys := row.keys()
        keys.reverse()
        var shuffled: Dictionary = {}
        for key: String in keys:
            shuffled[key] = row[key]
        reversed.append(shuffled)
    var indented := BlockRegistry.from_text(_text(reversed, "\t"))
    assert_object(indented).is_not_null()
    assert_str(indented.digest()).is_equal(plain.digest())


func test_digest_changes_when_one_value_changes() -> void:
    var base := BlockRegistry.from_text(_text(_rows())).digest()
    var rows := _rows()
    rows[1]["gravity"] = true
    assert_str(BlockRegistry.from_text(_text(rows)).digest()).is_not_equal(base)
    rows = _rows()
    rows[1]["durability"] = 9
    assert_str(BlockRegistry.from_text(_text(rows)).digest()).is_not_equal(base)
    rows = _rows()
    rows[1]["name"] = "soil"
    assert_str(BlockRegistry.from_text(_text(rows)).digest()).is_not_equal(base)


func test_digest_is_built_from_attribute_order_then_rows() -> void:
    # digest 의 입력을 여기서 독립적으로 재구성한다. 속성 열 순서가 첫 필드로 들어가야
    # ATTRIBUTES 순서가 바뀌었을 때 digest 도 바뀐다.
    var registry := BlockRegistry.load_default()
    var fields: Array = []
    fields.append(["attributes", ",".join(BlockRegistry.ATTRIBUTES)])
    fields.append(["count", registry.count()])
    for id in registry.count():
        fields.append(["%d.name" % id, registry.name_of(id)])
        fields.append(["%d.durability" % id, registry.max_durability(id)])
        for attr_index in BlockRegistry.ATTRIBUTES.size():
            var attr: String = BlockRegistry.ATTRIBUTES[attr_index]
            fields.append(["%d.%s" % [id, attr], 1 if registry.has_at(id, attr_index) else 0])
    assert_str(registry.digest()).is_equal(SimHash.hash_fields(fields))


# --- Dictionary 미보관 ---

func test_registry_keeps_no_dictionary() -> void:
    var registry := BlockRegistry.from_text(_text(_rows()))
    var script_variables := 0
    for property: Dictionary in registry.get_property_list():
        if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
            continue
        script_variables += 1
        assert_int(property["type"]).override_failure_message(
            "스크립트 변수 '%s' 가 Dictionary 다" % property["name"]
        ).is_not_equal(TYPE_DICTIONARY)
    # 리플렉션이 스크립트 변수를 돌려주지 않으면 위 단언은 비어 있는 것이다.
    assert_int(script_variables).is_greater(0)


# --- sim 가드 ---

func test_no_sim_code_compares_block_names() -> void:
    # name_of 는 표현 레이어 전용이다. sim 안에서 부르면 P2 위반으로 간다.
    var offenders := PackedStringArray()
    _collect_name_of_callers("res://sim", offenders)
    assert_array(offenders).is_empty()


func _collect_name_of_callers(dir_path: String, offenders: PackedStringArray) -> void:
    var dir := DirAccess.open(dir_path)
    assert_object(dir).is_not_null()
    if dir == null:
        return
    dir.list_dir_begin()
    var entry := dir.get_next()
    while entry != "":
        var path := dir_path.path_join(entry)
        if dir.current_is_dir():
            _collect_name_of_callers(path, offenders)
        elif entry.get_extension() == "gd" and entry != "block_registry.gd":
            if FileAccess.get_file_as_string(path).contains("name_of("):
                offenders.append(path)
        entry = dir.get_next()
    dir.list_dir_end()
