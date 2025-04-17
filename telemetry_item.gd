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
@onready var angle_input = $VBoxContainer/TaskCommands/AngleInput
@onready var distance_input = $VBoxContainer/TaskCommands/DistanceInput

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
	_publish_command("state", "start_manual")

func _on_autonomous_pressed() -> void:
	_publish_command("state", "start_auto")
	
func _on_pause_pressed() -> void:
	_publish_command("state", "pause")

func _on_standby_pressed() -> void:
	_publish_command("state", "standby")
	
func _on_turn_pressed() -> void:
	var angle_val = angle_input.value
	_publish_command("manual", "turn", {"angle_deg": angle_val})
		
func _on_move_pressed() -> void:
	var distance_val = distance_input.value
	_publish_command("manual", "move", {"distance_cm": distance_val})
		
func _on_scan_pressed() -> void:
	_publish_command("manual", "scan")

func _publish_command(command_type: String, command_value: String, _args: Dictionary = {}) -> void:
	var payload = ""
	var topic = ""
	if command_type == "state":
		topic = "PolyMap/%s/cmd/state" % robot_id
		payload = command_value
	elif command_type == "manual":
		topic = "PolyMap/%s/cmd/manual" % robot_id
		if command_value == "turn":
			var angle = _args.get("angle_deg", 0)
			payload = '{"action":"turn", "angle_deg": %s, "speed":200, "timeout":5000}' % [angle]
		elif command_value == "move":
			var distance = _args.get("distance_cm", 0)
			payload = '{"action":"move", "distance_cm": %s, "speed": 200, "timeout":10000}' % [distance]
		elif command_value == "scan":
			payload = '{"action":"scan", "start_angle":30, "end_angle":150, "speed": 60, "timeout":10000}'
		
	mqtt_node.publish(topic, payload)
	print("Published command to ", topic, ":", payload)
