extends Panel

# A property to store the unique robot identifier.
var robot_id: String

# Preload or get the MQTT node as needed.
@onready var mqtt_node = get_node("/root/MainScene/MQTT")
@onready var robot_info_label = $VBoxContainer/Label
@onready var manual_button = $VBoxContainer/StateChangeButtons/manual
@onready var autonomous_button = $VBoxContainer/StateChangeButtons/autonomous
@onready var standby_button = $VBoxContainer/StateChangeButtons/standby
@onready var pause_button = $VBoxContainer/StateChangeButtons/pause
@onready var move_button = $VBoxContainer/TaskCommands/Move
@onready var turn_button = $VBoxContainer/TaskCommands/Turn
@onready var scan_button = $VBoxContainer/TaskCommands/Scan

func _ready():
	# Connect button signals in your scene.
	manual_button.pressed.connect(_on_manual_pressed)
	autonomous_button.pressed.connect(_on_autonomous_pressed)
	standby_button.pressed.connect(_on_standby_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	move_button.pressed.connect(_on_move_pressed)
	turn_button.pressed.connect(_on_turn_pressed)
	scan_button.pressed.connect(_on_scan_pressed)
	
func setup(robot_id_passed: String, telemetry_data: Dictionary) -> void:
	# Update the label with detailed robot info.
	robot_id = robot_id_passed
	robot_info_label.text = "Robot: %s\nPose: %s\nLoc: %s, %s\nState: %s\nSub State: %s" % [
		robot_id,
		str(telemetry_data.get("orientation_rad", "N/A")),
		str(telemetry_data.get("gridX", "N/A")),
		str(telemetry_data.get("gridY", "N/A")),
		str(telemetry_data.get("robot_state", "N/A")),
		str(telemetry_data.get("agent_state", "None"))
	]
	
	# Optionally, update other UI controls based on telemetry_data

func _on_manual_pressed() -> void:
	_publish_command("state", "manual")

func _on_autonomous_pressed() -> void:
	_publish_command("state", "autonomous")
	
func _on_pause_pressed() -> void:
	_publish_command("state", "pause")

func _on_standby_pressed() -> void:
	_publish_command("state", "standby")
	
func _on_turn_pressed() -> void:
	_publish_command("manual", "turn")
		
func _on_move_pressed() -> void:
	_publish_command("manual", "move")
		
func _on_scan_pressed() -> void:
	_publish_command("manual", "scan")

func _publish_command(command_type: String, command_value: String, _args: Dictionary = {}) -> void:
	var payload = ""
	var topic = ""
	if command_type == "state":
		payload = "start_%s" % [command_value]
		topic = "PolyMap/%s/cmd/state" % robot_id
	elif command_type == "manual":
		topic = "PolyMap/%s/cmd/manual" % robot_id
		if command_value == "turn":
			payload = '{"action":"turn", "angle_deg": -90, "speed":200, "timeout":5000}'
		elif command_value == "move":
			payload = '{"action":"move", "distance_cm": 30, "speed": 200, "timeout":10000}'
		elif command_value == "scan":
			payload = '{"action":"scan", "start_angle":30, "end_angle":150, "speed": 60, "timeout":10000}'
		
	mqtt_node.publish(topic, payload)
	print("Published command to ", topic, ":", payload)
