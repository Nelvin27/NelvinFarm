extends RefCounted

enum Season { SPRING, SUMMER, FALL, WINTER }

const DAYS_PER_SEASON := 30
const SEASONS := ["Spring", "Summer", "Fall", "Winter"]
const TURNIP := 0
const MOONDROP := 5
const GRASS := 22
const SEED_COUNT := 23
const APPLE := SEED_COUNT
const POND_PERCH := 24


class Crop:
	var label: String
	var season: Season
	var harvest_day: int
	var regrowth: int
	var color: String
	var edible: bool
	var requires_sickle: bool

	func _init(crop_name: String, growing_season: Season, first_day: int,
			regrow_days: int, tint: String, is_edible: bool = true, cut_with_sickle: bool = false) -> void:
		label = crop_name
		season = growing_season
		harvest_day = first_day
		regrowth = regrow_days
		color = tint
		edible = is_edible
		requires_sickle = cut_with_sickle

	func seed_price() -> int:
		return maxi(2, harvest_day / 3)

	func sale_price() -> int:
		return seed_price() + 3 + harvest_day / 4

	func grows_in(current: Season) -> bool:
		if label == "Fodder Grass":
			return current != Season.WINTER
		return current == season


# The guide counts planting as day 1 for the first harvest.
static var crops: Array[Crop] = [
	Crop.new("Turnip", Season.SPRING, 5, 0, "#d49ab1"),
	Crop.new("Potato", Season.SPRING, 8, 0, "#b58e61"),
	Crop.new("Cucumber", Season.SPRING, 10, 5, "#729d64"),
	Crop.new("Strawberry", Season.SPRING, 10, 3, "#c47178"),
	Crop.new("Cabbage", Season.SPRING, 15, 0, "#8caf72"),
	Crop.new("Moondrop Flower", Season.SPRING, 7, 0, "#d7c88d", false),
	Crop.new("Toy Flower", Season.SPRING, 13, 0, "#a891bd", false),
	Crop.new("Tomato", Season.SUMMER, 10, 3, "#be665c"),
	Crop.new("Corn", Season.SUMMER, 15, 3, "#d5b86e"),
	Crop.new("Onion", Season.SUMMER, 8, 0, "#cba68d"),
	Crop.new("Pumpkin", Season.SUMMER, 15, 0, "#c48957"),
	Crop.new("Pineapple", Season.SUMMER, 21, 5, "#c4a45b"),
	Crop.new("Pinkcat Flower", Season.SUMMER, 7, 0, "#c889ae", false),
	Crop.new("Eggplant", Season.FALL, 10, 3, "#8c719c"),
	Crop.new("Carrot", Season.FALL, 8, 0, "#cb8b5b"),
	Crop.new("Yam", Season.FALL, 7, 3, "#a9718b"),
	Crop.new("Spinach", Season.FALL, 6, 0, "#66945e", true, true),
	Crop.new("Green Pepper", Season.FALL, 8, 2, "#71955c"),
	Crop.new("Adzuki Beans", Season.FALL, 11, 4, "#aa746a"),
	Crop.new("Chili Pepper", Season.FALL, 13, 5, "#b95754"),
	Crop.new("Magic Flower", Season.FALL, 11, 0, "#798fb7", false),
	Crop.new("Sunsweet Flower", Season.FALL, 11, 0, "#cfb477", false),
	Crop.new("Fodder Grass", Season.SPRING, 2, 1, "#799954", false, true),
	Crop.new("Orchard Apple", Season.FALL, 2, 0, "#b85c50"),
	Crop.new("Pond Perch", Season.SPRING, 4, 0, "#80a7a0"),
]


static func season_for(day: int) -> Season:
	return ((day - 1) / DAYS_PER_SEASON % SEASONS.size()) as Season


static func day_of_season(day: int) -> int:
	return (day - 1) % DAYS_PER_SEASON + 1
