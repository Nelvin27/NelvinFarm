extends RefCounted

enum Skill { FARMING, FISHING, COOKING }

const NAMES := ["Farming", "Fishing", "Cooking"]
const THRESHOLDS := [[8, 24, 48], [3, 8, 16], [3, 8, 16]]

var practice := Vector3i.ZERO


func level(skill: Skill) -> int:
	var rank := 1
	for threshold: int in THRESHOLDS[skill]:
		if practice[skill] >= threshold:
			rank += 1
	return rank


func train(skill: Skill) -> bool:
	var before := level(skill)
	practice[skill] = mini(practice[skill] + 1, THRESHOLDS[skill][-1])
	return level(skill) > before


func progress_text(skill: Skill) -> String:
	var rank := level(skill)
	if rank > THRESHOLDS[skill].size():
		return "%s Lv. %d (mastered)" % [NAMES[skill], rank]
	return "%s Lv. %d (%d/%d)" % [NAMES[skill], rank, practice[skill], THRESHOLDS[skill][rank - 1]]


func restore(saved: Variant) -> void:
	if saved is Vector3i:
		for skill in range(THRESHOLDS.size()):
			practice[skill] = clampi(saved[skill], 0, THRESHOLDS[skill][-1])
