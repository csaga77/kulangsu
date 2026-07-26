extends Node

const TEST_SAVE_PATH := "user://bagua_ascent_continue_fixture_test.save"
const FIXTURE := preload(
	"res://game/tests/persistence/fixtures/bagua_ascent_continue_fixture.gd"
)

var m_failures := PackedStringArray()
var m_repository := StorySaveRepository.new(TEST_SAVE_PATH)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	m_repository.clear()
	_assert_true(
		m_repository.save_payload(FIXTURE.build_payload()),
		"The fixed Bagua pre-ascent fixture writes through the save repository"
	)
	var app_state := AppStateService.new(m_repository)
	var metadata: Dictionary = app_state.get_save_metadata()
	_assert_true(
		bool(metadata.get("exists", false))
			and String(metadata.get("resume_location", "")) == "Bagua Tower",
		"The title flow exposes Bagua Tower as the Continue destination"
	)
	_assert_true(
		app_state.resume_story()
			and app_state.get_projection().mode_id == AppStateSnapshot.MODE_STORY,
		"The fixed pre-ascent fixture resumes in Story mode"
	)

	var pre_ascent_snapshot: AppStateSnapshot = app_state.get_snapshot()
	var score_before := int(
		app_state.get_projection().get_route_progress(
			"preservation_inheritance"
		).get("completion_score", 0)
	)
	_assert_true(
		bool(pre_ascent_snapshot.story_flags.get(
			"preservation_tower_perspective",
			false
		))
			and !bool(pre_ascent_snapshot.story_flags.get(
				"bagua_stewardship_jump_crossed",
				false
			))
			and !bool(pre_ascent_snapshot.story_flags.get(
				"bagua_stewardship_ladder_ascended",
				false
			)),
		"The fixture starts after perspective and before either physical completion"
	)
	_assert_true(
		app_state.get_projection().get_landmark_state("bagua_tower") == "available",
		"The fixture leaves the ordinary Bagua route available"
	)

	app_state.notify_story_world_event("bagua_stewardship_jump_crossed")
	app_state.notify_story_world_event("bagua_stewardship_ladder_ascended")
	var score_after := int(
		app_state.get_projection().get_route_progress(
			"preservation_inheritance"
		).get("completion_score", 0)
	)
	_assert_true(
		score_after == score_before
			and bool(app_state.get_snapshot().story_flags.get(
				"preservation_tower_perspective",
				false
			)),
		"The optional ascent neither renames, resolves, nor rescores tower perspective"
	)
	_assert_true(
		JournalBuilder.build_story_routes_journal_text(
			app_state.get_projection()
		).contains("joined stewardship promise"),
		"Continue unlocks the conditional preservation note after the ascent"
	)
	_assert_true(
		String(app_state.activate_story_subject(
			"inspectable:bagua_railings",
			"inspect"
		).get("text", "")).to_lower().contains("patient promise"),
		"Continue unlocks the Bagua view-deck response after the ascent"
	)

	_assert_true(
		app_state.request_autosave(),
		"The completed fixture writes a follow-up autosave"
	)
	var resumed_state := AppStateService.new(m_repository)
	_assert_true(
		resumed_state.resume_story(),
		"The completed Bagua ascent can Continue again"
	)
	var resumed_flags: Dictionary = resumed_state.get_snapshot().story_flags
	_assert_true(
		bool(resumed_flags.get("bagua_stewardship_jump_crossed", false))
			and bool(resumed_flags.get(
				"bagua_stewardship_ladder_ascended",
				false
			)),
		"Repeated Continue retains both authored ascent facts"
	)

	resumed_state.start_free_walk()
	resumed_state.notify_story_world_event("bagua_stewardship_jump_crossed")
	resumed_state.notify_story_world_event("bagua_stewardship_ladder_ascended")
	var free_walk_flags: Dictionary = resumed_state.get_snapshot().story_flags
	_assert_true(
		!bool(free_walk_flags.get("bagua_stewardship_jump_crossed", false))
			and !bool(free_walk_flags.get(
				"bagua_stewardship_ladder_ascended",
				false
			)),
		"Equivalent Free Walk completion remains story-state neutral"
	)

	app_state.free()
	resumed_state.free()
	m_repository.clear()

	if m_failures.is_empty():
		print("PASS: Bagua ascent Continue fixture")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error(
			"Bagua ascent Continue fixture failed with %d issue(s)."
			% m_failures.size()
		)

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
