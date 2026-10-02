# Onboarding — context
Last Updated: 2026-10-02

- app.gd 191 lines: routing goes in OnboardingFlow; _on_signed_in (≈110) calls it instead of _start_tutorial.
- ScreenRouter push/pop/pop_to/replace, screen_viewed tracked per push.
- CharacterSelectScreen (200 lines, reuse as is): SelectScreens.build(App.CHARACTER, setup, next, config, track); fills setup.characters().
- TutorialProgress [onboarding] tutorial completed|skipped (device-local). Bot choice → mark skipped.
- TutorialMatch.setup can be injected: TutorialDirector.match_setup(character). All 4 characters have specials.
- Supabase profiles(id, display_name ≤80); RLS: own row select/update; grant update(display_name).
- SupabaseClient 197 lines → ProfileApi separate (uses fresh_token, url, anon_key, transport, session).
- Nickname is PII: analytics get length/flags only.
- User is strict about spacing: DS.S* only, capture-verify (memory ui-spacing-rigor).
