# Onboarding before the tutorial — plan

Approved 2026-10-02 (mockup "목업대로", nickname shown on match HUD + title).

First sign-in on a device (TutorialProgress pending) no longer drops straight into the tutorial:
Welcome → Nickname → Character (existing CharacterSelectScreen) → Choice (튜토리얼부터 / 바로 봇전).

1. Nickname rules (2–12 chars after trim, no control chars) + ProfileStore: local cache
   SettingsStore [profile] nickname, remote Supabase profiles.display_name (GET prefill, PATCH save,
   fire-and-forget) via a small ProfileApi on SupabaseClient. TDD.
2. Screens (src/app/screens/onboarding/): WelcomeScreen, NicknameScreen, OnboardingChoiceScreen on a
   shared OnboardingLayout (title + centered UiPanel + 뒤로 bottom-left + key hint bottom-right, same
   as ArenaSelectLayout). DS spacing tokens only.
3. OnboardingFlow (src/app/onboarding_flow.gd): router steps + back; App._on_signed_in calls it.
   Tutorial gets the chosen character (TutorialLauncher.scene character arg); 바로 봇전 starts a bot
   match with the pick (default rule + arena) and marks the tutorial skipped.
4. Nickname on HUD (local player card) + title greeting.
5. Analytics schema 12: screen enum + nickname_set {length, prefilled, changed} + onboarding_choice
   {choice}; tracking-plan + EventCatalog + tests. design.md DS-LAY-03.
6. Captures desktop + phone (spacing check), code review, commit.
