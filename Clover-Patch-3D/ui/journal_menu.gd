extends "res://action_menu.gd"
## Valley Journal: forecast, seasonal deliveries, milestones, and links to the other journal pages.

signal deliver_requested(index: int)
signal milestone_requested
signal watering_upgrade_requested
signal collection_requested
signal village_requested
signal close_requested

@onready var forecast: Label = %Forecast
@onready var order_buttons: Array[Button] = [$Rows/Order0, $Rows/Order1, $Rows/Order2]
@onready var milestone_button: Button = %Milestone
@onready var watering_upgrade_button: Button = %WateringUpgrade
