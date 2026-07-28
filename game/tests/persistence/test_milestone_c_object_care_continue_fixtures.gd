extends Node

const TEST_SAVE_PATH := "user://milestone_c_object_care_continue_fixture_test.save"
const FIXTURES := preload(
	"res://game/tests/persistence/fixtures/milestone_c_object_care_continue_fixtures.gd"
)

var m_failures := PackedStringArray()
var m_repository := StorySaveRepository.new(TEST_SAVE_PATH)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_ferry_continue()
	_test_church_continue()
	m_repository.clear()

	if m_failures.is_empty():
		print("PASS: Milestone C object-care Continue fixtures")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error(
			"Milestone C object-care Continue fixtures failed with %d issue(s)."
			% m_failures.size()
		)

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _test_ferry_continue() -> void:
	m_repository.clear()
	_assert_true(
		m_repository.save_payload(FIXTURES.build_ferry_payload()),
		"The fixed ferry-care fixture writes through the save repository"
	)
	var app_state := AppStateService.new(m_repository)
	_assert_true(
		app_state.resume_story()
			and app_state.get_projection().location == "Piano Ferry",
		"Continue resumes the fixed ferry-care fixture in Story mode"
	)

	app_state.notify_story_world_event("piano_ferry_music_case_shelved")
	app_state.notify_story_world_event("harbor_sea_melody_listened")
	app_state.notify_story_world_event("piano_ferry_music_case_shelved")
	app_state.notify_story_world_event("harbor_sea_melody_listened")
	var completed_flags: Dictionary = app_state.get_snapshot().story_flags
	_assert_true(
		bool(completed_flags.get("piano_ferry_music_case_shelved", false))
			and bool(completed_flags.get("harbor_sea_melody_listened", false)),
		"Ferry carry and listening publish their exact Story-mode facts idempotently"
	)
	var journal_text := JournalBuilder.build_story_routes_journal_text(
		app_state.get_projection()
	)
	_assert_true(
		journal_text.contains("music case now rests safely")
			and journal_text.contains("phrase of the sea melody"),
		"The journal records both ferry object-care outcomes"
	)
	_assert_true(
		app_state.request_autosave(),
		"Ferry object-care completion writes a deterministic follow-up save"
	)

	var resumed_state := AppStateService.new(m_repository)
	_assert_true(
		resumed_state.resume_story()
			and bool(resumed_state.get_snapshot().story_flags.get(
				"piano_ferry_music_case_shelved",
				false
			))
			and bool(resumed_state.get_snapshot().story_flags.get(
				"harbor_sea_melody_listened",
				false
			)),
		"Repeated Continue retains both ferry object-care facts without occupancy state"
	)

	resumed_state.start_free_walk()
	resumed_state.notify_story_world_event("piano_ferry_music_case_shelved")
	resumed_state.notify_story_world_event("harbor_sea_melody_listened")
	var free_walk_flags: Dictionary = resumed_state.get_snapshot().story_flags
	_assert_true(
		!bool(free_walk_flags.get("piano_ferry_music_case_shelved", false))
			and !bool(free_walk_flags.get("harbor_sea_melody_listened", false)),
		"Equivalent ferry actions remain story-state neutral in Free Walk"
	)

	app_state.free()
	resumed_state.free()


func _test_church_continue() -> void:
	m_repository.clear()
	_assert_true(
		m_repository.save_payload(FIXTURES.build_church_payload()),
		"The fixed church-care fixture writes through the save repository"
	)
	var app_state := AppStateService.new(m_repository)
	_assert_true(
		app_state.resume_story()
			and app_state.get_projection().location == "Trinity Church",
		"Continue resumes the fixed church-care fixture in Story mode"
	)

	app_state.notify_story_world_event("trinity_hymn_chest_aligned")
	app_state.notify_story_world_event("trinity_hymn_chest_aligned")
	_assert_true(
		bool(app_state.get_snapshot().story_flags.get(
			"trinity_hymn_chest_aligned",
			false
		)),
		"Push/pull publishes the exact Trinity Story-mode fact idempotently"
	)
	_assert_true(
		JournalBuilder.build_story_routes_journal_text(
			app_state.get_projection()
		).contains("hymn chest is aligned"),
		"The journal records the aligned Trinity hymn chest"
	)
	_assert_true(
		app_state.request_autosave(),
		"Trinity object-care completion writes a deterministic follow-up save"
	)

	var resumed_state := AppStateService.new(m_repository)
	_assert_true(
		resumed_state.resume_story()
			and bool(resumed_state.get_snapshot().story_flags.get(
				"trinity_hymn_chest_aligned",
				false
			)),
		"Repeated Continue retains the Trinity object-care fact"
	)
	resumed_state.start_free_walk()
	resumed_state.notify_story_world_event("trinity_hymn_chest_aligned")
	_assert_true(
		!bool(resumed_state.get_snapshot().story_flags.get(
			"trinity_hymn_chest_aligned",
			false
		)),
		"Equivalent Trinity alignment remains story-state neutral in Free Walk"
	)

	app_state.free()
	resumed_state.free()


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
