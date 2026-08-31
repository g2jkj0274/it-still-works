class_name SkyView
extends Node3D

## 하늘과 햇빛. 낮과 밤에 따라 밝기와 빛깔이 옮겨간다.
##
## 틱을 읽어 색을 정할 뿐 시뮬레이션을 건드리지 않는다.
## 밤에는 어두워지고 시야가 좁아진다.

const DAY_SKY := Palette.SKY_DAY
const NIGHT_SKY := Palette.SKY_NIGHT

const DAY_AMBIENT := Palette.AMBIENT_DAY
const NIGHT_AMBIENT := Palette.AMBIENT_NIGHT

const DAY_LIGHT := 1.1
const NIGHT_LIGHT := 0.20

## 해가 지고 뜨는 데 걸리는 틱. 갑자기 캄캄해지지 않는다.
const TWILIGHT_TICKS := 15 * Simulation.TICK_RATE

var _environment: Environment
var _light: DirectionalLight3D
var _darkness: float = 0.0


func _ready() -> void:
    _environment = Environment.new()
    _environment.background_mode = Environment.BG_COLOR
    _environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    _environment.ambient_light_energy = 0.7

    var holder := WorldEnvironment.new()
    holder.name = "Environment"
    holder.environment = _environment
    add_child(holder)

    _light = DirectionalLight3D.new()
    _light.name = "Sun"
    _light.rotation_degrees = Vector3(-55.0, -40.0, 0.0)
    # 그림자는 부드럽게. 또렷한 그림자는 톤을 무겁게 만든다.
    _light.shadow_enabled = true
    _light.light_angular_distance = 2.0
    add_child(_light)

    apply(0)


## 0 은 한낮, 1 은 한밤중.
func darkness() -> float:
    return _darkness


func apply(tick: int) -> void:
    _darkness = darkness_at(tick)
    _environment.background_color = DAY_SKY.lerp(NIGHT_SKY, _darkness)
    _environment.ambient_light_color = DAY_AMBIENT.lerp(NIGHT_AMBIENT, _darkness)
    _light.light_energy = lerpf(DAY_LIGHT, NIGHT_LIGHT, _darkness)


## 그 틱의 어둠 정도. 해 질 녘과 새벽에 부드럽게 오간다.
static func darkness_at(tick: int) -> float:
    var phase := DayCycle.phase_tick(tick)
    if phase < DayCycle.DAY_TICKS - TWILIGHT_TICKS:
        return 0.0
    if phase < DayCycle.DAY_TICKS:
        return float(phase - (DayCycle.DAY_TICKS - TWILIGHT_TICKS)) / TWILIGHT_TICKS
    if phase < DayCycle.CYCLE_TICKS - TWILIGHT_TICKS:
        return 1.0
    return float(DayCycle.CYCLE_TICKS - phase) / TWILIGHT_TICKS
