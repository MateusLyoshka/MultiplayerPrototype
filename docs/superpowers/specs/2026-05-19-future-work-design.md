# Cyber Resistance — Trabalho futuro (transição TCC 1 → TCC 2)

**Data:** 2026-05-19
**Autor:** Mateus Santos Fernandes
**Status:** Design aprovado, pronto para plano de implementação

## 1. Contexto

O protótipo atual já entrega: arquitetura distribuída cliente-servidor para o lobby, comunicação host-jogador via segunda conexão ENet, propagação de movimento/animação, chat global, primeira versão de sincronização de cena, criação/entrada/saída de salas (até 4 jogadores). A documentação técnica do protótipo está em `README.md` (visão arquitetural) e `CLAUDE.md` (guia operacional para futuras sessões de trabalho).

Este documento descreve as cinco frentes restantes para fechar a entrega do TCC 2:

1. Fix de colisão do Player com estruturas do mundo
2. Refresh automático do lobby (5 s) + envio no momento da conexão
3. Informação enriquecida das salas nos cards (contagem + nomes dos jogadores)
4. Conclusão da sincronização de cena (lado reativo: spawn/despawn condicional)
5. Minigame cooperativo 2 vs 2 + persistência dos resultados no servidor central

## 2. Ordem de execução recomendada

Cada item destrava ou facilita o teste do próximo:

1. **Colisão** — fix mínimo, libera testes confortáveis de mundo.
2. **Refresh automático + info de sala** — reformulam o mesmo pacote (`RefreshClass`), faz sentido reescrever uma vez só.
3. **Scene sync (lado reativo)** — pré-requisito para teleportar 4 jogadores juntos para a cena de minigame.
4. **Minigame 2 vs 2** — bloco maior; depende de scene sync.
5. **Persistência de resultados no servidor** — última, conecta o minigame ao servidor central.

## 3. Item 1 — Colisão do Player com estruturas

### 3.1 Diagnóstico

- `prototype/scenes/in_game_reusables/player.tscn` define o `Player` como `CharacterBody2D` sem `collision_mask` explícito → default `1`.
- Os TileMaps dos cenários (`cafeteria.tscn`, `university.tscn`, `world.tscn`) definem `physics_layer_0/collision_layer = 2` e `collision_mask = 5`.
- O bit 2 não está na máscara default do player, por isso ele **atravessa as paredes**.

### 3.2 Implementação

- Abrir `player.tscn` no editor Godot.
- No nó raiz `Player`, alterar `collision_mask` para incluir o bit 2. Valor recomendado: `3` (bits 1 e 2 ativos), por compatibilidade com qualquer outra geometria já em layer 1.
- Nenhuma alteração de script. Nenhuma alteração nas cenas de cenário.

### 3.3 Teste

- Rodar a sessão de jogo localmente.
- Andar contra paredes, mesas e bancadas em `cafeteria.tscn`, `university.tscn`, `world.tscn`. Player deve parar; `move_and_slide()` continua respondendo ao input mas o `velocity` é absorvido pela colisão.
- Validar que portas (`doorArea.tscn`) continuam funcionando — elas são `Area2D` (não respeitam mask de solid body, dependem apenas de `monitoring`).

## 4. Item 2 — Refresh automático do lobby

### 4.1 Comportamento desejado

- Quando um cliente conecta ao servidor central, recebe um `REFRESH` **imediato** (logo após o `PEER_ID`), evitando a tela vazia inicial.
- Enquanto o cliente estiver no lobby (i.e., não dentro de uma sala), recebe um `REFRESH` automático a cada **5 segundos**.
- O botão "Refresh" manual continua funcionando — o disparo automático **não substitui** o manual, é cumulativo. Justificativa: feedback imediato para o usuário ao clicar; tolerância a perda de pacote do timer.

### 4.2 Implementação

#### `ProtNetworkHandler` (`scripts/network_handler.gd`)

- Em `peer_connected(peer)`, após enviar `PeerId.create(...).send(peer)`, sinalizar ao `ServerPacketHandler` para enviar o estado atual de salas para esse peer. Sugestão: emitir um sinal novo `on_new_peer_in_lobby(peer)` que `ServerPacketHandler` escuta, OU chamar diretamente `ServerPacketHandler.send_refresh(peer)` (já existe).

#### `ServerPacketHandler` (`scripts/server_packet_handler.gd`)

- Em `_ready()`, criar um `Timer`:
  ```gdscript
  var refresh_timer: Timer = Timer.new()
  refresh_timer.wait_time = 5.0
  refresh_timer.autostart = true
  refresh_timer.timeout.connect(_on_refresh_tick)
  add_child(refresh_timer)
  ```
- `_on_refresh_tick()` percorre `ProtNetworkHandler.peers_connected.values()`. Para cada peer:
  - **Pula** se `peer.get_meta("in_room", false)` for `true` (jogador dentro de uma sala não precisa ver o lobby).
  - Caso contrário, envia `RefreshClass.create(...)` com o estado atual.

#### Marcação `in_room`

- Em `save_room_info(peer, data)`: `peer.set_meta("in_room", true)` para o host.
- Em `join_request(...)` (caminho de sucesso): `peer.set_meta("in_room", true)` para o joiner.
- Em `quit_room_request(...)`: `peer.set_meta("in_room", false)` para cada peer afetado (host saindo dissolve a sala → todos voltam ao lobby; player saindo limpa só ele).

#### UI

- `multiplayer.gd::_on_refresh_button_down`: **mantém-se inalterado** (manda `RefreshRequestClass`). O servidor já trata `REFRESH_REQUEST` em `send_refresh`.

### 4.3 Teste

- Abrir cliente A. Cliente A entra no lobby → uma sala "fantasma" criada por cliente prévio deve aparecer **sem clicar refresh** dentro de 1 s da conexão.
- Sem nenhuma interação, esperar 5 s; a lista atualiza-se sozinha refletindo salas criadas/encerradas por outros peers.
- Apertar botão manual — atualização imediata (sem esperar o ciclo de 5 s).
- Cliente A entra numa sala → não recebe mais pacotes `REFRESH` (verificável via prints temporários).

## 5. Item 3 — Informação das salas nos cards (count + nomes)

### 5.1 Reformulação do `RefreshClass`

Hoje o pacote carrega só `Array[int]` de room IDs e tem um bug de off-by-one no encode/decode. A reescrita resolve ambos.

**Novo formato binário** (byte 0 é sempre o `packet_type`):

```
[u8] packet_type = REFRESH
[u8] num_rooms                  -- N salas
para cada sala (repetido N vezes):
  [u8]  room_id
  [u8]  num_players              -- 0..4
  para cada jogador (repetido num_players vezes):
    [u8]              name_size  -- bytes UTF-8 do nome
    [name_size bytes] name_utf8
```

Capacidade do pacote: cada sala ocupa `2 + Σ(1 + nome_bytes)`. Com nomes curtos (~10 bytes) e 4 jogadores por sala, cada sala = ~46 bytes. Para o limite de 255 salas (do enum atual `num_room`), o pacote ainda cabe bem abaixo do MTU típico do ENet.

**Refactor de `RefreshClass.encode/decode`**: implementar via `PackedByteArray.append` / leitura sequencial com um offset. O `pop_front()` que existe em `ClientPacketHandler.packet_handler` (caso `REFRESH`) **deve ser removido** — não há mais byte espúrio.

### 5.2 Estrutura no cliente

Em vez de `room_refresh(rooms_id: Array[int])`, o sinal passa a carregar uma estrutura tipada. Sugestão:

```gdscript
class_name RoomSummary
var id: int
var player_count: int
var player_names: Array[String]
```

E o sinal: `room_refresh(summaries: Array[RoomSummary])`.

### 5.3 Capturar nomes no protocolo de entrada

O nome local hoje é `ClientPacketHandler.temporary_player_name = "player_%d" % my_id`. Para o servidor saber os nomes, dois pacotes precisam transportá-lo:

- **`JoinRequestClass`** ganha campo `player_name: String`. Codificação: `[u8 size][name]` no fim do payload, depois dos dois `u8` existentes.
- **`RoomInfoClass`** ganha campo `player_name: String`. Mesma codificação ao fim do payload (depois do IP, ou antes — só fixar a ordem no encode/decode).

Em ambos os pontos do `ServerPacketHandler` (`save_room_info` e `join_request`), além de `add_player_id(...)`, chamar `add_player_name(name)` na `RoomStorage`.

### 5.4 `RoomStorage`

Adicionar:

```gdscript
var current_players_names: Array[String] = []

func add_player_name(name: String) -> void:
    current_players_names.append(name)

func remove_player_name(name: String) -> void:
    current_players_names.erase(name)
```

E nos pontos de quit no `ServerPacketHandler::quit_room_request`, espelhar a remoção.

### 5.5 UI dos cards

`prototype/scenes/menu/room.tscn` (`RoomItem`) ganha:

- Label `PlayerCountLabel`: texto `Players: %d/4`.
- VBoxContainer `PlayerNamesContainer` que recebe um Label por nome.

`RoomItem::setup_room` muda assinatura:

```gdscript
func setup_room(summary: RoomSummary) -> void:
    id = summary.id
    $PlayerCountLabel.text = "Players: %d/4" % summary.player_count
    for child in $PlayerNamesContainer.get_children():
        child.queue_free()
    for name in summary.player_names:
        var lbl: Label = Label.new()
        lbl.text = name
        $PlayerNamesContainer.add_child(lbl)
```

`multiplayer.gd::refresh_rooms` itera sobre `Array[RoomSummary]` em vez de `Array[int]`. `create_join_room` para o caso do criador continua usando só o ID (a sala recém-criada tem 1 jogador, ele mesmo).

### 5.6 Teste

- 1 host cria sala. Outro cliente vê o card com "1/4" e o nome do host.
- 2º jogador entra. O card no cliente que ainda está no lobby passa a mostrar "2/4" e dois nomes dentro de 5 s.
- O jogador sai. Card volta para "1/4". O host sai. Card desaparece.

## 6. Item 4 — Scene sync (lado reativo)

### 6.1 Estado atual

- `GameManager.goto_scene` faz a troca local e broadcasta `SceneSyncPacket` corretamente.
- Host recebe pacote de player → `Player.player_scene_change_packet_handler` salva no dicionário e rebroadcasta.
- Outros clientes recebem `SceneSyncPacket` → `Player.host_scene_change_packet_handler` salva.
- **O que está incompleto:** o estado fica no dicionário `players_scenes: Dictionary[int, String]` de uma instância de `Player` específica — quando essa instância despawna na troca de cena, o estado é perdido. Além disso, ninguém usa o dicionário para decidir spawn/despawn condicional.

### 6.2 Refactor proposto

#### Mover o estado para `ClientPacketHandler`

- Adicionar `var players_scenes: Dictionary[int, String] = {}` em `ClientPacketHandler`.
- Adicionar sinal `player_scene_changed(player_id: int, scene_path: String)` em `ClientPacketHandler`.

#### Mover o handler para `PlayerHostPacketHandler` → `ClientPacketHandler`

Atualmente o `host_change_scene_signal` e `player_change_scene_signal` são consumidos por `Player` (que está prestes a ser destruído na troca de cena, o que torna o ouvinte frágil). O consumidor correto é o singleton `ClientPacketHandler` (ou um novo `SceneSyncManager` autoload, se preferir separação de responsabilidades — a sugestão minimalista é estender `ClientPacketHandler`).

- `PlayerHostPacketHandler` mantém os sinais.
- `ClientPacketHandler._ready()` conecta-se a:
  - `PlayerHostPacketHandler.host_change_scene_signal` → chama `on_scene_sync_received(data)`.
  - `PlayerHostPacketHandler.player_change_scene_signal` → mesma função (no host, replica para si e rebroadcasta).
- `on_scene_sync_received(data)`:
  - Decode → atualiza `players_scenes[peer_id] = scene_path`.
  - Se sou host, rebroadcast do mesmo `SceneSyncPacket` (`broadcast(GamePacketHandler.host_connection)`).
  - Emite `player_scene_changed(peer_id, scene_path)`.

#### Spawn condicional

`scripts/player/spawn_player.gd` (componente `PlayerSpawner` em cada cena):

- Em `_init`/`_ready`, ler a cena atual (`get_tree().current_scene.scene_file_path`).
- `player_spawner(id)` só instancia se:
  - `id == ClientPacketHandler.my_id` (sempre spawnar a si), OU
  - `ClientPacketHandler.players_scenes.get(id, current_scene_path) == current_scene_path` (outro jogador está na mesma cena, ou ainda não registrou cena — herda da minha).
- Ouvir também `ClientPacketHandler.player_scene_changed`:
  - Se um id estava spawnado e mudou para uma cena ≠ a atual, despawnar (`queue_free`).
  - Se um id que ainda não estava spawnado passou a estar na mesma cena, spawnar.

#### Update local antes do roundtrip

Em `GameManager._deferred_goto_scene(path)`, **antes** do `change_scene_to_file`:

```gdscript
ClientPacketHandler.players_scenes[ClientPacketHandler.my_id] = path
```

Isso garante que o `PlayerSpawner` da nova cena, ao instanciar imediatamente, já saiba que o próprio jogador "pertence" à nova cena.

#### Remover lógica equivalente do `Player`

- Remover `var players_scenes`, `player_scene_change_packet_handler`, `host_scene_change_packet_handler` do `player.gd`.
- Remover a conexão a `player_change_scene_signal` / `host_change_scene_signal` em `setup_player()`.

### 6.3 Teste

- 4 instâncias locais. Host na `cafeteria`, players 2-3-4 no `world`. Host **não** deve ver players 2-3-4 (e vice-versa).
- Player 2 entra na cafeteria (por porta). Host vê player 2 aparecer. Players 3 e 4 (ainda no world) deixam de ver player 2.
- Reciprocidade: player 2 vê o host (e os players 3 e 4 não, pois estão em outra cena).

### 6.4 Risco: reentrância

Se um player muda de cena, recebe seu próprio `SceneSyncPacket` rebroadcastado pelo host, e atualiza `players_scenes[my_id]` novamente. Idempotente (mesmo valor), mas vale registrar que `ClientPacketHandler.on_scene_sync_received` deve filtrar `if peer_id == my_id: return` para evitar dupla emissão do sinal.

## 7. Item 5 — Minigame cooperativo 2 vs 2

### 7.1 Conceito

Quatro jogadores em uma sessão. Ao interagirem com um NPC/computador específico na cafeteria, são teleportados juntos para uma cena de minigame. Os 4 são particionados em duas **duplas** (A e B) por ordem de entrada. Dentro de cada dupla:

- **Papel DOC**: vê um documento de referência (texto sobre comandos/conceitos).
- **Papel QUIZ**: vê um questionário com N perguntas; digita respostas.

A comunicação dentro da dupla acontece pelo **chat existente**, com filtragem por time durante o minigame. As duplas competem por velocidade e precisão. Ao fim, todos veem uma tela de resultado; o host envia um relatório ao servidor central, que persiste em CSV. O professor consulta o CSV depois.

### 7.2 Conteúdo do quiz

Arquivo único versionado no projeto: **`prototype/data/minigame_quiz.json`**.

```json
{
  "document_title": "Comandos básicos de Linux",
  "document_text": "ls — lista o conteúdo do diretório atual.\npwd — mostra o caminho do diretório atual.\nchmod 755 <arquivo> — define permissão rwx-rx-rx.\n...",
  "questions": [
    {"prompt": "Qual comando lista o conteúdo do diretório atual?", "answer": "ls"},
    {"prompt": "Qual comando mostra o caminho do diretório atual?", "answer": "pwd"},
    {"prompt": "Qual comando dá permissão 755 a um arquivo?", "answer": "chmod 755"}
  ]
}
```

Carregamento (no host, no `_ready` da cena de minigame):

```gdscript
var f := FileAccess.open("res://prototype/data/minigame_quiz.json", FileAccess.READ)
var raw := f.get_as_text()
var parsed := JSON.parse_string(raw)
```

Validação de resposta:

```gdscript
func normalize(s: String) -> String:
    return s.strip_edges().to_lower()

func is_correct(user_answer: String, expected: String) -> bool:
    return normalize(user_answer) == normalize(expected)
```

Tolerância básica (espaços e caixa). Sem regex / sem fuzzy matching nesta versão.

### 7.3 Cena `minigame_quiz.tscn`

Estrutura sugerida (em `prototype/scenes/in_game_reusables/`):

```
MinigameQuiz (Node2D)
├── Background (ColorRect ou tile)
├── DocumentPanel (Control, visible=false por default)
│   ├── TitleLabel
│   └── DocumentText (RichTextLabel, scroll vertical)
├── QuizPanel (Control, visible=false por default)
│   ├── QuestionLabel
│   ├── AnswerLine (LineEdit)
│   └── SubmitButton
├── TeamHUD (Control, sempre visível)
│   ├── TimerLabel
│   ├── ProgressLabel ("Pergunta X de Y")
│   └── ScoreLabel ("Acertos: a  Erros: e")
├── Chat (instância de chat.tscn, reaproveitada)
└── MinigameSession (Node, sem visual — script controlador)
```

`MinigameSession` é o **controlador da partida** e é o único que existe nesta cena. Ele não é autoload — é criado e destruído com a cena.

### 7.4 Trigger no mundo: NPC interativo

**Novo objeto**: `prototype/scenes/in_game_reusables/minigame_starter.tscn` — um `Area2D` com sprite + Label "[E] Iniciar desafio" + `script` em `minigame_starter.gd`.

`minigame_starter.gd`:

```gdscript
extends Area2D

@onready var prompt: Label = $Prompt
var player_inside: Node = null

func _ready() -> void:
    prompt.visible = false
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player") and body.get("is_authority"):
        player_inside = body
        prompt.visible = true

func _on_body_exited(body: Node) -> void:
    if body == player_inside:
        player_inside = null
        prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
    if player_inside == null: return
    if not event.is_action_pressed("interact"): return
    if not GamePacketHandler.is_host:
        # Apenas o host pode iniciar; mostra dialog ou ignora silenciosamente.
        return
    if ClientPacketHandler.spawned_ids.size() < 4:
        push_warning("Minigame requer 4 jogadores conectados.")
        return
    GameManager.goto_scene("res://prototype/scenes/in_game_reusables/minigame_quiz.tscn")
```

Input action **nova**: `interact` (tecla E) — adicionar em `project.godot[input]` no mesmo formato dos `walk_*`.

Instanciar `minigame_starter.tscn` em `cafeteria.tscn` em um local apropriado (ex.: junto a um computador).

**Restrição importante**: somente o host dispara o `goto_scene`. Justificativa: evita dois jogadores spawnando dois minigames simultâneos por race condition. O prompt visual aparece para qualquer jogador autoritário, mas a ação efetiva só roda no host. UX: mostrar texto "Apenas o host pode iniciar" como tooltip quando um não-host aperta E (versão final), ou só ignorar silenciosamente (versão mínima).

### 7.5 Atribuição de duplas e papéis

Calculado pelo **host** no momento que a cena `minigame_quiz` é carregada:

```gdscript
var ids := ClientPacketHandler.spawned_ids.duplicate()
ids.sort()  # ordem determinística
# Dupla A: ids[0] (DOC), ids[1] (QUIZ)
# Dupla B: ids[2] (DOC), ids[3] (QUIZ)
```

O host envia para cada peer um `MinigameAssignPacket` com:

- `team: u8` (0 = A, 1 = B)
- `role: u8` (0 = DOC, 1 = QUIZ)
- `partner_id: u8`
- `team_member_ids: Array[u8]` (sempre 2 elementos = a própria dupla)

Localmente, o host também aplica a sua atribuição (a si mesmo) imediatamente, sem enviar pacote para si.

Ao receber o `MinigameAssignPacket`, o cliente:
- Esconde/mostra `DocumentPanel` ou `QuizPanel` conforme `role`.
- Inicializa cronômetro local.
- Registra o `team` para uso do chat filtrado.

### 7.6 Chat filtrado por time durante o minigame

`ClientPacketHandler` ganha:

```gdscript
var minigame_team: int = -1            # -1 quando fora do minigame
var minigame_team_members: Array[int] = []
```

Setados ao receber `MinigameAssignPacket`. Resetados ao sair da cena de minigame.

`PlayerHostPacketHandler` ganha:

```gdscript
var team_by_peer: Dictionary[ENetPacketPeer, int] = {}
var is_minigame_active: bool = false
```

Setados no host quando ele envia o `MinigameAssignPacket` (mapeia o `ENetPacketPeer` correspondente ao `team`).

`chat.gd::host_text` (host recebe texto de player) durante minigame ativo: em vez de `broadcast`, iterar as entradas de `team_by_peer` e enviar diretamente (`send`) somente para os peers com o mesmo `team` do remetente. Fora do minigame, `broadcast` normal.

`chat.gd::_on_send_pressed` (host envia texto próprio) durante minigame ativo: mesma lógica — em vez de `packet.broadcast(...)`, iterar `team_by_peer` filtrando pelo time do próprio host (que o host conhece por ter calculado a atribuição). Fora do minigame, `broadcast` normal.

Após o `MINIGAME_RESULT` ser enviado, o host limpa `is_minigame_active = false` e `team_by_peer.clear()`. Cada cliente limpa seu `minigame_team` ao receber o resultado ou ao trocar de cena de volta.

### 7.7 Fluxo da partida

1. Host carrega `minigame_quiz.json`. Cria estado interno em `MinigameSession`:
   - `team_state[A] = { question_idx: 0, correct: 0, wrong: 0, finished: false, elapsed_ms: 0 }`
   - `team_state[B] = { ... mesmo ... }`
   - `total_questions = parsed.questions.size()`
   - `start_time = Time.get_ticks_msec()`
2. Host envia `MinigameAssignPacket` para cada peer.
3. Player com role QUIZ digita resposta e aperta submit → envia `MinigameAnswerPacket(question_idx, answer_string)` ao host.
4. Host valida (`is_correct`), atualiza `team_state[meu_team]`, e envia `MinigameProgressPacket(team, question_idx, was_correct, total_correct, total_wrong)` somente para os peers do mesmo time.
5. Quando `team_state[team].correct + team_state[team].wrong == total_questions`, host registra `finished = true`, calcula `elapsed_ms = now - start_time`, envia `MinigameFinishedPacket(team, elapsed_ms)` (broadcast — ambos os times sabem que o outro acabou; ajuda na UX de espera).
6. Quando ambos os times finalizaram, host monta `MinigameResultPacket` com os resultados completos de ambos os times, broadcasta. Inclui (Layer-1) `MatchReportPacket` ao servidor central.
7. Cliente, ao receber `MinigameResultPacket`, troca para `minigame_results.tscn` (ou mostra overlay Control). Botão "Voltar" → `GameManager.goto_scene("res://prototype/scenes/scenarios/cafeteria.tscn")`.

### 7.8 Novos pacotes Layer-2

Adicionar em `InGameTypeClass.PACKET_TYPE`:

```gdscript
enum PACKET_TYPE {
    PLAYER_PACKET = 0,
    TEXT_PACKET = 10,
    SCENE_SYNC_PACKET = 11,
    MINIGAME_ASSIGN = 20,
    MINIGAME_ANSWER = 21,
    MINIGAME_PROGRESS = 22,
    MINIGAME_FINISHED = 23,
    MINIGAME_RESULT = 24
}
```

Arquivos novos em `prototype/scripts/in_game_packets/`:

| Arquivo | Classe | Payload |
|---|---|---|
| `minigame_assign_packet.gd` | `MinigameAssignPkt` | `team: u8`, `role: u8`, `partner_id: u8`, `member_ids: Array[u8]` (sempre 2) |
| `minigame_answer_packet.gd` | `MinigameAnswerPkt` | `question_idx: u8`, `answer: String` (com prefixo u8 de tamanho) |
| `minigame_progress_packet.gd` | `MinigameProgressPkt` | `team: u8`, `question_idx: u8`, `was_correct: u8`, `total_correct: u8`, `total_wrong: u8` |
| `minigame_finished_packet.gd` | `MinigameFinishedPkt` | `team: u8`, `elapsed_ms: u32` |
| `minigame_result_packet.gd` | `MinigameResultPkt` | Para cada team: `correct: u8`, `wrong: u8`, `elapsed_ms: u32`, lista de respostas digitadas |

Todas seguem o padrão da seção 4 do `CLAUDE.md`: `extends InGameTypeClass`, `static create(...)`, `static create_from_data(data)`, `encode/decode` sobre `PackedByteArray`.

`PlayerHostPacketHandler.player_packet_handler` e `host_packet_handler` ganham casos no `match`:

```gdscript
InGameTypeClass.PACKET_TYPE.MINIGAME_ASSIGN: minigame_assign_signal.emit(data)
InGameTypeClass.PACKET_TYPE.MINIGAME_ANSWER: minigame_answer_signal.emit(peer, data)
# etc.
```

Sinais novos no `PlayerHostPacketHandler` (5 por lado, simétricos):

- `host_minigame_assign_signal`, `host_minigame_progress_signal`, `host_minigame_finished_signal`, `host_minigame_result_signal` (host → player)
- `player_minigame_answer_signal` (player → host)

`MinigameSession` consome os sinais correspondentes ao papel atual (host ou player).

### 7.9 Tela de resultados (`minigame_results.tscn`)

Cena nova com layout simples:

```
- "Resultado final"
- Card Dupla A:
    - "Vencedor"/"Perdedor" badge
    - "Tempo: 2m 47s"
    - "Acertos: 8  Erros: 2"
    - Sub-lista: respostas digitadas
- Card Dupla B: (mesmo formato)
- Botão "Voltar para cafeteria"
```

Critério de vencedor por dupla: maior `correct - wrong`; desempate por menor `elapsed_ms`. Empate total possível e marcado como "Empate".

Conteúdo derivado integralmente do `MinigameResultPkt` recebido → todos os 4 jogadores veem a mesma tela.

### 7.10 Persistência no servidor central

#### Pacote Layer-1: `MatchReportClass`

Adicionar em `PacketTypeClass.PACKET_TYPE`:

```gdscript
MATCH_REPORT = 70
```

Arquivo: `prototype/scripts/menu_packets/match_report_packet.gd`.

Payload (campos serializados sequencialmente; strings com prefixo `u8` de tamanho):

```
[u8]  packet_type = MATCH_REPORT
[u8]  room_id
[u32] start_unix_seconds
[u32] duration_ms
para cada team (2x):
  [u8 + name1]
  [u8 + name2]
  [u8] correct
  [u8] wrong
  [u32] elapsed_ms
```

#### Lado host

No `MinigameSession`, ao receber/computar o `MinigameResultPkt`, montar paralelamente um `MatchReportClass`:

```gdscript
var report := MatchReportClass.create(
    ClientPacketHandler.current_room_id,
    Time.get_unix_time_from_system(),
    duration_ms,
    [team_a_state, team_b_state]
)
report.send(ProtNetworkHandler.server_peer)
```

#### Lado servidor

`ServerPacketHandler.client_packet_handler` ganha:

```gdscript
PacketTypeClass.PACKET_TYPE.MATCH_REPORT:
    save_match_report(peer, data)
```

`save_match_report`:

```gdscript
var report := MatchReportClass.create_from_data(data)
var path := "user://match_reports.csv"
var file := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
if not FileAccess.file_exists(path):
    file.store_line("timestamp,room_id,team,player1,player2,correct,wrong,elapsed_ms")
file.seek_end()
for team in report.teams:
    file.store_line("%d,%d,%s,%s,%s,%d,%d,%d" % [
        report.start_unix_seconds, report.room_id, team.label,
        team.player1, team.player2, team.correct, team.wrong, team.elapsed_ms
    ])
file.close()
```

O arquivo `user://match_reports.csv` resolve para `%APPDATA%/Godot/app_userdata/LowLevel/match_reports.csv` no Windows quando o servidor está rodando. Documentar isso no README para o professor.

### 7.11 Teste do minigame

1. 4 instâncias locais (uma com `--server`, três como cliente — para teste interno, é possível ligar 4 clientes ao servidor com IPs/portas distintos ou usar `Run multiple instances` no editor Godot).
2. Os 4 entram numa mesma sala.
3. Todos vão para a cafeteria.
4. Um dos jogadores caminha até o NPC `minigame_starter` (visualizar prompt "[E] Iniciar desafio").
5. Apertar E como **não-host** → nada deve acontecer.
6. Apertar E como **host** → todos teleportam para `minigame_quiz`.
7. Os 4 veem painéis corretos: id0 e id2 → DOC; id1 e id3 → QUIZ.
8. Player do QUIZ digita resposta correta → ProgressLabel atualiza só na própria dupla.
9. Player do QUIZ da outra dupla **não** vê mensagens do chat da primeira dupla.
10. Ambas as duplas terminam → tela de resultados aparece para todos.
11. Verificar `user://match_reports.csv` no servidor: linha nova com timestamps e contagens corretas.

## 8. Riscos e mitigação

| Risco | Mitigação |
|---|---|
| Reescrever `RefreshClass` e quebrar a UI temporariamente | Fazer num único commit incluindo `RefreshClass`, `ClientPacketHandler.packet_handler` (remoção do `pop_front`), `multiplayer.gd::refresh_rooms`, `RoomItem.setup_room` |
| `JoinRequestClass` / `RoomInfoClass` quebram compatibilidade com versões antigas | Não há outras versões em produção; toda a base é atualizada num único commit |
| Scene sync com 4 players em cenas diferentes pode produzir spawn/despawn intermitente | `SceneSyncPacket` já usa `FLAG_RELIABLE`; o spawner deve checar `spawned_ids` antes de instanciar (idempotência) |
| Filtro de chat por team vazando para fora do minigame | Resetar `is_minigame_active`, `team_by_peer`, `minigame_team` em pontos bem definidos: ao broadcast do `MINIGAME_RESULT` no host, ao recebê-lo no cliente, e ao trocar de cena de volta |
| `MinigameStarter` disparado por dois hosts simultaneamente (race) | Inviável por design — só há um host por sala. Não há risco real |
| `JSON.parse_string` retorna `null` em arquivo malformado | Falhar visivelmente: `push_error` no host e abortar o `goto_scene` |
| IP retornado por `get_ipv4()` pode ser de um adapter VirtualBox | Risco já existente do projeto; fora de escopo deste documento |
| Caminho `user://` no servidor não ser óbvio para o professor | Documentar o caminho exato no `README.md` na entrega final |

## 9. Plano de teste resumido

| Item | Teste manual mínimo |
|---|---|
| Colisão | Andar contra parede em cafeteria, university, world — player não atravessa |
| Refresh auto | Cliente conecta ao servidor e vê salas existentes sem clicar; lista atualiza-se sozinha em ≤5 s |
| Refresh manual | Botão continua funcionando (atualização imediata, paralelo ao automático) |
| Info de sala | Card mostra "X/4" e os nomes; entradas e saídas refletem dentro de 5 s |
| Scene sync | Players visíveis apenas para quem está na mesma cena; teleporte coerente |
| Minigame (host) | Trigger no NPC funciona apenas para host e somente com 4 conectados |
| Minigame (papéis) | DOC e QUIZ corretos para cada player; ordem determinística (sort de ids) |
| Minigame (chat) | Mensagens só chegam ao parceiro durante o minigame |
| Minigame (progresso) | ProgressLabel só atualiza dentro do próprio time |
| Minigame (resultado) | Tela aparece para todos com mesmos dados; vencedor calculado corretamente |
| Persistência | `user://match_reports.csv` no servidor recebe nova linha por team após cada partida |

## 10. Critério de "pronto" do TCC 2

- Os 5 itens deste documento implementados e testados manualmente.
- Pelo menos uma rodada completa de minigame com 4 jogadores reais (ou 4 instâncias locais) registrada em CSV.
- `README.md` atualizado com os novos pacotes (Layer-1: `MATCH_REPORT`; Layer-2: `MINIGAME_*`) e o caminho do CSV de relatório.
- `CLAUDE.md` atualizado se algum padrão arquitetural mudou (ex.: novo autoload, novo grupo de cena).

---

**Próximo passo:** este documento alimenta o plano de implementação detalhado (skill `writing-plans`), que quebrará cada item em commits/PRs verificáveis.
