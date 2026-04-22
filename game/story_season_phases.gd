class_name StorySeasonPhases
extends RefCounted

const SUMMER_1 := "summer_1"
const AUTUMN_STUDY := "autumn_study"
const WINTER := "winter"
const SPRING_FESTIVAL := "spring_festival"
const SUMMER_2 := "summer_2"
const ENDGAME := "endgame"

const DEFAULT_PHASE := SUMMER_1
const DEFAULT_RESUME_PHASE := SPRING_FESTIVAL
const AUTHORABLE_PHASE_IDS := [
	SUMMER_1,
	AUTUMN_STUDY,
	WINTER,
	SPRING_FESTIVAL,
	SUMMER_2,
]
const RUNTIME_PHASE_IDS := [
	SUMMER_1,
	AUTUMN_STUDY,
	WINTER,
	SPRING_FESTIVAL,
	SUMMER_2,
	ENDGAME,
]
const AUTHORABLE_PHASE_HINT := (
	SUMMER_1
	+ ","
	+ AUTUMN_STUDY
	+ ","
	+ WINTER
	+ ","
	+ SPRING_FESTIVAL
	+ ","
	+ SUMMER_2
)
const DISPLAY_NAMES := {
	SUMMER_1: "Summer",
	AUTUMN_STUDY: "Autumn / Study",
	WINTER: "Winter",
	SPRING_FESTIVAL: "Spring Festival / Spring",
	SUMMER_2: "Second Summer",
	ENDGAME: "Final Act",
}


static func authorable_phase_ids() -> PackedStringArray:
	return PackedStringArray(AUTHORABLE_PHASE_IDS)


static func runtime_phase_ids() -> PackedStringArray:
	return PackedStringArray(RUNTIME_PHASE_IDS)


static func is_authorable_phase(phase_id: String) -> bool:
	return AUTHORABLE_PHASE_IDS.has(phase_id)


static func display_name(phase_id: String) -> String:
	return String(DISPLAY_NAMES.get(phase_id, "Story"))
