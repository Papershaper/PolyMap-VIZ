extends Window

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
	var mqtt = get_node("../MQTT")
	if button_pressed:
		# Attempt to connect.
		status_label.text = "Connecting..."
		mqtt.client_id = "s%d" % randi()
		if lastwill_topic.text.strip_edges() != "":
			mqtt.set_last_will(lastwill_topic.text, lastwill_message.text, lastwill_retain.pressed)
		else:
			mqtt.set_last_will("", "", false)
		if broker_user.text.strip_edges() != "":
			mqtt.set_user_pass(broker_user.text, broker_pwd.text)
		else:
			mqtt.set_user_pass(null, null)

		var url = broker_address.text.strip_edges()
		var protocol = broker_protocol.get_item_text(broker_protocol.selected)
		var port = broker_port.text.strip_edges()
		var connect_url = "%s%s:%s" % [protocol, url, port]
		var retval = mqtt.connect_to_broker(connect_url)
		if retval:
			status_label.text = "Connection initiated..."
		else:
			status_label.text = "Connection failed to initiate."
			connect_toggle.pressed = false  # revert the toggle
	else:
		status_label.text = "Disconnecting..."
		mqtt.disconnect_from_server()
		
func _on_ok_pressed():
	hide()
	
func _on_subscribe_pressed():
	var qos = 0  # Adjust QoS as needed.
	var mqtt = get_node("../MQTT")
	var topic = $VBox/HBoxSubscriptions/subscribetopic.text.strip_edges()
	mqtt.subscribe(topic, qos)
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
	var mqtt = get_node("../MQTT")
	mqtt.unsubscribe(topic)
	sel_list.remove_item(sel_list.selected)
	sel_list.disabled = (sel_list.item_count == 0)
	$VBox/HBoxSubscriptions/unsubscribe.disabled = (sel_list.item_count == 0)
	if sel_list.item_count != 0:
		sel_list.select(min(sel, sel_list.item_count - 1))
		
func _on_publish_pressed():
	var qos = 0  # Adjust QoS as needed.
	var mqtt = get_node("../MQTT")
	mqtt.publish(
		$VBox/HBoxPublish/publishtopic.text, 
		$VBox/HBoxPublish/publishmessage.text, 
		$VBox/HBoxPublish/publishretain.button_pressed, 
		qos)
