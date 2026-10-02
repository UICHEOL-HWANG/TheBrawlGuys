class_name OnboardingFlow
extends RefCounted
## First sign-in on a device (design.md DS-LAY-03 온보딩, PRD-UI-02): 환영 → 닉네임 → 캐릭터 →
## 시작 방식, pushed over the title. The nickname is saved (ProfileStore: device + account); the
## character fills a 1-vs-bot MatchSetup; 튜토리얼부터 plays the tutorial as that character and
## 바로 봇전 starts that match (default rule and arena) and marks the tutorial skipped. 뒤로 walks
## back one step. Leaving the tutorial or match returns to the title as usual.

const WELCOME := "welcome"
const NICKNAME := "nickname"
const CHOICE := "onboarding_choice"

var _router: ScreenRouter
var _profile: ProfileStore
var _tutorial: TutorialProgress
var _track: Callable
var _config: GameConfig
## (source: String, character: String) and (setup: MatchSetup): the App starts them.
var _start_tutorial: Callable
var _start_match: Callable
var _setup: MatchSetup
var _welcome: WelcomeScreen
var _nickname: NicknameScreen


func _init(router: ScreenRouter, profile: ProfileStore, tutorial: TutorialProgress, track: Callable,
		config: GameConfig, start_tutorial: Callable, start_match: Callable) -> void:
	_router = router
	_profile = profile
	_tutorial = tutorial
	_track = track
	_config = config
	_start_tutorial = start_tutorial
	_start_match = start_match


## seed: the bot match's seed (App.new_seed).
func start(seed: int) -> void:
	_setup = MatchSetup.vs_bots(MatchSetup.DEFAULT_PLAYERS, seed)
	_welcome = WelcomeScreen.new()
	_welcome.started.connect(_open_nickname)
	_router.push(WELCOME, _welcome)


func _open_nickname() -> void:
	_nickname = NicknameScreen.new()
	_nickname.submitted.connect(_on_nickname)
	_nickname.cancelled.connect(func() -> void:
		_router.pop()
		_welcome.reopen())
	_router.push(NICKNAME, _nickname)
	var local := _profile.nickname()
	if not local.is_empty():
		_nickname.set_prefill(local)
	else:
		var screen := _nickname
		_profile.fetch_remote(func(display_name: String) -> void:
			if is_instance_valid(screen):
				screen.set_prefill(Nickname.prefill(display_name)))


func _on_nickname(nick: String) -> void:
	var before := _profile.nickname()
	_track.call("nickname_set", {"length": nick.length(), "prefilled": _nickname.is_prefilled(),
		"changed": not before.is_empty() and before != nick})
	_profile.save(nick)
	var chars := SelectScreens.build(App.CHARACTER, _setup, _open_choice, _config, _track)
	chars.connect("cancelled", func() -> void:
		_router.pop()
		_nickname.reopen())
	_router.push(App.CHARACTER, chars)


func _open_choice() -> void:
	var choice := OnboardingChoiceScreen.new()
	choice.chosen.connect(_on_choice)
	choice.cancelled.connect(func() -> void: _router.pop())
	_router.push(CHOICE, choice)


func _on_choice(choice: String) -> void:
	_track.call("onboarding_choice", {"choice": choice})
	if choice == OnboardingChoiceScreen.CHOICE_TUTORIAL:
		_start_tutorial.call(TutorialFlow.SOURCE_FIRST_LOGIN, _setup.characters()[_setup.local_slot()])
	else:
		_tutorial.mark(TutorialProgress.SKIPPED)
		_start_match.call(_setup)
