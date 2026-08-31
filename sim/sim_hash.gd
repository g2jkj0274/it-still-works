class_name SimHash
extends RefCounted

## 월드 상태 해시의 토대.
##
## 상태를 먼저 하나의 정규 문자열로 직렬화한 뒤 SHA-256 을 취한다.
## 정규화 규칙은 두 가지다.
##   - 필드는 주어진 순서대로만 이어붙인다. 순서 비보장 자료구조를 그대로 순회하지 않는다
##   - 각 토큰에 길이 접두사를 붙여 서로 다른 상태가 같은 문자열로 뭉개지지 않게 한다
##
## 해시는 16진 문자열이다. 정수로 접으면 오버플로 처리가 플랫폼에 의존할 수 있다.

const _SEPARATOR := ":"


## 정규 문자열의 SHA-256 16진 다이제스트.
static func hash_text(text: String) -> String:
    return text.sha256_text()


## [param fields] 는 [[키, 값], ...] 형태의 순서 있는 배열이다.
static func hash_fields(fields: Array) -> String:
    return hash_text(canonical_text(fields))


## 바이트 배열의 SHA-256 16진 다이제스트. 복셀 격자처럼 큰 상태를 접을 때 쓴다.
static func hash_bytes(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish().hex_encode()


## 해시 이전 단계의 정규 문자열. 실패한 해시를 눈으로 비교할 때 쓴다.
static func canonical_text(fields: Array) -> String:
    var parts := PackedStringArray()
    for field: Array in fields:
        parts.append(_token(str(field[0])))
        parts.append(_token(str(field[1])))
    return "".join(parts)


## 길이 접두사를 붙여 단일 복호 가능한 토큰으로 만든다. "a" + "12" 와 "a1" + "2" 를 구분한다.
static func _token(text: String) -> String:
    return str(text.length()) + _SEPARATOR + text
