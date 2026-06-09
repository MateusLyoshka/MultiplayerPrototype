extends Control

const SERVER_PORT: int = 42069
const QUIZ_JSON_PATH := "res://data/minigame_quiz.json"

@onready var server_ip_line: LineEdit = $VBox/ConnectRow/ServerIpLine
@onready var connect_button: Button = $VBox/ConnectRow/ConnectButton
@onready var status_label: Label = $VBox/StatusLabel
@onready var summary_label: Label = $VBox/SummaryLabel
@onready var submissions_vbox: VBoxContainer = $VBox/ScrollContainer/SubmissionsVBox

# (room_id, team_index) -> bool. True quando ja enviamos nota.
var graded: Dictionary[String, bool] = {}
# (room_id) -> Node do card, para evitar duplicar se a mesma sala chegar de novo.
var room_cards: Dictionary[int, Node] = {}
var room_headers: Dictionary[int, Button] = {}
var room_bodies: Dictionary[int, VBoxContainer] = {}
var room_team_counts: Dictionary[int, int] = {}
var quiz_questions: Array = []
var submission_count: int = 0

func _ready() -> void:
	connect_button.pressed.connect(_on_connect_pressed)
	ProtNetworkHandler.on_peer_connected.connect(_on_connected)
	ProtNetworkHandler.on_connection_error.connect(_on_disconnected)
	ProfessorPacketHandler.submission_received.connect(_on_submission)
	_load_quiz()
	_update_summary()

func _load_quiz() -> void:
	var f: FileAccess = FileAccess.open(QUIZ_JSON_PATH, FileAccess.READ)
	if f == null:
		push_warning("Quiz JSON nao encontrado em %s" % QUIZ_JSON_PATH)
		return
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		quiz_questions = (parsed as Dictionary).get("questions", [])

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

func _update_summary() -> void:
	if submission_count == 0:
		summary_label.text = "Aguardando submissoes..."
	else:
		summary_label.text = "Submissoes recebidas: %d" % submission_count

func _on_submission(room_id: int, teams: Array) -> void:
	submission_count += 1
	_update_summary()
	# Preserva o estado colapsado da sala quando o card e recriado.
	var was_collapsed: bool = false
	if room_cards.has(room_id):
		if room_bodies.has(room_id):
			was_collapsed = not room_bodies[room_id].visible
		room_cards[room_id].queue_free()
	var card: PanelContainer = _build_room_card(room_id, teams)
	submissions_vbox.add_child(card)
	room_cards[room_id] = card
	if was_collapsed and room_bodies.has(room_id):
		room_bodies[room_id].visible = false
		_update_header_text(room_id)

func _build_room_card(room_id: int, teams: Array) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	var card_vbox: VBoxContainer = VBoxContainer.new()
	card.add_child(card_vbox)
	var header: Button = Button.new()
	header.add_theme_font_size_override("font_size", 20)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card_vbox.add_child(header)
	var body: VBoxContainer = VBoxContainer.new()
	card_vbox.add_child(body)
	for i in teams.size():
		body.add_child(_build_team_section(room_id, i, teams[i]))
		if i + 1 < teams.size():
			body.add_child(HSeparator.new())
	room_headers[room_id] = header
	room_bodies[room_id] = body
	room_team_counts[room_id] = teams.size()
	header.pressed.connect(func() -> void:
		body.visible = not body.visible
		_update_header_text(room_id)
	)
	_update_header_text(room_id)
	return card

func _update_header_text(room_id: int) -> void:
	if not room_headers.has(room_id) or not room_bodies.has(room_id):
		return
	var arrow: String = "v" if room_bodies[room_id].visible else ">"
	room_headers[room_id].text = "Sala %d (%d duplas) %s" % [room_id, room_team_counts.get(room_id, 0), arrow]

func _build_team_section(room_id: int, team_index: int, team: Dictionary) -> VBoxContainer:
	var vbox: VBoxContainer = VBoxContainer.new()
	var team_letter: String = "A" if team_index == 0 else "B"
	var members: Array = team["members"]
	var total_msec: int = int(team["total_msec"])
	var answers: Array = team["answers"]
	var submission_msecs: Array = team["submission_msecs"]

	var team_header: Label = Label.new()
	team_header.text = "Dupla %s — players %s — tempo total: %.1fs" % [team_letter, str(members), total_msec / 1000.0]
	team_header.add_theme_font_size_override("font_size", 16)
	vbox.add_child(team_header)

	for q_idx in answers.size():
		vbox.add_child(_build_question_row(q_idx, answers[q_idx], submission_msecs[q_idx]))

	# Form de grade
	var form: HBoxContainer = HBoxContainer.new()
	var grade_label: Label = Label.new()
	grade_label.text = "Nota:"
	form.add_child(grade_label)
	var grade_spin: SpinBox = SpinBox.new()
	grade_spin.min_value = 0
	grade_spin.max_value = 10
	grade_spin.step = 1
	grade_spin.value = 0
	grade_spin.rounded = true
	grade_spin.allow_greater = false
	grade_spin.allow_lesser = false
	grade_spin.custom_minimum_size = Vector2(90, 0)
	form.add_child(grade_spin)
	var comment_label: Label = Label.new()
	comment_label.text = "  Comentario:"
	form.add_child(comment_label)
	var comment_line: LineEdit = LineEdit.new()
	comment_line.placeholder_text = "Feedback para a dupla (opcional)"
	comment_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(comment_line)
	var send_button: Button = Button.new()
	send_button.text = "Enviar nota"
	form.add_child(send_button)
	var status: Label = Label.new()
	status.text = "  Pendente"
	form.add_child(status)
	vbox.add_child(form)

	var key: String = "%d-%d" % [room_id, team_index]
	send_button.pressed.connect(func() -> void:
		var clamped: int = clampi(int(round(grade_spin.value)), 0, 10)
		grade_spin.value = clamped
		var pkt: MinigameGradePkt = MinigameGradePkt.create(room_id, team_index, float(clamped), comment_line.text)
		pkt.send(ProtNetworkHandler.server_peer)
		graded[key] = true
		grade_spin.editable = false
		comment_line.editable = false
		send_button.disabled = true
		status.text = "  Enviada"
	)
	return vbox

func _build_question_row(idx: int, answer: String, submission_msec: int) -> VBoxContainer:
	var qbox: VBoxContainer = VBoxContainer.new()
	var prompt: String = "(pergunta %d)" % (idx + 1)
	if idx < quiz_questions.size():
		var q: Dictionary = quiz_questions[idx]
		prompt = "%d) %s" % [idx + 1, q.get("prompt", "")]
	var prompt_label: Label = Label.new()
	prompt_label.text = prompt
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qbox.add_child(prompt_label)
	var answer_label: Label = Label.new()
	answer_label.text = "Resposta: %s   [tempo: %.1fs]" % [answer, submission_msec / 1000.0]
	answer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qbox.add_child(answer_label)
	return qbox
