extends Node

# Roteia pacotes do server central que sao relevantes pra UI do professor.
# Por enquanto so MINIGAME_SUBMISSION (entrega das duplas) e PEER_ID (id
# atribuido pelo server, guardamos por simetria com o client).

signal submission_received(room_id: int, teams: Array)

var my_id: int = -1

func _ready() -> void:
	ProtNetworkHandler.from_server_packet.connect(packet_handler)
	ProtNetworkHandler.on_peer_connected.connect(_on_connected)

func _on_connected() -> void:
	# Sinaliza ao server que este peer e o professor antes de receber qualquer
	# submissao pendente. O server vai despachar as submissoes ja armazenadas
	# em sequencia logo apos receber este HELLO.
	ProfessorHelloPkt.create().send(ProtNetworkHandler.server_peer)
	print("(Professor) HELLO enviado")

func packet_handler(data: PackedByteArray) -> void:
	var packet_type: int = int(data.decode_u8(0))
	match packet_type:
		PacketTypeClass.PACKET_TYPE.PEER_ID:
			my_id = PeerId.create_from_data(data).id
		PacketTypeClass.PACKET_TYPE.MINIGAME_SUBMISSION:
			var pkt: MinigameSubmissionPkt = MinigameSubmissionPkt.create_from_data(data)
			print("(Professor) submission room=", pkt.room_id, " teams=", pkt.teams)
			submission_received.emit(pkt.room_id, pkt.teams)
		# REFRESH e demais ignorados — professor nao lista salas para entrar.
