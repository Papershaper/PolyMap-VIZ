extends RefCounted
class_name PolyMapMqtt

const TOPIC_NAMESPACE := "PolyMap"
const GLOBAL_MAP_TOPIC := "PolyMap/global_map"
const CMD_STATE_SEGMENT := "cmd/state"
const CMD_MANUAL_SEGMENT := "cmd/manual"
const TELEMETRY_SEGMENT := "telemetry"


static func matches_current_global_map_topic(topic: String) -> bool:
	return topic.begins_with(GLOBAL_MAP_TOPIC)


static func matches_current_telemetry_topic(topic: String) -> bool:
	return topic.find(TELEMETRY_SEGMENT) != -1


static func parse_robot_id_from_current_telemetry_topic(topic: String) -> String:
	var parts = topic.split("/")
	if parts.size() >= 3:
		return parts[1]
	return ""


static func build_state_command_topic(robot_id: String) -> String:
	return "%s/%s/%s" % [TOPIC_NAMESPACE, robot_id, CMD_STATE_SEGMENT]


static func build_manual_command_topic(robot_id: String) -> String:
	return "%s/%s/%s" % [TOPIC_NAMESPACE, robot_id, CMD_MANUAL_SEGMENT]


static func encode_state_command(command_value: String) -> String:
	return command_value


static func encode_manual_command(action: String, args: Dictionary = {}) -> String:
	if action == "turn":
		var angle = args.get("angle_deg", 0)
		return '{"action":"turn", "angle_deg": %s, "speed":200, "timeout":5000}' % [angle]
	if action == "move":
		var distance = args.get("distance_cm", 0)
		return '{"action":"move", "distance_cm": %s, "speed": 200, "timeout":10000}' % [distance]
	if action == "scan":
		return '{"action":"scan", "start_angle":30, "end_angle":150, "speed": 60, "timeout":10000}'
	return ""


static func decode_global_map_message(message) -> Dictionary:
	var message_str = _message_to_string(message)
	var result = JSON.parse_string(message_str)
	if result == null:
		return {"ok": false, "error": "Error parsing global_map JSON: " + message_str}
	if typeof(result) != TYPE_DICTIONARY or not result.has("global_map"):
		return {"ok": false, "error": "Invalid global_map payload: missing top-level global_map key"}
	return {"ok": true, "data": result}


static func decode_telemetry_message(message) -> Dictionary:
	var message_str = _message_to_string(message)
	var result = JSON.parse_string(message_str)
	if result == null:
		return {"ok": false, "error": "Error parsing telemetry JSON: " + message_str}
	if typeof(result) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Invalid telemetry payload: expected JSON object"}
	return {"ok": true, "data": result}


static func _message_to_string(message) -> String:
	if typeof(message) == TYPE_PACKED_BYTE_ARRAY:
		return String(message)
	if typeof(message) == TYPE_STRING:
		return message
	return str(message)
