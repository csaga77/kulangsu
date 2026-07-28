class_name CharacterAnimationProfile3D
extends Resource

## Model-independent animation policy for HumanBody3D.
##
## All compatible player GLBs provide idle/walk/run. Air, landing, and recovery
## deliberately fall back to the neutral first idle sample. Ladder locomotion uses
## a generated, model-local cycle built against whichever compatible skeleton the
## selected GLB exposes.

enum Phase {
	IDLE,
	WALK,
	RUN,
	AIR,
	LAND,
	LADDER_MOUNT,
	LADDER_CLIMB,
	LADDER_DISMOUNT,
	CARRY_IDLE,
	CARRY_WALK,
	CARRY_PLACE,
	PUSH,
	PULL,
	SIT_ENTER,
	SIT_IDLE,
	SIT_EXIT,
	RECOVERY,
}

const GENERATED_LIBRARY := &"generated_fallbacks"
const FALLBACK_LADDER_CLIMB := &"fallback_ladder_climb"
const FALLBACK_LADDER_PATH := "generated_fallbacks/fallback_ladder_climb"
const FALLBACK_CARRY_HOLD := &"fallback_carry_hold"
const FALLBACK_CARRY_PATH := "generated_fallbacks/fallback_carry_hold"
const FALLBACK_OBJECT_BRACE := &"fallback_object_brace"
const FALLBACK_OBJECT_BRACE_PATH := "generated_fallbacks/fallback_object_brace"
const FALLBACK_SIT_ENTER := &"fallback_sit_enter"
const FALLBACK_SIT_ENTER_PATH := "generated_fallbacks/fallback_sit_enter"
const FALLBACK_SIT_IDLE := &"fallback_sit_idle"
const FALLBACK_SIT_IDLE_PATH := "generated_fallbacks/fallback_sit_idle"
const FALLBACK_SIT_EXIT := &"fallback_sit_exit"
const FALLBACK_SIT_EXIT_PATH := "generated_fallbacks/fallback_sit_exit"

@export var idle_animation := "idle"
@export var walk_animation := "walk"
@export var run_animation := "run"
@export_range(0.0, 1.0, 0.01) var air_blend_seconds := 0.12
@export_range(0.0, 1.0, 0.01) var land_blend_seconds := 0.10
@export_range(0.0, 1.0, 0.01) var ladder_align_seconds := 0.30
@export_range(0.0, 1.0, 0.01) var carry_release_seconds := 0.25
@export_range(0.0, 1.0, 0.01) var sit_entry_seconds := 0.35
@export_range(0.0, 1.0, 0.01) var sit_exit_seconds := 0.30
@export_range(0.0, 1.0, 0.01) var recovery_blend_seconds := 0.15


func get_animation_name(phase: Phase) -> String:
	match phase:
		Phase.WALK:
			return walk_animation
		Phase.RUN:
			return run_animation
		Phase.LADDER_MOUNT, Phase.LADDER_CLIMB, Phase.LADDER_DISMOUNT:
			return FALLBACK_LADDER_PATH
		Phase.CARRY_IDLE, Phase.CARRY_WALK, Phase.CARRY_PLACE:
			return FALLBACK_CARRY_PATH
		Phase.PUSH, Phase.PULL:
			return FALLBACK_OBJECT_BRACE_PATH
		Phase.SIT_ENTER:
			return FALLBACK_SIT_ENTER_PATH
		Phase.SIT_IDLE:
			return FALLBACK_SIT_IDLE_PATH
		Phase.SIT_EXIT:
			return FALLBACK_SIT_EXIT_PATH
		_:
			return idle_animation


func get_blend_seconds(phase: Phase) -> float:
	match phase:
		Phase.AIR:
			return air_blend_seconds
		Phase.LAND:
			return land_blend_seconds
		Phase.LADDER_MOUNT, Phase.LADDER_DISMOUNT:
			return ladder_align_seconds
		Phase.CARRY_PLACE:
			return carry_release_seconds
		Phase.SIT_ENTER:
			return sit_entry_seconds
		Phase.SIT_EXIT:
			return sit_exit_seconds
		Phase.RECOVERY:
			return recovery_blend_seconds
		_:
			return 0.15


func should_seek_neutral_sample(phase: Phase) -> bool:
	return phase in [Phase.AIR, Phase.LAND, Phase.RECOVERY]


func should_loop(phase: Phase) -> bool:
	return phase in [
		Phase.IDLE,
		Phase.WALK,
		Phase.RUN,
		Phase.LADDER_CLIMB,
		Phase.CARRY_IDLE,
		Phase.CARRY_WALK,
		Phase.PUSH,
		Phase.PULL,
		Phase.SIT_IDLE,
	]


func ensure_generated_fallbacks(
	animation_player: AnimationPlayer,
	skeleton: Skeleton3D
) -> void:
	if animation_player == null or skeleton == null:
		return
	var library: AnimationLibrary = null
	if animation_player.has_animation_library(GENERATED_LIBRARY):
		library = animation_player.get_animation_library(GENERATED_LIBRARY)
	else:
		library = AnimationLibrary.new()
		animation_player.add_animation_library(GENERATED_LIBRARY, library)
	if library.has_animation(FALLBACK_LADDER_CLIMB):
		pass
	else:
		library.add_animation(
			FALLBACK_LADDER_CLIMB,
			_build_ladder_cycle(animation_player, skeleton)
		)
	if !library.has_animation(FALLBACK_CARRY_HOLD):
		library.add_animation(
			FALLBACK_CARRY_HOLD,
			_build_upper_body_pose(animation_player, skeleton, 28.0, 18.0)
		)
	if !library.has_animation(FALLBACK_OBJECT_BRACE):
		library.add_animation(
			FALLBACK_OBJECT_BRACE,
			_build_upper_body_pose(animation_player, skeleton, 42.0, 26.0)
		)
	if !library.has_animation(FALLBACK_SIT_ENTER):
		library.add_animation(
			FALLBACK_SIT_ENTER,
			_build_sit_pose(animation_player, skeleton, sit_entry_seconds, false)
		)
	if !library.has_animation(FALLBACK_SIT_IDLE):
		library.add_animation(
			FALLBACK_SIT_IDLE,
			_build_sit_pose(animation_player, skeleton, 1.0, true)
		)
	if !library.has_animation(FALLBACK_SIT_EXIT):
		library.add_animation(
			FALLBACK_SIT_EXIT,
			_build_sit_exit(animation_player, skeleton)
		)


func _build_ladder_cycle(
	animation_player: AnimationPlayer,
	skeleton: Skeleton3D
) -> Animation:
	var animation := Animation.new()
	animation.length = 1.0
	animation.loop_mode = Animation.LOOP_LINEAR
	var animation_root := animation_player.get_node_or_null(animation_player.root_node)
	if animation_root == null:
		animation_root = animation_player
	var skeleton_path := animation_root.get_path_to(skeleton)
	var animated_bones := _find_ladder_bones(skeleton)
	for bone_data in animated_bones:
		var bone_name := StringName(bone_data.get("name", &""))
		var phase_sign := float(bone_data.get("phase", 1.0))
		if bone_name.is_empty():
			continue
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("%s:%s" % [skeleton_path, bone_name]))
		animation.rotation_track_insert_key(
			track,
			0.0,
			Quaternion(Vector3.FORWARD, deg_to_rad(12.0) * phase_sign)
		)
		animation.rotation_track_insert_key(
			track,
			0.5,
			Quaternion(Vector3.FORWARD, deg_to_rad(-12.0) * phase_sign)
		)
		animation.rotation_track_insert_key(
			track,
			1.0,
			Quaternion(Vector3.FORWARD, deg_to_rad(12.0) * phase_sign)
		)
	return animation


func _find_ladder_bones(skeleton: Skeleton3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bone_index in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(bone_index)
		var lowered := String(bone_name).to_lower()
		var is_twist := "twist" in lowered
		var is_arm := !is_twist and ("upperarm" in lowered or "upper_arm" in lowered)
		var is_leg := !is_twist and (
			"thigh" in lowered or "upperleg" in lowered or "upper_leg" in lowered
		)
		if !is_arm and !is_leg:
			continue
		var is_left := lowered.ends_with("_l") or "left" in lowered
		var phase_sign := 1.0 if is_left else -1.0
		if is_leg:
			phase_sign *= -1.0
		result.append({"name": bone_name, "phase": phase_sign})
	return result


func _build_upper_body_pose(
	animation_player: AnimationPlayer,
	skeleton: Skeleton3D,
	arm_degrees: float,
	forearm_degrees: float
) -> Animation:
	var animation := Animation.new()
	animation.length = 1.0
	animation.loop_mode = Animation.LOOP_LINEAR
	var skeleton_path := _resolve_skeleton_path(animation_player, skeleton)
	for bone_index in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(bone_index)
		var lowered := String(bone_name).to_lower()
		var angle := 0.0
		if "upperarm" in lowered or "upper_arm" in lowered:
			angle = arm_degrees
		elif "forearm" in lowered or "lowerarm" in lowered:
			angle = forearm_degrees
		else:
			continue
		var side_sign := 1.0 if lowered.ends_with("_l") or "left" in lowered else -1.0
		_add_rotation_pose_track(
			animation,
			skeleton_path,
			bone_name,
			Quaternion(Vector3.FORWARD, deg_to_rad(angle) * side_sign),
			1.0,
			true
		)
	return animation


func _build_sit_pose(
	animation_player: AnimationPlayer,
	skeleton: Skeleton3D,
	duration: float,
	looped: bool
) -> Animation:
	var animation := Animation.new()
	animation.length = maxf(duration, 0.01)
	animation.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
	var skeleton_path := _resolve_skeleton_path(animation_player, skeleton)
	for bone_index in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(bone_index)
		var lowered := String(bone_name).to_lower()
		var degrees := 0.0
		if "thigh" in lowered or "upperleg" in lowered or "upper_leg" in lowered:
			degrees = 80.0
		elif "shin" in lowered or "calf" in lowered or "lowerleg" in lowered:
			degrees = -90.0
		else:
			continue
		_add_rotation_pose_track(
			animation,
			skeleton_path,
			bone_name,
			Quaternion(Vector3.RIGHT, deg_to_rad(degrees)),
			animation.length,
			looped
		)
	return animation


func _build_sit_exit(
	animation_player: AnimationPlayer,
	skeleton: Skeleton3D
) -> Animation:
	var animation := _build_sit_pose(
		animation_player,
		skeleton,
		sit_exit_seconds,
		false
	)
	for track_index in range(animation.get_track_count()):
		if animation.track_get_key_count(track_index) < 2:
			continue
		var first_value: Variant = animation.track_get_key_value(track_index, 0)
		var last_value: Variant = animation.track_get_key_value(track_index, 1)
		animation.track_set_key_value(track_index, 0, last_value)
		animation.track_set_key_value(track_index, 1, first_value)
	return animation


func _resolve_skeleton_path(
	animation_player: AnimationPlayer,
	skeleton: Skeleton3D
) -> NodePath:
	var animation_root := animation_player.get_node_or_null(animation_player.root_node)
	if animation_root == null:
		animation_root = animation_player
	return animation_root.get_path_to(skeleton)


func _add_rotation_pose_track(
	animation: Animation,
	skeleton_path: NodePath,
	bone_name: StringName,
	pose: Quaternion,
	duration: float,
	start_in_pose := false
) -> void:
	var track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track, NodePath("%s:%s" % [skeleton_path, bone_name]))
	animation.rotation_track_insert_key(
		track,
		0.0,
		pose if start_in_pose else Quaternion.IDENTITY
	)
	animation.rotation_track_insert_key(track, maxf(duration, 0.01), pose)
