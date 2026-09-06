extends GdUnitTestSuite

## 화면에 나갈 말 검증.
##
## 프로그래밍 용어가 화면에 새어 나가면 안 된다. 눈으로만 지키면 언젠가 샌다.

## 화면에 나와서는 안 되는 말들.
const FORBIDDEN: PackedStringArray = [
    "변수", "함수", "조건문", "반복문", "자료형", "형변환", "인자", "매개변수",
    "반환", "포인터", "배열", "스코프", "캡슐화", "불리언", "정수", "실수",
    "bool", "int", "float", "type", "block", "signal", "loop", "if", "var",
]


func _every_word() -> PackedStringArray:
    var words := PackedStringArray()
    for block_type in BlockType.COUNT:
        if block_type == BlockType.EMPTY or BlockType.is_door(block_type) and block_type == BlockType.DOOR_OPEN:
            continue
        words.append(PartWords.name_of(block_type))
        words.append(PartWords.description_of(block_type))
    for target in DetectorPart.TARGET_COUNT:
        words.append(PartWords.target_name(target))
    for shape in BoxPart.SHAPE_COUNT:
        words.append(PartWords.shape_name(shape))
    for i in InputController.REPEATER_PRESETS.size():
        words.append(PartWords.repeater_setting_name(i))
    for i in InputController.BRANCH_PRESETS.size():
        words.append(PartWords.branch_setting_name(i))
    return words


func test_no_programming_words_reach_the_screen() -> void:
    for word in _every_word():
        for banned in FORBIDDEN:
            assert_str(word.to_lower()).not_contains(banned)


func test_every_placeable_thing_has_a_name_and_a_line() -> void:
    for block_type in InputController.PLACEABLE:
        assert_str(PartWords.name_of(block_type)).is_not_empty()
        assert_str(PartWords.name_of(block_type)).is_not_equal("?")
        assert_str(PartWords.description_of(block_type)).is_not_empty()


func test_every_detector_target_has_a_name() -> void:
    for target in DetectorPart.TARGET_COUNT:
        assert_str(PartWords.target_name(target)).is_not_equal("?")


func test_every_box_shape_has_a_name() -> void:
    for shape in BoxPart.SHAPE_COUNT:
        assert_str(PartWords.shape_name(shape)).is_not_equal("?")


func test_every_setting_choice_has_a_name() -> void:
    for i in InputController.REPEATER_PRESETS.size():
        assert_str(PartWords.repeater_setting_name(i)).is_not_equal("?")
    for i in InputController.BRANCH_PRESETS.size():
        assert_str(PartWords.branch_setting_name(i)).is_not_equal("?")


func test_the_detector_line_tells_how_to_connect() -> void:
    # 자동문을 만들려면 잇기를 알아야 한다. 그 한 가지는 알려준다.
    assert_str(PartWords.description_of(BlockType.DETECTOR)).contains("잇기")


func test_names_are_distinct() -> void:
    var seen: Array = []
    for block_type in InputController.PLACEABLE:
        var word := PartWords.name_of(block_type)
        assert_bool(seen.has(word)).is_false()
        seen.append(word)
