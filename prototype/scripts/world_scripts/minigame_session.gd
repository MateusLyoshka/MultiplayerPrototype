extends Node

const QUIZ_JSON_PATH := "res://prototype/data/minigame_quiz.json"

@onready var waiting_label: Label = $"../WaitingLabel"
@onready var document_panel: PanelContainer = $"../DocumentPanel"
@onready var doc_title_label: Label = $"../DocumentPanel/VBox/DocTitleLabel"
@onready var document_text: RichTextLabel = $"../DocumentPanel/VBox/DocumentText"
@onready var quiz_panel: PanelContainer = $"../QuizPanel"
@onready var question_label: Label = $"../QuizPanel/VBox/QuestionLabel"
@onready var answer_line: LineEdit = $"../QuizPanel/VBox/AnswerLine"
@onready var submit_button: Button = $"../QuizPanel/VBox/SubmitButton"
@onready var team_hud: VBoxContainer = $"../TeamHUD"
@onready var timer_label: Label = $"../TeamHUD/TimerLabel"
@onready var progress_label: Label = $"../TeamHUD/ProgressLabel"
@onready var score_label: Label = $"../TeamHUD/ScoreLabel"
@onready var team_info_label: Label = $"../TeamHUD/TeamInfoLabel"

var quiz_data: Dictionary = {}
var total_questions: int = 0

var my_team: int = -1
var my_role: int = -1
var my_partner_id: int = -1
var my_team_members: Array[int] = []
var assigned: bool = false

var start_msec: int = 0

func _ready() -> void:
	if not _load_quiz():
		push_error("Minigame: falha ao carregar %s" % QUIZ_JSON_PATH)
		return

	if GamePacketHandler.is_host:
		# Host conhece os ids da partida e calcula tudo localmente; não fica
		# esperando seu próprio pacote pelo loopback (broadcast não volta ao remetente).
		_host_assign_and_dispatch()
	else:
		# O assign chega no broadcast quase junto com o SceneForcePacket que nos
		# trouxe; pode ter chegado antes desta cena existir. Conferir o buffer.
		if ClientPacketHandler.pending_minigame_assign != null:
			var p: MinigameAssignPkt = ClientPacketHandler.pending_minigame_assign
			ClientPacketHandler.pending_minigame_assign = null
			_apply_assignment(p.team, p.role, p.partner_id, p.member_ids)
		else:
			ClientPacketHandler.minigame_assigned.connect(_on_assign_signal)

func _process(_delta: float) -> void:
	if not assigned:
		return
	var elapsed: int = (Time.get_ticks_msec() - start_msec) / 1000
	timer_label.text = "Tempo: %ds" % elapsed

func _load_quiz() -> bool:
	var f: FileAccess = FileAccess.open(QUIZ_JSON_PATH, FileAccess.READ)
	if f == null:
		return false
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	quiz_data = parsed
	total_questions = (quiz_data.get("questions", []) as Array).size()
	return true

func _host_assign_and_dispatch() -> void:
	var ids: Array[int] = ClientPacketHandler.spawned_ids.duplicate()
	ids.sort()
	# Dupla A: ids[0] DOC, ids[1] QUIZ — Dupla B: ids[2] DOC, ids[3] QUIZ.
	# Determinístico via sort para que host e clientes derivem a mesma partição.
	for i in ids.size():
		var player_id: int = ids[i]
		var team: int = 0 if i < 2 else 1
		var role: int = MinigameAssignPkt.ROLE.DOC if i % 2 == 0 else MinigameAssignPkt.ROLE.QUIZ
		var partner: int = ids[i + 1] if i % 2 == 0 else ids[i - 1]
		var members: Array[int] = [ids[i - i % 2], ids[i - i % 2 + 1]]
		if player_id == ClientPacketHandler.my_id:
			# Broadcast do ENet não volta ao remetente; aplicamos localmente.
			_apply_assignment(team, role, partner, members)
		else:
			MinigameAssignPkt.create(player_id, team, role, partner, members).broadcast(GamePacketHandler.host_connection)

func _on_assign_signal(pkt: MinigameAssignPkt) -> void:
	ClientPacketHandler.pending_minigame_assign = null
	_apply_assignment(pkt.team, pkt.role, pkt.partner_id, pkt.member_ids)

func _apply_assignment(team: int, role: int, partner: int, members: Array[int]) -> void:
	my_team = team
	my_role = role
	my_partner_id = partner
	my_team_members = members
	assigned = true
	start_msec = Time.get_ticks_msec()

	# Chat consulta ClientPacketHandler para filtrar/colorir; aqui é o único
	# ponto comum entre host (aplica local) e player (vem do pacote).
	ClientPacketHandler.minigame_team = team
	ClientPacketHandler.minigame_team_members = members.duplicate()

	waiting_label.visible = false
	team_hud.visible = true
	team_info_label.text = "Dupla %s — voce: %s | parceiro: player_%d" % [
		"A" if team == 0 else "B",
		"DOC" if role == MinigameAssignPkt.ROLE.DOC else "QUIZ",
		partner
	]
	progress_label.text = "Pergunta 0 de %d" % total_questions
	score_label.text = "Acertos: 0  Erros: 0"

	if role == MinigameAssignPkt.ROLE.DOC:
		_setup_document_view()
	else:
		_setup_quiz_view()

func _setup_document_view() -> void:
	document_panel.visible = true
	quiz_panel.visible = false
	doc_title_label.text = String(quiz_data.get("document_title", "Documento"))
	document_text.text = String(quiz_data.get("document_text", ""))

func _setup_quiz_view() -> void:
	quiz_panel.visible = true
	document_panel.visible = false
	# Skeleton da Fase 2: mostra a primeira pergunta. O loop de envio/validação
	# vem na Fase 3 (MinigameAnswerPkt / MinigameProgressPkt).
	var questions: Array = quiz_data.get("questions", [])
	if questions.is_empty():
		question_label.text = "(sem perguntas no JSON)"
		return
	var first: Dictionary = questions[0]
	question_label.text = "1) %s" % first.get("prompt", "")
	answer_line.text = ""
	answer_line.editable = false
	submit_button.disabled = true
	submit_button.text = "Enviar (Fase 3)"
