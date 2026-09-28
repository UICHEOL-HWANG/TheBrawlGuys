# Google Stitch 프롬프트 — 숲속 난투 UI 시안

> 2026-09-28 · 원천: [`design.md`](./design.md) (DS-TOK-01~06, DS-LAY-01~03, DS-CMP-01~13)
> 용도: PHASES.md의 🖼 시각 비교 게이트 후보를 Stitch로 생성 (aside CLI). 결과는 참고 시안이며, Godot 구현은 `tokens.gd` + DS 컴포넌트로 다시 만든다.
> 사용법: 각 화면 프롬프트 앞에 **공통 컨텍스트**를 붙여서 보낸다. 화면마다 3안(variant)을 요청한다.

---

## 공통 컨텍스트 (모든 프롬프트 앞에 붙이기)

```
Design system for "Forest Brawl", a cozy 3D arena brawler game for mobile (landscape only, 1920x1080 reference) and desktop.
Mood: sunny midday forest diorama — soft, round, toy-like, warm light. Think a hand-held diorama with lime grass, teal tree canopies made of clustered spheres, a bright blue lake, cream egg-shaped rocks, and tiny scattered pink/blue/yellow flower dots.

Rules:
- Everything is round and soft: pill buttons, large corner radii (12 / 20 / 32 px), circular touch buttons. No sharp corners.
- NO black anywhere (#000 forbidden). The darkest color is deep teal #17525A, used for all text.
- NO outlines on shapes, no neon, no glassmorphism, no decorative gradients. Flat colors with soft drop shadows (0 8px 16px rgba(23,82,90,0.25)).
- Text over game scenes gets a 3px deep-teal (#17525A) stroke plus a soft shadow so it reads on any background.
- Information UI sits at the top of the screen; touch controls sit at the bottom (thumbs).
- Minimum touch target 48dp. Respect safe areas.

Palette (use exactly):
- Grass #A5D65A, sunlit grass #D6EE7C, mid grass #7CC04B, grass shadow #4F9A48
- Canopy teal #2E8C86, deep teal (text) #17525A, soft text #3F7470
- Water #3A9FE3, sky #C4E8F6, cream stone #F3EEE7, bark #6C5A66, dirt #8A6B55
- Accents: petal pink #F27DB6, petal blue #3E6FE3, petal yellow #F5D53D (highlight/focus), berry #7B5AD8, campfire orange #FF9A2E (primary CTA), glow #FFF3C4, danger #F0584A
- UI surface (cream white) #FFFDF6, dim surface #EAF2DC
- Players (always paired with a shape): P1 blue #3E7BF0 ● circle, P2 red #F25C5C ▲ triangle, P3 yellow #FFC93C ■ square, P4 purple #B46CF0 ◆ diamond

Typography:
- Display / numbers / titles: "Jua" (Google Font, rounded Korean). Sizes 96 (damage %), 64 (banners), 40 (titles).
- Body / buttons / captions: "Pretendard" SemiBold 28, Medium 22.
- UI copy is Korean.

Motion hint: buttons squish on press (scale 1.04 x 0.92), numbers pop with a soft elastic bounce.
```

---

## 1. 인게임 HUD + 터치 조작 (DS-LAY-01, DS-LAY-02, DS-CMP-01~05)

```
Screen: in-game HUD over a live 3D match, mobile landscape. Show the HUD layered on a top-down view of a round lime-grass arena with a thick dirt edge, teal sphere-cluster trees outside it, and a blue lake on the right.

Top edge: two damage counters (1v1) at the far left and far right — each a cream pill card with the player's shape icon, a big Jua damage number ("42%" for P1 in cream white, "118%" for P2 tinted campfire orange as damage rises), and 3 small stock dots in the player color. Pause button top-right, 48dp.

Bottom-left: floating virtual joystick (translucent cream circle base with a solid cream knob).
Bottom-right: 4 circular touch buttons in a thumb arc — the largest is "공격" (attack, resting thumb position), around it "점프" (jump), "가드" (guard), and "잡기" (grab). Buttons are cream at 70% opacity with a soft shadow and a deep-teal icon plus a small Korean label. The grab button shows its highlighted state: a petal-yellow ring with a soft pulse, meaning an item is nearby.

Above one character, a small world-space charge gauge filling from petal yellow to campfire orange.
Generate 3 variants of the button layout: A) arc around attack, B) diamond, C) 2x2 grid.
```

## 2. 타이틀 + 모드 선택 (DS-LAY-03, DS-CMP-06, DS-CMP-07)

```
Screen: title and mode select, mobile landscape. Background: the forest arena diorama seen from high above, softly desaturated so the UI pops.
Center-left: game logo "숲속 난투" in Jua, cream letters with a deep-teal stroke and a playful slight tilt.
Right side: a cream rounded panel (radius 32) with three large pill buttons stacked: "봇전" (primary, campfire orange), "로컬 2인", "온라인". A small settings gear button in the corner.
Tiny floating leaves and flower dots as decoration, only at the edges.
Generate 3 variants.
```

## 3. 캐릭터(스타일) 선택 (DS-CMP-08, DS-CMP-10, DS-TOK-06)

```
Screen: character (fighting style) select, mobile landscape, up to 4 players.
Three large select cards in a row: "권투형" (boxer — big round gloves icon), "무기형" (weapon — log bat icon), "원거리형" (ranged — slingshot icon). Each card: cream surface, radius 32, a chibi character silhouette on a soft grass-colored circle, the style name in Jua, and three short stat bars (속도, 사거리, 넉백) in teal.
States to show: one card focused (4px petal-yellow ring), one card selected by P1 (blue ring + P1 ● badge), one card selected by P2 (red ring + P2 ▲ badge).
Bottom: a row of player slots P1–P4 showing states: selecting, ready (check), empty ("참가 대기").
Primary CTA bottom-right: "준비 완료" pill in campfire orange.
Generate 3 variants.
```

## 4. 경기장 선택 (DS-CMP-08, DS-THM-02)

```
Screen: arena select, mobile landscape.
Four arena cards in a horizontal carousel, each with a diorama thumbnail and its own time-of-day tint:
- "호숫가 캠프장" (warm midday, lake + campfire) — gimmick icons: water ring-out, fire damage
- "통나무 다리" (bright day, narrow log bridge over water) — gimmick: breaking planks
- "버섯 숲" (golden late afternoon, glowing pink/berry mushrooms) — gimmick: bounce mushrooms
- "안개 낀 숲" (cool early morning, mist) — gimmick: periodic fog
Card: cream frame, radius 32, arena name in Jua, 1–2 small round gimmick icons with Korean captions.
Show focused and locked states. CTA "이 경기장으로" in campfire orange.
Generate 3 variants.
```

## 5. 결과 화면 (DS-CMP-09)

```
Screen: match result, mobile landscape, over the frozen arena.
Big Jua banner "승리!" for the winner with a gentle elastic pop and falling flower petals (pink/yellow/blue dots); the winner's chibi portrait inside a player-colored circle with its shape badge.
Below: a small stats row per player (KO 수, 받은 대미지, 링아웃) in cream pill cards.
Buttons: "다시 하기" (campfire orange primary) and "메뉴로" (cream secondary).
Also show the defeat variant: "패배…" in calmer teal tones, no petals.
Generate 3 variants.
```

## 6. 온라인 로비 — 방 코드 (DS-CMP-10, DS-CMP-11, DS-CMP-13)

```
Screen: online lobby, mobile landscape.
Left: a "방 만들기" card showing a generated room code in large Jua letters inside 6 separate rounded cells (e.g. "KX7P2M"), with a copy button.
Right: a "방 참가" card with a 6-cell uppercase room-code input, showing an error state ("방을 찾을 수 없어요" in danger red under the cells) and a loading state.
Bottom: 4 player slots with online states — waiting, ready, disconnected (dimmed with a small warning icon) — each with its player color and shape.
Top-right: a connection indicator pill (ping "42ms" with a dot colored mid grass / petal yellow / danger for good / fair / bad).
A toast at the top: "P3 님이 입장했어요".
Generate 3 variants.
```

---

## 결과물 처리 규칙

1. 시안은 `docs/references/stitch/<화면>-<A|B|C>.png`로 저장한다
2. 🖼 게이트에서 3안을 비교해 확정한 뒤 design.md의 해당 DS 항목을 갱신한다
3. Stitch가 쓴 색이 팔레트를 벗어나면 design.md 토큰으로 되돌린다 (시안이 토큰을 바꾸지 않는다)
4. Stitch의 HTML 코드는 쓰지 않는다. Godot에서 `tokens.gd`와 DS 컴포넌트로 다시 구현한다
