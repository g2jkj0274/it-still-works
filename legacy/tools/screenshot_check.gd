class_name ScreenshotCheck
extends RefCounted

## 스크린샷에서 명백한 이상을 찾는다.
##
## 그림이 예쁜지는 판정하지 않는다. 판정하는 것은 "아무것도 안 나왔다" 뿐이다.
## 검은 화면, 단색 화면, 있어야 할 것이 안 보이는 경우.

const PROBLEM_BLACK := "검은 화면"
const PROBLEM_UNIFORM := "단색 화면"
const PROBLEM_BLOWN := "날아간 화면"

## 이보다 어두우면 아무것도 그려지지 않은 것으로 본다.
const MIN_LUMINANCE := 0.05

## 한 색이 이 비율을 넘으면 단색 화면으로 본다.
const MAX_DOMINANT_RATIO := 0.95

## 이보다 색 종류가 적으면 단색 화면으로 본다.
const MIN_DISTINCT_COLOURS := 8

## 세 갈래 모두 꽉 찬 픽셀. 이보다 넓게 퍼지면 볕이 색을 씻어낸 것으로 본다.
##
## 검은 화면의 반대쪽이다. 너무 어두우면 아무것도 안 보이고, 너무 밝아도
## 아무것도 안 보인다. 흰 것이 흰 것으로 보이는 만큼은 남겨 둔다.
const MAX_BLOWN_RATIO := 0.20

## 이 위로는 꽉 찬 것으로 친다. 8비트 한 칸 차이는 세지 않는다.
const BLOWN_LEVEL := 0.995

## 표본 간격. 전 픽셀을 보면 느리고, 이상 감지에는 표본으로 충분하다.
const SAMPLE_STEP := 4

## 두 픽셀이 이만큼 넘게 벌어지면 다른 것으로 본다.
const PIXEL_EPSILON := 0.02

## 대상 영역이 이 비율 넘게 달라지면 대상이 그려진 것으로 본다.
const MIN_SUBJECT_RATIO := 0.02


static func problems(image: Image) -> PackedStringArray:
    var found := PackedStringArray()
    if average_luminance(image) < MIN_LUMINANCE:
        found.append(PROBLEM_BLACK)
    if dominant_ratio(image) > MAX_DOMINANT_RATIO or distinct_colours(image) < MIN_DISTINCT_COLOURS:
        found.append(PROBLEM_UNIFORM)
    if blown_ratio(image) > MAX_BLOWN_RATIO:
        found.append(PROBLEM_BLOWN)
    return found


## 세 갈래가 모두 꽉 차 버린 픽셀의 비율.
##
## 여기까지 간 픽셀은 원래 무슨 색이었는지 알 수 없다. 팔레트가 칸마다 주는
## 명도 변주도 함께 사라진다.
static func blown_ratio(image: Image) -> float:
    var blown := 0
    var samples := 0
    for y in range(0, image.get_height(), SAMPLE_STEP):
        for x in range(0, image.get_width(), SAMPLE_STEP):
            samples += 1
            var pixel := image.get_pixel(x, y)
            if pixel.r >= BLOWN_LEVEL and pixel.g >= BLOWN_LEVEL and pixel.b >= BLOWN_LEVEL:
                blown += 1
    if samples == 0:
        return 0.0
    return float(blown) / samples


static func average_luminance(image: Image) -> float:
    var total := 0.0
    var samples := 0
    for y in range(0, image.get_height(), SAMPLE_STEP):
        for x in range(0, image.get_width(), SAMPLE_STEP):
            total += image.get_pixel(x, y).get_luminance()
            samples += 1
    if samples == 0:
        return 0.0
    return total / samples


static func distinct_colours(image: Image) -> int:
    return _histogram(image).size()


static func dominant_ratio(image: Image) -> float:
    var histogram := _histogram(image)
    var samples := 0
    var top := 0
    for key in histogram:
        var count: int = histogram[key]
        samples += count
        top = maxi(top, count)
    if samples == 0:
        return 0.0
    return float(top) / samples


## [param rect] 안에서 두 이미지가 다른 픽셀의 비율.
## 이미지 밖으로 나간 부분은 세지 않는다.
static func region_difference(before: Image, after: Image, rect: Rect2i) -> float:
    var bounds := rect.intersection(Rect2i(Vector2i.ZERO, before.get_size()))
    bounds = bounds.intersection(Rect2i(Vector2i.ZERO, after.get_size()))
    if bounds.size.x <= 0 or bounds.size.y <= 0:
        return 0.0

    var differing := 0
    var samples := 0
    for y in range(bounds.position.y, bounds.end.y):
        for x in range(bounds.position.x, bounds.end.x):
            samples += 1
            if _differs(before.get_pixel(x, y), after.get_pixel(x, y)):
                differing += 1
    if samples == 0:
        return 0.0
    return float(differing) / samples


## 대상을 켠 화면과 끈 화면을 견줘 실제로 그려졌는지 본다.
##
## 색으로 찾는 것보다 튼튼하다. 팔레트가 바뀌어도 이 판정은 그대로 쓸 수 있다.
static func subject_visible(with_subject: Image, without_subject: Image, rect: Rect2i) -> bool:
    return region_difference(with_subject, without_subject, rect) >= MIN_SUBJECT_RATIO


static func _histogram(image: Image) -> Dictionary:
    var histogram: Dictionary = {}
    for y in range(0, image.get_height(), SAMPLE_STEP):
        for x in range(0, image.get_width(), SAMPLE_STEP):
            var key := image.get_pixel(x, y).to_rgba32()
            histogram[key] = int(histogram.get(key, 0)) + 1
    return histogram


static func _differs(left: Color, right: Color) -> bool:
    return (
        absf(left.r - right.r) > PIXEL_EPSILON
        or absf(left.g - right.g) > PIXEL_EPSILON
        or absf(left.b - right.b) > PIXEL_EPSILON
    )
