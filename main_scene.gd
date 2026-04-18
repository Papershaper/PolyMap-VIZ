extends Control

const PolyMapMqtt = preload("res://polymap_mqtt.gd")
const TelemetryItemScene = preload("res://telemetry_item.tscn")

var receivedmessagecount = 0

@onready var mqtt = $MQTT
@onready var connection_indicator = $StatusIndicator  # TextureRect for connection status
@onready var connection_dialog   = $ConnectionDialog
@onready var clear_button = $ClearButton
@onready var mqtt_button = $MQTTButton
@onready var reset_button = $ResetButton
@onready var telemetry_list = $Panel/TelemetryList
@onready var global_map_scene = $SubViewportContainer/SubViewport/GlobalMapScene

func _ready():
	print("Main scene ready.")
	clear_button.pressed.connect(_on_clear_pressed)
	mqtt_button.pressed.connect(_on_open_connection_dialog_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	connection_dialog.show_disconnected()
	
	# Set the connection indicator to red (disconnected) initially.
	_update_status_indicator(false)
	
	# Connect MQTT signals if not already connected via the editor
	mqtt.broker_connected.connect(_on_mqtt_broker_connected)
	mqtt.broker_disconnected.connect(_on_mqtt_broker_disconnected)
	mqtt.broker_connection_failed.connect(_on_mqtt_broker_connection_failed)
	mqtt.received_message.connect(_on_mqtt_received_message)
	connection_dialog.connect_requested.connect(_on_connection_dialog_connect_requested)
	connection_dialog.disconnect_requested.connect(_on_connection_dialog_disconnect_requested)
	connection_dialog.subscribe_requested.connect(_on_connection_dialog_subscribe_requested)
	connection_dialog.unsubscribe_requested.connect(_on_connection_dialog_unsubscribe_requested)
	connection_dialog.publish_requested.connect(_on_connection_dialog_publish_requested)
	
	randomize()  # For generating random client IDs
	
func _on_open_connection_dialog_pressed():
	connection_dialog.popup_centered()

func _on_mqtt_broker_connected():
	connection_dialog.show_connected()
	receivedmessagecount = 0
	_update_status_indicator(true)

func _on_mqtt_broker_disconnected():
	connection_dialog.show_disconnected()
	_update_status_indicator(false)

func _on_mqtt_broker_connection_failed():
	connection_dialog.show_connection_failed()
	_update_status_indicator(false)

func _on_mqtt_received_message(topic: String, message) -> void:
	print("message recieved: " + topic)
	if receivedmessagecount == 0:
		connection_dialog.clear_received_messages()
	receivedmessagecount += 1
	connection_dialog.append_received_message(topic, message, mqtt.verbose_level)
	
	# If the message is a global map update, forward it to the 3D visualization.
	if PolyMapMqtt.matches_current_global_map_topic(topic):
		var decoded_global_map = PolyMapMqtt.decode_global_map_message(message)
		if not decoded_global_map.get("ok", false):
			push_error(decoded_global_map.get("error", "Unknown global_map parse error"))
			return
		global_map_scene.update_map(decoded_global_map.get("data", {}))
		return
	
	if PolyMapMqtt.matches_current_telemetry_topic(topic):
		var robot_id = PolyMapMqtt.parse_robot_id_from_current_telemetry_topic(topic)
		if robot_id == "":
			return
		var decoded_telemetry = PolyMapMqtt.decode_telemetry_message(message)
		if not decoded_telemetry.get("ok", false):
			push_error(decoded_telemetry.get("error", "Unknown telemetry parse error"))
			return
		# Update the telemetry panel with this robot's data.
		var telemetry_data = decoded_telemetry.get("data", {})
		update_telemetry(robot_id, telemetry_data)
		global_map_scene.update_robot_marker(robot_id, telemetry_data)
			
func _update_status_indicator(mqtt_connected: bool):
	if mqtt_connected:
		connection_indicator.texture = load("res://assets/green_dot.png")
	else:
		connection_indicator.texture = load("res://assets/red_dot.png")

func _on_clear_pressed():
	global_map_scene.clear_map()

func _on_reset_pressed():
	global_map_scene.reset_view()
	
func update_telemetry(robot_id: String, telemetry_data: Dictionary) -> void:
	# Try to get a child node with the robot_id as its name.
	var telemetry_item = telemetry_list.get_node_or_null(robot_id)
	if telemetry_item == null:
		# Instance a new TelemetryItem if not already present.
		telemetry_item = TelemetryItemScene.instantiate()
		telemetry_item.name = robot_id  # Set the node's name for lookup.
		telemetry_list.add_child(telemetry_item)
		telemetry_item.state_command_requested.connect(_on_telemetry_item_state_command_requested)
		telemetry_item.manual_command_requested.connect(_on_telemetry_item_manual_command_requested)
	# Update the existing TelemetryItem with new telemetry data.
	telemetry_item.setup(robot_id, telemetry_data)


func _on_connection_dialog_connect_requested(protocol: String, address: String, port: String, username: String, password: String, last_will_topic: String, last_will_message: String, last_will_retain: bool) -> void:
	mqtt.client_id = "s%d" % randi()
	if last_will_topic != "":
		mqtt.set_last_will(last_will_topic, last_will_message, last_will_retain)
	else:
		mqtt.set_last_will("", "", false)
	if username != "":
		mqtt.set_user_pass(username, password)
	else:
		mqtt.set_user_pass(null, null)

	var connect_url = "%s%s:%s" % [protocol, address, port]
	if mqtt.connect_to_broker(connect_url):
		connection_dialog.show_connection_initiated()
	else:
		connection_dialog.show_connection_initiation_failed()


func _on_connection_dialog_disconnect_requested() -> void:
	mqtt.disconnect_from_server()


func _on_connection_dialog_subscribe_requested(topic: String, qos: int) -> void:
	mqtt.subscribe(topic, qos)


func _on_connection_dialog_unsubscribe_requested(topic: String) -> void:
	mqtt.unsubscribe(topic)


func _on_connection_dialog_publish_requested(topic: String, message: String, retain: bool, qos: int) -> void:
	mqtt.publish(topic, message, retain, qos)


func _on_telemetry_item_state_command_requested(robot_id: String, command_value: String) -> void:
	var topic = PolyMapMqtt.build_state_command_topic(robot_id)
	var payload = PolyMapMqtt.encode_state_command(command_value)
	mqtt.publish(topic, payload)
	print("Published command to ", topic, ":", payload)


func _on_telemetry_item_manual_command_requested(robot_id: String, action: String, args: Dictionary) -> void:
	var topic = PolyMapMqtt.build_manual_command_topic(robot_id)
	var payload = PolyMapMqtt.encode_manual_command(action, args)
	mqtt.publish(topic, payload)
	print("Published command to ", topic, ":", payload)
