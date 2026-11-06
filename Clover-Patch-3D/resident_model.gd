extends RefCounted

const Meshes := preload("res://farm_mesh.gd")

# Position, dimensions, and color in the farmer's front-facing voxel proportions.
const ACCESSORIES := {
	"ledger": [[0.25,0.43,0.245,0.16,0.22,0.075,"accent"], [0.25,0.43,0.287,0.12,0.18,0.018,"#706080"]],
	"bread": [[0.27,0.38,0.23,0.21,0.12,0.21,"#c88a48"], [0.27,0.45,0.23,0.15,0.045,0.16,"#f2c77c"]],
	"seed_pouch": [[0.26,0.32,0.17,0.18,0.19,0.15,"#987653"], [0.26,0.415,0.18,0.1,0.04,0.1,"accent"]],
	"lamp": [
		[0.28,0.33,0.2,0.16,0.19,0.15,"#e0b459"],
		[0.28,0.225,0.2,0.19,0.05,0.17,"#6c5041"],
		[0.28,0.45,0.2,0.18,0.05,0.17,"#6c5041"],
		[0.28,0.49,0.2,0.06,0.05,0.05,"#6c5041"],
	],
	"satchel": [[0.24,0.32,0.22,0.19,0.19,0.13,"#7e5648"], [0.24,0.38,0.29,0.19,0.07,0.035,"accent"]],
	"mallet": [[0.28,0.37,0.22,0.055,0.25,0.055,"#865945"], [0.28,0.5,0.22,0.17,0.1,0.1,"accent"]],
	"scale": [
		[0.28,0.29,0.21,0.18,0.07,0.16,"accent"],
		[0.28,0.39,0.21,0.045,0.16,0.05,"#a68659"],
		[0.28,0.47,0.21,0.18,0.04,0.07,"accent"],
	],
	"glasses": [
		[-0.108,0.755,0.283,0.145,0.1,0.03,"accent"],
		[0.108,0.755,0.283,0.145,0.1,0.03,"accent"],
		[-0.108,0.755,0.303,0.105,0.068,0.015,"#667486"],
		[0.108,0.755,0.303,0.105,0.068,0.015,"#667486"],
		[0,0.76,0.285,0.072,0.025,0.035,"accent"],
	],
	"key": [
		[0.25,0.4,0.23,0.065,0.21,0.05,"accent"],
		[0.25,0.49,0.23,0.135,0.06,0.06,"accent"],
		[0.285,0.32,0.23,0.08,0.055,0.05,"accent"],
	],
	"rod": [
		[0.29,0.65,-0.11,0.04,0.93,0.04,"#9f7651"],
		[0.29,0.91,-0.11,0.055,0.07,0.055,"accent"],
		[0.29,0.22,-0.11,0.07,0.15,0.07,"#5f4b44"],
	],
	"kite": [
		[0.03,0.7,-0.22,0.3,0.34,0.035,"accent"],
		[0.03,0.7,-0.246,0.028,0.34,0.025,"#a66252"],
		[0.03,0.49,-0.225,0.04,0.15,0.04,"#a66252"],
	],
	"clinic_bag": [
		[0.26,0.34,0.22,0.23,0.2,0.14,"accent"],
		[0.26,0.46,0.22,0.11,0.055,0.04,"#664d53"],
		[0.26,0.35,0.3,0.08,0.026,0.012,"#eee3cd"],
		[0.26,0.35,0.3,0.025,0.078,0.012,"#eee3cd"],
	],
	"oar": [[0.28,0.63,-0.15,0.053,0.87,0.05,"#9a6f4f"], [0.28,1.1,-0.15,0.15,0.24,0.06,"accent"]],
	"net": [
		[0.25,0.36,-0.17,0.24,0.25,0.13,"#9d8768"],
		[0.25,0.42,-0.245,0.24,0.035,0.022,"accent"],
		[0.25,0.31,-0.245,0.24,0.035,0.022,"accent"],
	],
	"gauge": [
		[0.27,0.38,0.22,0.085,0.25,0.085,"#a4b8b5"],
		[0.27,0.32,0.22,0.088,0.085,0.088,"#649394"],
		[0.27,0.51,0.22,0.11,0.035,0.11,"accent"],
	],
	"bowl": [[0.24,0.37,0.23,0.23,0.085,0.21,"#a9684c"], [0.24,0.423,0.23,0.19,0.045,0.16,"accent"]],
	"apple": [[0.27,0.37,0.225,0.13,0.12,0.13,"#bc6556"], [0.28,0.444,0.225,0.038,0.042,0.05,"#708452"]],
	"chisel": [[0.27,0.33,0.22,0.07,0.13,0.08,"#9b694f"], [0.27,0.43,0.22,0.05,0.11,0.05,"accent"]],
	"bee_hat": [
		[0,0.94,0.02,0.76,0.065,0.57,"accent"],
		[0,1.03,0.02,0.5,0.14,0.4,"#c49a54"],
		[0,0.99,0.02,0.52,0.05,0.42,"#8a673e"],
	],
	"sapling": [
		[0.28,0.29,0.21,0.15,0.13,0.15,"#a7664d"],
		[0.28,0.44,0.21,0.034,0.24,0.034,"#8a693e"],
		[0.32,0.52,0.21,0.13,0.075,0.11,"#8dad62"],
	],
	"map": [
		[0.22,0.43,0.235,0.24,0.17,0.055,"accent"],
		[0.22,0.43,0.268,0.17,0.027,0.015,"#8d7764"],
		[0.19,0.47,0.268,0.024,0.1,0.015,"#879174"],
	],
	"jam": [[0.27,0.36,0.23,0.125,0.17,0.125,"#9b5a70"], [0.27,0.455,0.23,0.138,0.045,0.138,"accent"]],
	"saw": [[0.29,0.36,-0.165,0.08,0.31,0.05,"accent"], [0.29,0.55,-0.165,0.1,0.12,0.075,"#7e5945"]],
	"bucket": [[0.28,0.3,0.2,0.2,0.19,0.18,"#9a7952"], [0.28,0.4,0.2,0.21,0.038,0.19,"accent"]],
	"hammer": [[0.29,0.4,-0.15,0.065,0.42,0.055,"#a47252"], [0.29,0.63,-0.15,0.22,0.1,0.12,"accent"]],
	"field_hat": [
		[0,0.96,0.015,0.68,0.075,0.57,"accent"],
		[0,1.03,0.015,0.45,0.105,0.39,"#936840"],
		[0,0.99,0.015,0.48,0.039,0.42,"#6d5c45"],
	],
	"lute": [
		[0.235,0.37,-0.2,0.22,0.27,0.1,"#b47a51"],
		[0.235,0.6,-0.2,0.075,0.27,0.065,"accent"],
		[0.235,0.38,-0.26,0.08,0.08,0.018,"#60433e"],
	],
	"basket": [
		[0.28,0.3,0.2,0.24,0.17,0.19,"#ad8250"],
		[0.28,0.385,0.2,0.255,0.045,0.2,"accent"],
		[0.28,0.47,0.2,0.23,0.035,0.04,"#ae8050"],
	],
	"crook": [
		[0.27,0.57,-0.12,0.043,0.88,0.043,"#b28d63"],
		[0.33,1.01,-0.12,0.15,0.047,0.047,"accent"],
		[0.39,0.96,-0.12,0.04,0.12,0.05,"accent"],
	],
	"brooch": [[0.11,0.52,0.198,0.105,0.092,0.04,"accent"], [0.11,0.53,0.225,0.053,0.056,0.02,"#e7c989"]],
	"tea": [
		[0.28,0.36,0.21,0.17,0.145,0.16,"accent"],
		[0.28,0.445,0.21,0.14,0.034,0.14,"#e0c4a1"],
		[0.38,0.37,0.21,0.08,0.055,0.065,"#d3ac75"],
	],
	"bell": [
		[0.26,0.36,0.21,0.17,0.15,0.16,"accent"],
		[0.26,0.27,0.21,0.2,0.035,0.19,"#b78654"],
		[0.26,0.456,0.21,0.07,0.052,0.068,"#805c48"],
	],
}


static func build(body: Node3D, look: Dictionary) -> Array[Node3D]:
	var skin: String = look.get("skin", "#dca481")
	var hair: String = look.get("hair", "#49312f")
	var cloth: String = look.get("cloth", "#527d76")
	var accent: String = look.get("accent", "#e7c58d")
	var pants := "#" + Color(cloth).darkened(0.35).to_html(false)
	body.scale = Vector3.ONE * clampf(float(look.get("scale", 1.0)), 0.75, 1.15)
	Meshes.box(body, Vector3(0, 0.39, 0), Vector3(0.43, 0.46, 0.32), cloth)
	var legs: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.11, 0.28, 0)
		body.add_child(leg)
		legs.append(leg)
		Meshes.box(leg, Vector3(0, -0.065, 0), Vector3(0.16, 0.20, 0.18), pants)
		Meshes.box(leg, Vector3(0, -0.205, 0.035), Vector3(0.17, 0.15, 0.25), "#674a40")
		Meshes.box(body, Vector3(side * 0.25, 0.44, 0), Vector3(0.13, 0.22, 0.16), cloth)
		Meshes.box(body, Vector3(side * 0.25, 0.305, 0.035), Vector3(0.12, 0.10, 0.14), skin)
		Meshes.box(body, Vector3(side * 0.108, 0.755, 0.264), Vector3(0.044, 0.057, 0.015), "#3e3337")
		var blush := "#" + Color(skin).lerp(Color("#c56f6c"), 0.5).to_html(false)
		Meshes.box(body, Vector3(side * 0.157, 0.688, 0.264), Vector3(0.062, 0.028, 0.014), blush)
	Meshes.box(body, Vector3(0, 0.745, 0.055), Vector3(0.49, 0.38, 0.41), skin)
	_hair(body, look.get("haircut", "cropped"), hair, accent)
	_outfit(body, look.get("outfit", "vest"), cloth, accent)
	for box in ACCESSORIES.get(look.get("accessory", ""), []):
		var color: String = accent if box[6] == "accent" else box[6]
		Meshes.box(body, Vector3(box[0], box[1], box[2]), Vector3(box[3], box[4], box[5]), color)
	return legs


static func _hair(body: Node3D, cut: String, hair: String, accent: String) -> void:
	Meshes.box(body, Vector3(0, 0.92, 0.025), Vector3(0.51, 0.11, 0.45), hair)
	Meshes.box(body, Vector3(0, 0.78, -0.128), Vector3(0.50, 0.29, 0.12), hair)
	match cut:
		"part", "sweep":
			var width := 0.25 if cut == "part" else 0.37
			Meshes.box(body, Vector3(-0.055, 0.875, 0.225), Vector3(width, 0.10, 0.10), hair)
			Meshes.box(body, Vector3(-0.19, 0.827, 0.214), Vector3(0.10, 0.10, 0.10), hair)
		"bun":
			Meshes.box(body, Vector3(0, 0.955, -0.17), Vector3(0.23, 0.18, 0.22), hair)
			Meshes.box(body, Vector3(0, 0.885, -0.20), Vector3(0.24, 0.04, 0.11), accent)
		"bob", "braids":
			for side in [-1.0, 1.0]:
				Meshes.box(body, Vector3(side * 0.227, 0.754, 0.035), Vector3(0.095, 0.32, 0.30), hair)
				if cut == "braids":
					Meshes.box(body, Vector3(side * 0.228, 0.584, 0.14), Vector3(0.085, 0.21, 0.10), hair)
					Meshes.box(body, Vector3(side * 0.228, 0.496, 0.14), Vector3(0.09, 0.035, 0.105), accent)
		"tuft":
			Meshes.box(body, Vector3(-0.065, 0.998, 0.08), Vector3(0.24, 0.09, 0.24), hair)
			Meshes.box(body, Vector3(-0.13, 1.039, 0.1), Vector3(0.11, 0.045, 0.14), hair)
		"beard":
			Meshes.box(body, Vector3(0, 0.655, 0.221), Vector3(0.34, 0.09, 0.10), hair)
			Meshes.box(body, Vector3(0, 0.605, 0.212), Vector3(0.23, 0.06, 0.105), hair)


static func _outfit(body: Node3D, outfit: String, cloth: String, accent: String) -> void:
	match outfit:
		"apron":
			Meshes.box(body, Vector3(0, 0.345, 0.169), Vector3(0.29, 0.32, 0.035), accent)
			Meshes.box(body, Vector3(0, 0.302, 0.193), Vector3(0.14, 0.094, 0.024), cloth)
		"overalls":
			Meshes.box(body, Vector3(0, 0.365, 0.174), Vector3(0.29, 0.24, 0.041), accent)
			for side in [-1.0, 1.0]:
				Meshes.box(body, Vector3(side * 0.12, 0.515, 0.178), Vector3(0.055, 0.14, 0.04), accent)
		"coat", "long_coat":
			Meshes.box(body, Vector3(0, 0.49, 0.17), Vector3(0.085, 0.24, 0.04), accent)
			for side in [-1.0, 1.0]:
				Meshes.box(body, Vector3(side * 0.12, 0.52, 0.177), Vector3(0.085, 0.10, 0.025), accent)
				if outfit == "long_coat":
					Meshes.box(body, Vector3(side * 0.17, 0.215, -0.055), Vector3(0.14, 0.23, 0.25), cloth)
		"cape":
			Meshes.box(body, Vector3(0, 0.53, 0), Vector3(0.53, 0.13, 0.37), accent)
			Meshes.box(body, Vector3(0, 0.38, -0.17), Vector3(0.44, 0.34, 0.08), cloth)
		"vest":
			for side in [-1.0, 1.0]:
				Meshes.box(body, Vector3(side * 0.11, 0.39, 0.177), Vector3(0.16, 0.33, 0.04), accent)
			Meshes.box(body, Vector3(0, 0.54, 0.178), Vector3(0.085, 0.065, 0.035), "#e5d5b4")
