extends RefCounted
class_name DialogueDataRegistry


const DIALOGUES := {
	"spawn_goddess_intro": {
		"dialogue_id": "spawn_goddess_intro",
		"start_node_id": "awakening",
		"nodes": {
			"awakening": {
				"speaker_name": "复活女神",
				"base_text": "睁开眼吧，迷途者。你的旧人生已经停在死亡的那一刻，而我把你从断裂的终点重新拽了回来。这里不是安稳的庇护所，而是你被允许再次站起来的起点。",
				"conditional_text_segments": [
					{
						"requires_trigger": "bg_student",
						"fragments": [
							{"text": "你上一世是"},
							{"text": "学生", "highlight": true, "trigger_id": "bg_student"},
							{"text": "。你还保留着追问、记忆与拼命理解世界规则的惯性。"},
						],
					},
					{
						"requires_trigger": "bg_worker",
						"fragments": [
							{"text": "你上一世是"},
							{"text": "打工人", "highlight": true, "trigger_id": "bg_worker"},
							{"text": "。你已经习惯把疲惫咽下去，再把流程硬撑到结束。"},
						],
					},
					{
						"requires_trigger": "bg_esports",
						"fragments": [
							{"text": "你上一世是"},
							{"text": "电竞选手", "highlight": true, "trigger_id": "bg_esports"},
							{"text": "。你对节奏断点、瞬时判断和局势翻面的气味还没有忘。"},
						],
					},
					{
						"requires_trigger": "bg_courier",
						"fragments": [
							{"text": "你上一世是"},
							{"text": "外卖员", "highlight": true, "trigger_id": "bg_courier"},
							{"text": "。你最先记住的不是墙，而是路、拐角和还能不能赶上下一秒。"},
						],
					},
					{
						"requires_trigger": "bg_idle",
						"fragments": [
							{"text": "你上一世是"},
							{"text": "无业游民", "highlight": true, "trigger_id": "bg_idle"},
							{"text": "。你活在边角里太久了，所以更懂缝隙、机会和不体面的活法。"},
						],
					},
					{
						"requires_trigger": "trait_eager_learner",
						"fragments": [{"text": "你身上还有"}, {"text": "求知欲", "highlight": true, "trigger_id": "trait_eager_learner"}, {"text": "，这会让你在陌生世界里更快抓住方法。"}],
					},
					{
						"requires_trigger": "trait_exam_memory",
						"fragments": [{"text": "你的"}, {"text": "应试记忆", "highlight": true, "trigger_id": "trait_exam_memory"}, {"text": "没有散掉，短时间里的信息提取仍会帮到你。"}],
					},
					{
						"requires_trigger": "trait_pressure_inertia",
						"fragments": [{"text": "那份"}, {"text": "抗压惯性", "highlight": true, "trigger_id": "trait_pressure_inertia"}, {"text": "还在，你不会因为第一轮压力就立刻失去动作。"}],
					},
					{
						"requires_trigger": "trait_process_familiarity",
						"fragments": [{"text": "你的"}, {"text": "流程熟练", "highlight": true, "trigger_id": "trait_process_familiarity"}, {"text": "会让你更快看懂这场试炼要你做什么。"}],
					},
					{
						"requires_trigger": "trait_rapid_response",
						"fragments": [{"text": "你的"}, {"text": "高速反应", "highlight": true, "trigger_id": "trait_rapid_response"}, {"text": "会在第一次交锋时替你抢下一瞬。"}],
					},
					{
						"requires_trigger": "trait_momentum_read",
						"fragments": [{"text": "你的"}, {"text": "局势判断", "highlight": true, "trigger_id": "trait_momentum_read"}, {"text": "会让你更早察觉战局什么时候开始倾斜。"}],
					},
					{
						"requires_trigger": "trait_route_instinct",
						"fragments": [{"text": "你的"}, {"text": "路线直觉", "highlight": true, "trigger_id": "trait_route_instinct"}, {"text": "会把路径、掩体和退路先一步送到你眼前。"}],
					},
					{
						"requires_trigger": "trait_race_against_time",
						"fragments": [{"text": "那份"}, {"text": "争分夺秒", "highlight": true, "trigger_id": "trait_race_against_time"}, {"text": "的本能还在，你会更习惯在倒数感里行动。"}],
					},
					{
						"requires_trigger": "trait_idle_observer",
						"fragments": [{"text": "你的"}, {"text": "闲散观察", "highlight": true, "trigger_id": "trait_idle_observer"}, {"text": "会让你注意到别人懒得看的异常。"}],
					},
					{
						"requires_trigger": "trait_low_cost_survival",
						"fragments": [{"text": "你的"}, {"text": "低成本生存", "highlight": true, "trigger_id": "trait_low_cost_survival"}, {"text": "会让你在窘迫时依然保住基本状态。"}],
					},
					{
						"requires_trigger": "trait_observant",
						"fragments": [{"text": "你的"}, {"text": "观察入微", "highlight": true, "trigger_id": "trait_observant"}, {"text": "会帮你更快发现房间里的细节和威胁。"}],
					},
					{
						"requires_trigger": "trait_steady_breathing",
						"fragments": [{"text": "你的"}, {"text": "呼吸平稳", "highlight": true, "trigger_id": "trait_steady_breathing"}, {"text": "会帮你在慌乱出现时重新抓住节奏。"}],
					},
					{
						"requires_trigger": "trait_nimble_steps",
						"fragments": [{"text": "你的"}, {"text": "步伐轻快", "highlight": true, "trigger_id": "trait_nimble_steps"}, {"text": "会让你在试炼里更快调整站位和距离。"}],
					},
				],
				"options": [
					{
						"id": "ask_about_trials",
						"text": "告诉我接下来要面对什么。",
						"actions": [{"type": "goto_node", "node_id": "trial_briefing"}],
					},
					{
						"id": "accept_resurrection",
						"text": "我准备好了，让试炼开始吧。",
						"actions": [
							{"type": "grant_trigger", "trigger_id": "finished_goddess_intro_dialogue"},
							{"type": "grant_trigger", "trigger_id": "finished_intro_villager_dialogue"},
							{"type": "set_event_flag", "flag_id": "intro_room_overview_seen", "value": true},
							{"type": "end_dialogue", "reason": "goddess_intro_complete"},
						],
					},
				],
			},
			"trial_briefing": {
				"speaker_name": "复活女神",
				"base_text": "走出这间复苏之室后，你只会面对三段试炼。第一间房里只有一名近战小兵；第二间房里是一名近战与一名远程；第三间房里，守着通路尽头的 Boss 会亲自确认你是否配得上第二次生命。",
				"options": [
					{
						"id": "begin_trial",
						"text": "明白了，我会一间一间打过去。",
						"actions": [
							{"type": "grant_trigger", "trigger_id": "finished_goddess_intro_dialogue"},
							{"type": "grant_trigger", "trigger_id": "finished_intro_villager_dialogue"},
							{"type": "set_event_flag", "flag_id": "intro_room_overview_seen", "value": true},
							{"type": "end_dialogue", "reason": "goddess_trial_briefing_complete"},
						],
					},
				],
			},
		},
	},
	"tutorial_boss_clear_goddess": {
		"dialogue_id": "tutorial_boss_clear_goddess",
		"start_node_id": "tutorial_clear",
		"nodes": {
			"tutorial_clear": {
				"speaker_name": "复活女神",
				"base_text": "做得不错。你已经穿过了这场一次性的启程试炼，也证明了自己能在新世界里继续活下去。这里的战斗到此为止，真正漫长的选择，现在才要开始。",
				"conditional_text_segments": [
					{
						"conditions": [{"type": "event_flag_is", "flag_id": "tutorial_completed", "value": true}],
						"fragments": [
							{"text": "接下来，我会把你送往"},
							{"text": "主神空间", "highlight": true},
							{"text": "。那里会成为你之后往返诸界的中枢。"},
						],
					},
				],
				"options": [
					{
						"id": "enter_god_space",
						"text": "带我去主神空间。",
						"actions": [
							{"type": "call_hook", "hook_id": "transition_to_god_space"},
						],
					},
				],
			},
		},
	},
	"god_space_goddess_intro": {
		"dialogue_id": "god_space_goddess_intro",
		"start_node_id": "hub_intro",
		"nodes": {
			"hub_intro": {
				"speaker_name": "复活女神",
				"base_text": "这里就是主神空间。你以后每完成一段旅程，都会回到这里整理状态、确认方向，然后再次迈向新的世界。",
				"conditional_text_segments": [
					{
						"conditions": [{"type": "event_flag_is", "flag_id": "seen_god_space_intro", "value": false}],
						"fragments": [
							{"text": "你眼前的正式入口目前通往四条不同路线："},
							{"text": "修仙世界", "highlight": true},
							{"text": "、"},
							{"text": "异能世界", "highlight": true},
							{"text": "、"},
							{"text": "未来世界", "highlight": true},
							{"text": "，以及"},
							{"text": "古代世界", "highlight": true},
							{"text": "。先从你已经能踏入的那一条开始吧。"},
						],
					},
					{
						"conditions": [{"type": "event_flag_is", "flag_id": "seen_god_space_intro", "value": true}],
						"fragments": [
							{"text": "世界出口还在那里。准备好之后，就去挑选下一段旅程。"},
						],
					},
				],
				"options": [
					{
						"id": "acknowledge_hub",
						"text": "我明白了，会从这里选择下一条路。",
						"conditions": [{"type": "event_flag_is", "flag_id": "seen_god_space_intro", "value": false}],
						"actions": [
							{"type": "set_event_flag", "flag_id": "seen_god_space_intro", "value": true},
							{"type": "end_dialogue", "reason": "god_space_intro_complete"},
						],
					},
					{
						"id": "leave_hub_guidance",
						"text": "我先去看看世界入口。",
						"conditions": [{"type": "event_flag_is", "flag_id": "seen_god_space_intro", "value": true}],
						"actions": [
							{"type": "end_dialogue", "reason": "god_space_intro_repeat_complete"},
						],
					},
				],
			},
		},
	},
}


static func get_dialogue(dialogue_id: String) -> Dictionary:
	if not DIALOGUES.has(dialogue_id):
		return {}
	return (DIALOGUES[dialogue_id] as Dictionary).duplicate(true)
