class_name NicknameEdit
extends RefCounted
## The title's 변경 / 닉네임 정하기 (design.md DS-LAY-03): the onboarding NicknameScreen pushed over
## the title, starting from the current nickname. 다음 saves it (ProfileStore: device + account,
## tracked nickname_set) and returns to the title; 뒤로 returns without a change.


static func open(router: ScreenRouter, profile: ProfileStore, track: Callable) -> void:
	if router.is_busy() or router.current_id() == OnboardingFlow.NICKNAME:
		return
	var screen := NicknameScreen.new()
	var before := profile.nickname()
	screen.submitted.connect(func(nick: String) -> void:
		track.call("nickname_set", {"length": nick.length(), "prefilled": screen.is_prefilled(),
			"changed": not before.is_empty() and before != nick})
		profile.save(nick)
		router.pop())
	screen.cancelled.connect(func() -> void: router.pop())
	router.push(OnboardingFlow.NICKNAME, screen)
	screen.set_prefill(before)
