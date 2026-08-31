extends GdUnitTestSuite

## 스크린샷 이상 감지 검증.
##
## 합성 이미지로 판정 함수를 시험한다. 실제 캡처는 렌더링이 필요해 헤드리스에서
## 돌지 않으므로, 여기서는 판정 로직만 못박는다.

const W := 64
const H := 48


func _filled(colour: Color) -> Image:
    var image := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
    image.fill(colour)
    return image


func _noisy() -> Image:
    var image := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
    for y in H:
        for x in W:
            image.set_pixel(x, y, Color(float(x) / W, float(y) / H, 0.5))
    return image


func test_black_screen_is_reported() -> void:
    var problems := ScreenshotCheck.problems(_filled(Color.BLACK))
    assert_array(problems).contains([ScreenshotCheck.PROBLEM_BLACK])


func test_dark_but_lit_screen_is_not_black() -> void:
    var problems := ScreenshotCheck.problems(_filled(Color(0.4, 0.5, 0.6)))
    assert_array(problems).not_contains([ScreenshotCheck.PROBLEM_BLACK])


func test_uniform_screen_is_reported() -> void:
    var problems := ScreenshotCheck.problems(_filled(Color(0.4, 0.5, 0.6)))
    assert_array(problems).contains([ScreenshotCheck.PROBLEM_UNIFORM])


func test_varied_screen_has_no_problems() -> void:
    assert_array(ScreenshotCheck.problems(_noisy())).is_empty()


func test_average_luminance_tracks_brightness() -> void:
    assert_float(ScreenshotCheck.average_luminance(_filled(Color.BLACK))).is_equal_approx(0.0, 0.01)
    assert_float(ScreenshotCheck.average_luminance(_filled(Color.WHITE))).is_equal_approx(1.0, 0.01)


func test_dominant_ratio_is_one_for_a_flat_image() -> void:
    assert_float(ScreenshotCheck.dominant_ratio(_filled(Color.RED))).is_equal_approx(1.0, 0.01)


func test_dominant_ratio_drops_when_colours_vary() -> void:
    assert_float(ScreenshotCheck.dominant_ratio(_noisy())).is_less(0.5)


func test_distinct_colours_counts_variety() -> void:
    assert_int(ScreenshotCheck.distinct_colours(_filled(Color.RED))).is_equal(1)
    assert_int(ScreenshotCheck.distinct_colours(_noisy())).is_greater(8)


func test_identical_regions_do_not_differ() -> void:
    var rect := Rect2i(8, 8, 16, 16)
    assert_float(ScreenshotCheck.region_difference(_noisy(), _noisy(), rect)).is_equal_approx(0.0, 0.001)


func test_changed_region_is_detected() -> void:
    var rect := Rect2i(8, 8, 16, 16)
    assert_float(ScreenshotCheck.region_difference(_filled(Color.RED), _filled(Color.BLUE), rect)).is_equal_approx(1.0, 0.001)


func test_region_outside_the_image_is_clamped_away() -> void:
    var rect := Rect2i(1000, 1000, 16, 16)
    assert_float(ScreenshotCheck.region_difference(_noisy(), _filled(Color.RED), rect)).is_equal_approx(0.0, 0.001)


func test_missing_subject_is_reported_when_nothing_changes() -> void:
    var rect := Rect2i(8, 8, 16, 16)
    assert_bool(ScreenshotCheck.subject_visible(_noisy(), _noisy(), rect)).is_false()


func test_present_subject_is_detected() -> void:
    var with_subject := _noisy()
    for y in range(8, 24):
        for x in range(8, 24):
            with_subject.set_pixel(x, y, Color.MAGENTA)
    assert_bool(ScreenshotCheck.subject_visible(with_subject, _noisy(), Rect2i(8, 8, 16, 16))).is_true()
