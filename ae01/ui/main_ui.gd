extends Control

func _ready() -> void:
	# Wire the ScenarioPlayer to the ControlPanel and give ControlPanel
	# a reference to the AffectEngine (accessed through the Agent node).
	var scenario_player: Node = get_node_or_null("ScenarioPlayer")
	var control_panel = get_node_or_null("HSplit/RightPanel/RightContent/ControlPanel")
	var agent = get_node_or_null(
		"HSplit/SimPanel/SimViewportContainer/SimViewport/GridWorld/Agent"
	)

	if control_panel and scenario_player:
		control_panel.set_scenario_player(scenario_player)

	if control_panel and agent:
		control_panel.affect_engine_ref = agent._engine
