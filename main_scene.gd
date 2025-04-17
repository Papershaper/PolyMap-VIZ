extends Control

var receivedmessagecount = 0

@onready var connection_indicator = $StatusIndicator  # TextureRect for connection status
@onready var connection_dialog   = $ConnectionDialog
@onready var clear_button = $ClearButton
@onready var mqtt_button = $MQTTButton

func _ready():
	print("Main scene ready.")
	clear_button.pressed.connect(_on_clear_pressed)
	mqtt_button.pressed.connect(_on_open_connection_dialog_pressed)
	connectedactionsactive(false)
	
	# Set the connection indicator to red (disconnected) initially.
	_update_status_indicator(false)
	
	# Connect MQTT signals if not already connected via the editor
	$MQTT.broker_connected.connect(_on_mqtt_broker_connected)
	$MQTT.broker_disconnected.connect(_on_mqtt_broker_disconnected)
	$MQTT.broker_connection_failed.connect(_on_mqtt_broker_connection_failed)
	$MQTT.received_message.connect(_on_mqtt_received_message)
	
	randomize()  # For generating random client IDs
	
func _on_open_connection_dialog_pressed():
	connection_dialog.popup_centered()

func brokersettingsactive(active):
	$ConnectionDialog/VBox/HBoxBroker/brokeraddress.editable = active
	$ConnectionDialog/VBox/HBoxBroker/brokerport.editable = active
	$ConnectionDialog/VBox/HBoxBroker/brokerprotocol.disabled = not active
	$ConnectionDialog/VBox/HBoxLastwill/lastwilltopic.editable = active
	$ConnectionDialog/VBox/HBoxLastwill/lastwillmessage.editable = active
	$ConnectionDialog/VBox/HBoxLastwill/lastwillretain.disabled = not active
	$ConnectionDialog/VBox/HBoxBrokerControl/ButtonConnect.button_pressed = not active

func connectedactionsactive(active):
	$ConnectionDialog/VBox/HBoxSubscriptions/subscribetopic.editable = active
	$ConnectionDialog/VBox/HBoxSubscriptions/subscribe.disabled = not active
	$ConnectionDialog/VBox/HBoxPublish/publishtopic.editable = active
	$ConnectionDialog/VBox/HBoxPublish/publishmessage.editable = active
	$ConnectionDialog/VBox/HBoxPublish/publishretain.disabled = not active
	$ConnectionDialog/VBox/HBoxPublish/publish.disabled = not active
	if not active:
		$ConnectionDialog/VBox/HBoxSubscriptions/subscriptions.clear()
	$ConnectionDialog/VBox/HBoxSubscriptions/subscriptions.disabled = true
	$ConnectionDialog/VBox/HBoxSubscriptions/unsubscribe.disabled = true

func _on_mqtt_broker_connected():
	$ConnectionDialog/VBox/HBoxBrokerControl/status.text = "connected."
	brokersettingsactive(false)
	connectedactionsactive(true)
	receivedmessagecount = 0
	_update_status_indicator(true)

func _on_mqtt_broker_disconnected():
	$ConnectionDialog/VBox/HBoxBrokerControl/status.text = "disconnected."
	brokersettingsactive(true)
	connectedactionsactive(false)
	_update_status_indicator(false)

func _on_mqtt_broker_connection_failed():
	$ConnectionDialog/VBox/HBoxBrokerControl/status.text = "failed."
	brokersettingsactive(true)
	connectedactionsactive(false)
	_update_status_indicator(false)

func _on_mqtt_received_message(topic: String, message) -> void:
	print("message recieved: " + topic)
	if receivedmessagecount == 0:
		$ConnectionDialog/VBox/subscribedmessages.clear()
	receivedmessagecount += 1
	if $MQTT.verbose_level == 2:
		$ConnectionDialog/VBox/subscribedmessages.append_text("[b]%s[/b] %s\n" % [topic, message])
	else:
		$ConnectionDialog/VBox/subscribedmessages.append_text("[b]{topic}[/b] \n ")
	
	# If the message is a global map update, forward it to the 3D visualization.
	if topic.begins_with("PolyMap/global_map"):
		var message_str: String = ""
		if typeof(message) == TYPE_PACKED_BYTE_ARRAY:
			message_str = String(message)
		else:
			message_str = message

		var result = JSON.parse_string(message_str)
		if result == null:
			push_error("Error parsing global_map JSON: " + message_str)
			return
		# Expecting a dictionary with keys "timestamp" and "global_map"
		if typeof(result) == TYPE_DICTIONARY and result.has("global_map"):
			$SubViewportContainer/SubViewport/GlobalMapScene.update_map(result)
		return
	
	if topic.find("telemetry") != -1:
		var parts = topic.split("/")
		if parts.size() >= 3:
			var robot_id = parts[1]
			var message_str: String = ""
			if typeof(message) == TYPE_PACKED_BYTE_ARRAY:
				message_str = String(message)
			else:
				message_str = message
			var data = JSON.parse_string(message_str)
			if data == null:
				push_error("Error parsing telemetry JSON: " + message_str)
				return
			# Update the telemetry panel with this robot's data.
			update_telemetry(robot_id, data)
			$SubViewportContainer/SubViewport/GlobalMapScene.update_robot_marker(robot_id, data)
			
func _update_status_indicator(mqtt_connected: bool):
	if mqtt_connected:
		connection_indicator.texture = load("res://assets/green_dot.png")
	else:
		connection_indicator.texture = load("res://assets/red_dot.png")

func _on_clear_pressed():
	$SubViewportContainer/SubViewport/GlobalMapScene.clear_map()
	
func update_telemetry(robot_id: String, telemetry_data: Dictionary) -> void:
	# Assuming $Panel/TelemetryList is a VBoxContainer.
	var telemetry_list = $Panel/TelemetryList
	# Try to get a child node with the robot_id as its name.
	var telemetry_item = telemetry_list.get_node_or_null(robot_id)
	if telemetry_item == null:
		# Instance a new TelemetryItem if not already present.
		var TelemetryItemScene = preload("res://telemetry_item.tscn")
		telemetry_item = TelemetryItemScene.instantiate()
		telemetry_item.name = robot_id  # Set the node's name for lookup.
		telemetry_list.add_child(telemetry_item)
		telemetry_item.setup(robot_id, telemetry_data)
	else:
		# Update the existing TelemetryItem with new telemetry data.
		telemetry_item.setup(robot_id, telemetry_data)
