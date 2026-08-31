extends GdUnitTestSuite

## 월드 상태 해시의 토대가 되는 정규화·다이제스트 검증.


func test_same_input_same_hash() -> void:
    assert_str(SimHash.hash_text("a=1;b=2")).is_equal(SimHash.hash_text("a=1;b=2"))


func test_different_input_different_hash() -> void:
    assert_str(SimHash.hash_text("a=1")).is_not_equal(SimHash.hash_text("a=2"))


func test_hash_is_fixed_length_hex() -> void:
    var digest := SimHash.hash_text("x")
    assert_str(digest).has_length(64)
    assert_bool(digest.is_valid_hex_number(false)).is_true()


func test_field_encoding_is_unambiguous() -> void:
    # 구분자 없이 이어붙이면 아래 두 입력이 같은 문자열로 뭉개진다.
    # 길이 접두사가 그것을 막는지 확인한다.
    var left := SimHash.hash_fields([["a", 1], ["b", 2]])
    var right := SimHash.hash_fields([["a", 12], ["b", 0]])
    assert_str(left).is_not_equal(right)


func test_field_order_matters() -> void:
    var left := SimHash.hash_fields([["a", 1], ["b", 2]])
    var right := SimHash.hash_fields([["b", 2], ["a", 1]])
    assert_str(left).is_not_equal(right)


func test_empty_fields_hash_is_stable() -> void:
    assert_str(SimHash.hash_fields([])).is_equal(SimHash.hash_fields([]))
