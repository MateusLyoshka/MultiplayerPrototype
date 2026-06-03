extends Control

const SERVER_PORT: int = 42069

@onready var server_ip_line: LineEdit = $VBox/ConnectRow/ServerIpLine
@onready var connect_button: Button = $VBox/ConnectRow/ConnectButton
@onready var status_label: Label = $VBox/StatusLabel
@onready var submissions_label: Label = $VBox/SubmissionsLabel
@onready var log_text: RichTextLabel = $VBox/LogText

var submission_count: int = 0

func _ready() -> void:
	connect_button.pressed.connect(_on_connect_pressed)
	ProtNetworkHandler.on_peer_connected.connect(_on_connected)
	ProtNetworkHandler.on_connection_error.connect(_on_disconnected)
	ProfessorPacketHandler.submission_received.connect(_on_submission)
	status_label.text = "Status: Desconectado"
	submissions_label.text = "Submissoes recebidas: 0"
	log_text.text = ""

func _on_connect_pressed() -> void:
	var ip: String = server_ip_line.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Status: Informe o IP do server"
		return
	connect_button.disabled = true
	status_label.text = "Status: Conectando a %s..." % ip
	ProtNetworkHandler.start_client(ip, SERVER_PORT)

func _on_connected() -> void:
	status_label.text = "Status: Conectado"

func _on_disconnected() -> void:
	status_label.text = "Status: Desconectado"
	connect_button.disabled = false

func _on_submission(room_id: int, teams: Array) -> void:
	submission_count += 1
	submissions_label.text = "Submissoes recebidas: %d" % submission_count
	log_text.append_text("[b]Sala %d[/b] — %d duplas\n" % [room_id, teams.size()])
	for i in teams.size():
		var team: Dictionary = teams[i]
		log_text.append_text("  Dupla %s — members=%s tempo=%dms respostas=%d\n" % [
			"A" if i == 0 else "B",
			str(team["members"]),
			int(team["total_msec"]),
			(team["answers"] as Array).size()
		])
