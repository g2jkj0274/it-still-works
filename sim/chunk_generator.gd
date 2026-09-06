class_name ChunkGenerator
extends RefCounted

## 시드 기반 청크 절차 생성 (M1-3, 헌법 P7).
##
## 셀 값은 오직 (월드 시드, 월드 좌표, 층, 규칙 표) 의 순수 함수다.
##
## 세계 RNG 를 쓰지 않는 이유: 난수열은 뽑은 순서에 묶인다. 세계 RNG 로 청크를 채우면 플레이어가
## 어느 청크를 먼저 밟았는지가 지형을 바꾸고, "같은 시드 = 같은 세계"(P3) 가 방문 순서에 종속된다.
## 언로드 뒤 다시 만들 때(P7) 도 같은 지형이 나와야 한다. 그래서 좌표를 해시한다 — 어느 청크를
## 언제 몇 번 만들어도 같은 바이트열이다.
##
## 규칙 두 층:
##   - 굵은 격자(ZONE_SHIFT, 한 변 8칸) 좌표의 해시 → 지대 블록. 격자 안의 셀이 같은 값을
##     공유해 덩어리가 생긴다. 격자 좌표는 산술 시프트(`>>`) 로 구한다 — 음수에서도 floor 다.
##   - 셀 좌표의 해시 → 흩뿌림. 표의 항목을 순서대로 누적 문턱과 비교한다.
## 셀은 자기 해시와 자기 격자 해시만 본다. 이웃 셀에 값을 찍지 않는다 — 찍으면 청크 경계에서
## 이웃 청크가 이미 생성됐는지에 따라 결과가 갈린다.
##
## 이 파일에는 파일 IO·표 파싱·난수 생성기·부동소수가 없다. 64비트 정수 해시와 배치만 한다.

## 굵은 격자 한 변 = 1 << ZONE_SHIFT = 8 칸.
const ZONE_SHIFT := 3

## 역할별 salt. 같은 좌표라도 역할이 다르면 다른 해시를 얻는다. 서로 다른 큰 홀수.
const SALT_UNDER_ZONE := 0x2545F4914F6CDD1D
const SALT_GROUND_ZONE := 0x5851F42D4C957F2D
const SALT_SCATTER := 0x14057B7EF767814F

## splitmix64 계열 상수. GDScript 정수 리터럴은 부호 있는 64비트를 넘을 수 없어 2의 보수로 적었다.
##   _K_GOLDEN = 0x9E3779B97F4A7C15, _K_MUL_A = 0xBF58476D1CE4E5B9, _K_MUL_B = 0x94D049BB133111EB
const _K_GOLDEN := -0x61C8864680B583EB
const _K_MUL_A := -0x40A7B892E31B1A47
const _K_MUL_B := -0x6B2FB644ECCEEE15

## 비음수화 마스크 (INT64_MAX).
const _NON_NEGATIVE_MASK := 0x7FFFFFFFFFFFFFFF

## 밀도 판정 마스크. `h & 255` 는 항상 0..255 다 (`% 256` 은 음수에서 음수를 낸다).
const _ROLL_MASK := 255

var _world_seed: int
var _registry: BlockRegistry
var _terrain: TerrainTable


func _init(world_seed: int, registry: BlockRegistry, terrain: TerrainTable) -> void:
    _world_seed = world_seed
    _registry = registry
    _terrain = terrain


## (시드, 좌표, salt) → 64비트 정수 해시. splitmix64 피니셜라이저.
## 0 이 아닌 상수를 먼저 더하므로 시드 0·좌표 (0,0)·salt 0 에서 0 으로 퇴화하지 않는다.
## GDScript int 는 64비트 랩어라운드다 — 곱셈 오버플로는 정의된 동작이고 여기서는 의도한 섞기다.
## `>>` 는 산술 시프트지만 xor-shift 는 그래도 전단사라 섞기 품질에 문제가 없다.
static func cell_hash(world_seed: int, wx: int, wy: int, salt: int) -> int:
    var h := world_seed + _K_GOLDEN
    h += wx * _K_MUL_A
    h += wy * _K_MUL_B
    h += salt
    h ^= h >> 30
    h *= _K_MUL_A
    h ^= h >> 27
    h *= _K_MUL_B
    h ^= h >> 31
    return h


## 해시를 0 이상 [param n] 미만의 인덱스로 접는다. 부호 비트를 지우고 나머지를 취한다.
## [param n] 이 0 이하면 0.
static func pick(h: int, n: int) -> int:
    if n <= 0:
        return 0
    return (h & _NON_NEGATIVE_MASK) % n


## 월드 좌표 [param wx], [param wy] 의 지하층 블록 id. 굵은 격자 해시만 본다.
func under_id_at(wx: int, wy: int) -> int:
    var h := cell_hash(_world_seed, wx >> ZONE_SHIFT, wy >> ZONE_SHIFT, SALT_UNDER_ZONE)
    return _terrain.under_zone(pick(h, _terrain.under_zone_count()))


## 월드 좌표 [param wx], [param wy] 의 지상층 블록 id.
## 격자 해시로 지대 바탕을 고르고, 셀 해시의 하위 8비트를 흩뿌림 항목의 누적 문턱과 순서대로 비교한다.
## 아무 항목에도 걸리지 않으면 지대 바탕이다.
func ground_id_at(wx: int, wy: int) -> int:
    var zone_hash := cell_hash(_world_seed, wx >> ZONE_SHIFT, wy >> ZONE_SHIFT, SALT_GROUND_ZONE)
    var zone_id := _terrain.ground_zone(pick(zone_hash, _terrain.ground_zone_count()))
    var roll := cell_hash(_world_seed, wx, wy, SALT_SCATTER) & _ROLL_MASK
    var acc := 0
    for i in _terrain.scatter_count():
        acc += _terrain.scatter_per_256(i)
        if roll < acc:
            return _terrain.scatter_id(i)
    return zone_id


## 청크 좌표 [param cx], [param cy] 의 청크를 만든다.
## UNDER 는 지대, GROUND 는 지대 + 흩뿌림, UPPER 는 전부 air. 내구도는 레지스트리의 최대값.
## 생성 직후는 clean — 아직 저장할 변경이 없다.
func generate(cx: int, cy: int) -> Chunk:
    var chunk := Chunk.empty()
    var base_x := cx * Chunk.CHUNK_SIZE
    var base_y := cy * Chunk.CHUNK_SIZE
    for y in Chunk.CHUNK_SIZE:
        var wy := base_y + y
        for x in Chunk.CHUNK_SIZE:
            var wx := base_x + x
            var under_id := under_id_at(wx, wy)
            chunk.set_id(x, y, Chunk.LAYER_UNDER, under_id, _registry.max_durability(under_id))
            var ground_id := ground_id_at(wx, wy)
            chunk.set_id(x, y, Chunk.LAYER_GROUND, ground_id, _registry.max_durability(ground_id))
    chunk.clear_dirty()
    return chunk
