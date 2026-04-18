extends Window

signal connect_requested(protocol: String, address: String, port: String, username: String, password: String, last_will_topic: String, last_will_message: String, last_will_retain: bool)
signal disconnect_requested()
signal subscribe_requested(topic: String, qos: int)
signal unsubscribe_requested(topic: String)
signal publish_requested(topic: String, message: String, retain: bool, qos: int)

# References to the input fields in the dialog.
@onready var broker_address = $VBox/HBoxBroker/brokeraddress
@onready var broker_protocol = $VBox/HBoxBroker/brokerprotocol
@onready var broker_port = $VBox/HBoxBroker/brokerport
@onready var broker_user = $VBox/HBoxBroker/brokeruser
@onready var broker_pwd = $VBox/HBoxBroker/brokerpswd
@onready var lastwill_topic = $VBox/HBoxLastwill/lastwilltopic
@onready var lastwill_message = $VBox/HBoxLastwill/lastwillmessage
@onready var lastwill_retain = $VBox/HBoxLastwill/lastwillretain
@onready var subscribe_button = $VBox/HBoxSubscriptions/subscribe
@onready var unsubscribe_button = $VBox/HBoxSubscriptions/unsubscribe
@onready var connect_toggle = $VBox/HBoxBrokerControl/ButtonConnect
@onready var publish_button = $VBox/HBoxPublish/publish
@onready var status_label = $VBox/HBoxBrokerControl/status
@onready var	 ok_button = $VBox/HBoxBrokerControl/ButtonOK

func _ready():
	connect_toggle.toggled.connect(_on_connect_toggle)
	broker_protocol.item_selected.connect(_on_brokerprotocol_item_selected)
	subscribe_button.pressed.connect(_on_subscribe_pressed)
	unsubscribe_button.pressed.connect(_on_unsubscribe_pressed)
	publish_button.pressed.connect(_on_publish_pressed)
	ok_button.pressed.connect(_on_ok_pressed)
	# Optionally, set an initial default port
	_on_brokerprotocol_item_selected(broker_protocol.selected)

func _on_brokerprotocol_item_selected(index):
	# Set default port based on protocol selection [tcp, ssl, ws, wss]
	var default_ports = [1883, 8886, 8080, 8081]
	broker_port.text = "%d" % default_ports[index]

func _on_connect_toggle(button_pressed):
	if button_pressed:
		status_label.text = "Connecting..."
		connect_requested.emit(
			broker_protocol.get_item_text(broker_protocol.selected),
			broker_address.text.strip_edges(),
			broker_port.text.strip_edges(),
			broker_user.text.strip_edges(),
			broker_pwd.text,
			lastwill_topic.text.strip_edges(),
			lastwill_message.text,
			lastwill_retain.button_pressed
		)
	else:
		status_label.text = "Disconnecting..."
		disconnect_requested.emit()
		
func _on_ok_pressed():
	hide()
	
func _on_subscribe_pressed():
	var qos = 0  # Adjust QoS as needed.
	var topic = $VBox/HBoxSubscriptions/subscribetopic.text.strip_edges()
	subscribe_requested.emit(topic, qos)
	for i in range($VBox/HBoxSubscriptions/subscriptions.item_count):
		if topic == $VBox/HBoxSubscriptions/subscriptions.get_item_text(i):
			return
	$VBox/HBoxSubscriptions/subscriptions.add_item(topic)
	$VBox/HBoxSubscriptions/subscriptions.select($VBox/HBoxSubscriptions/subscriptions.item_count - 1)
	$VBox/HBoxSubscriptions/subscriptions.disabled = false
	$VBox/HBoxSubscriptions/unsubscribe.disabled = false

func _on_unsubscribe_pressed():
	var sel_list = $VBox/HBoxSubscriptions/subscriptions
	var sel = sel_list.selected
	var topic = sel_list.get_item_text(sel)
	unsubscribe_requested.emit(topic)
	sel_list.remove_item(sel_list.selected)
	sel_list.disabled = (sel_list.item_count == 0)
	$VBox/HBoxSubscriptions/unsubscribe.disabled = (sel_list.item_count == 0)
	if sel_list.item_count != 0:
		sel_list.select(min(sel, sel_list.item_count - 1))
		
func _on_publish_pressed():
	var qos = 0  # Adjust QoS as needed.
	publish_requested.emit(
		$VBox/HBoxPublish/publishtopic.text,
		$VBox/HBoxPublish/publishmessage.text,
		$VBox/HBoxPublish/publishretain.button_pressed,
		qos
	)


func show_connected() -> void:
	status_label.text = "connected."
	_set_broker_settings_active(false)
	_set_connected_actions_active(true)
	connect_toggle.set_pressed_no_signal(true)


func show_disconnected() -> void:
	status_label.text = "disconnected."
	_set_broker_settings_active(true)
	_set_connected_actions_active(false)
	connect_toggle.set_pressed_no_signal(false)


func show_connection_failed() -> void:
	status_label.text = "failed."
	_set_broker_settings_active(true)
	_set_connected_actions_active(false)
	connect_toggle.set_pressed_no_signal(false)


func show_connection_initiated() -> void:
	status_label.text = "Connection initiated..."


func show_connection_initiation_failed() -> void:
	status_label.text = "Connection failed to initiate."
	connect_toggle.set_pressed_no_signal(false)


func clear_received_messages() -> void:
	$VBox/subscribedmessages.clear()


func append_received_message(topic: String, message, verbose_level: int) -> void:
	if verbose_level == 2:
		$VBox/subscribedmessages.append_text("[b]%s[/b] %s\n" % [topic, message])
	else:
		$VBox/subscribedmessages.append_text("[b]%s[/b]\n" % topic)


func _set_broker_settings_active(active: bool) -> void:
	broker_address.editable = active
	broker_port.editable = active
	broker_protocol.disabled = not active
	lastwill_topic.editable = active
	lastwill_message.editable = active
	lastwill_retain.disabled = not active
	connect_toggle.set_pressed_no_signal(not active)


func _set_connected_actions_active(active: bool) -> void:
	$VBox/HBoxSubscriptions/subscribetopic.editable = active
	$VBox/HBoxSubscriptions/subscribe.disabled = not active
	$VBox/HBoxPublish/publishtopic.editable = active
	$VBox/HBoxPublish/publishmessage.editable = active
	$VBox/HBoxPublish/publishretain.disabled = not active
	$VBox/HBoxPublish/publish.disabled = not active
	if not active:
		$VBox/HBoxSubscriptions/subscriptions.clear()
	$VBox/HBoxSubscriptions/subscriptions.disabled = true
	$VBox/HBoxSubscriptions/unsubscribe.disabled = true
