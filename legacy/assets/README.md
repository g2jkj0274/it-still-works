# 에셋

바깥에서 가져온 것만 여기 둔다. 코드로 만드는 모양은 `view/` 안에 있다.

## kenney_nature_kit

- 출처: [Kenney — Nature Kit 2.1](https://kenney.nl/assets/nature-kit)
- 라이선스: **CC0 1.0** (`kenney_nature_kit/LICENSE.txt`)
- 표기는 의무가 아니지만 남긴다. 만든 사람은 Kenney (www.kenney.nl).

원본 팩은 330종이고 형식도 여섯 가지다. 저장소에 다 넣을 이유가 없어
**땅에 깔 것 열두 개만 glTF(.glb)로 골라 담았다.** 80KB 남짓이다.

| 파일 | 쓰이는 곳 |
|---|---|
| `grass*.glb`, `plant_bush*.glb` | 풀숲 |
| `flower_*.glb` | 꽃 |
| `mushroom_*.glb` | 버섯 |
| `rock_small*.glb` | 잔돌 |

`view/ground_cover.gd` 가 지면 윗면에 흩뿌린다. **꾸밈일 뿐이다.** 시뮬레이션은
이것을 알지 못하고, 부술 수도 막지도 못한다.

### 더 가져오려면

```bash
curl -sSL https://kenney.nl/assets/nature-kit -o page.html
grep -oE 'https://kenney.nl/media/[^" ]+\.zip' page.html
```

내려받는 링크가 페이지 안에 그대로 적혀 있다. 필요한 `.glb` 만 꺼내
`assets/kenney_nature_kit/` 에 넣고 라이선스 파일을 함께 둔다.
