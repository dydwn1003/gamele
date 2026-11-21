extends Node
## 상호작용 관리: "interactable" 그룹 중 플레이어와 가장 가까운 대상을 골라
## 화면에 안내 문구를 띄우고, '확인' 버튼을 누르면 그 대상의 interact() 를 호출한다.
## 대상 노드는 interact_text() -> String, interact() , interact_radius 를 가진다.

var player
var current: Node = null


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var best: Node = null
	var best_d := 1e9
	if not player.dead:
		var list: Array = get_tree().get_nodes_in_group("interactable")
		for n in list:
			var r: float = n.interact_radius
			var d: float = n.global_position.distance_to(player.global_position)
			if d < r and d < best_d and n.interact_text() != "":
				best_d = d
				best = n
	current = best
	Controls.interact_hint = best.interact_text() if best else ""
	if best and Controls.consume("interact"):
		best.interact()
