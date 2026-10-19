class_name TutorialUI
extends Control
## Guided real actions on disposable battle/camp states, with no profile/run writes.
const W = preload("res://scripts/ui/combat_widgets.gd")
const LESSONS := [
    ["부담 없이 조작부터 익혀요","실제 카드와 버튼을 눌러 배우는 연습입니다.\n전투 → 포획 → 야영 순서로 진행합니다.\n진행 중인 원정·도감·골드는 바뀌지 않습니다.","연습 시작"],
    ["상대의 다음 행동을 먼저 봐요","상대 위의 표시는 다음에 사용할 행동입니다.\n공격이라면 예상 피해를 확인하세요.\n내가 턴을 끝낼 때 마지막 출전 동료가 맞습니다.","카드 써 보기"],
    ["기술 카드 한 장을 사용해요","아래 ‘불꽃세례’에 마우스를 올려 예상 결과를 보고\n카드를 눌러 보세요. 왼쪽 위 숫자가 에너지 비용입니다.\n사용 후 왼쪽 아래 에너지가 줄어듭니다.",""],
    ["다른 동료의 기술로 자동 교대해요","이번에는 꼬부기의 ‘물대포’를 눌러 보세요.\n꼬부기로 교대하며 기술을 사용합니다.\n카드 비용 외에 추가 교대 비용은 없습니다.",""],
    ["마지막 동료에게 보호막을 줘요","‘방어 지시’를 눌러 출전 중인 꼬부기를 보호하세요.\n이 카드는 현재 출전 동료에게 보호막을 줍니다.\n보호막이 있으면 HP보다 먼저 소모됩니다.",""],
    ["턴을 끝내 상대 행동을 확인해요","오른쪽 아래 ‘턴 종료’를 누르세요.\n상대가 행동한 뒤 새 손패와 에너지를 받습니다.\n기본 에너지 3·손패 5장, 더 빠르면 에너지 +1.\n쓰지 않은 카드는 보존 효과가 없으면 버려집니다.",""],
    ["이제 야생 포켓몬을 잡아 봐요","일반 야생은 HP 25% 이하·에너지 1·몬스터볼 1개가 필요합니다.\n연습용으로 체력을 낮춘 이브이를 준비합니다.\n관장·트레이너의 포켓몬은 포획할 수 없습니다.","포획 연습 시작"],
    ["몬스터볼 버튼을 눌러요","‘포획’ 버튼을 누르세요. 단축키는 C입니다.\n포획하면 전투가 끝나고 합류·교체를 선택합니다.\n본편에서는 포획한 계통의 스타팅도 해금됩니다.",""],
    ["야영지에서 회복을 준비해요","회복이 필요한 동료들로 연습합니다. ‘휴식하기’를 누르세요.\n새 원정 회복은 첫 지역 40% → 35% → 30%입니다. 기절도 회복합니다.",""],
    ["휴식과 강화 중 하나를 골라요","휴식은 끝났습니다. 같은 야영지에서 강화도 할 수는 없습니다.\n다음 연습은 건강한 상태입니다. 회복 대신 카드 강화를 준비해 봅시다.","강화 연습으로"],
    ["카드 강화를 직접 선택해요","‘카드 강화 선택’ → 카드 한 장 → ‘이 카드 강화’를 누르세요.\n비용·효과를 비교한 뒤 확정합니다. 강화는 이 원정 동안 유지되며 야영 행동을 사용합니다.",""],
]
var step := 0
var practice: TacticalJourney
var battle_view: TacticalUI
var camp_view: TacticalJourneyUI
var stage_view: Control
var coach: Control
var frame: Panel
var next_button: Button
var exit_button: Button
var body_label: Label
var _finishing := false
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    restart_lesson()
func _clear_stage() -> void:
    if is_instance_valid(stage_view):
        remove_child(stage_view)
        stage_view.queue_free()
    battle_view=null;camp_view=null
func _battle(capture := false) -> void:
    _clear_stage()
    practice=TutorialLesson.battle_practice(capture)
    battle_view=load("res://scripts/ui/tutorial_battle_view.gd").new()
    battle_view.set("teacher",self)
    battle_view.battle=practice.battle
    battle_view.run_mode=true
    battle_view.run_journey=practice
    battle_view.run_title="튜토리얼 · 연습 전용 · 원정에 반영되지 않습니다"
    battle_view.run_biome=practice.biome()
    battle_view.capture_action=func():return {"reason":practice.capture(),"notice":"연습 포획 성공! 도감에는 기록하지 않습니다."}
    battle_view.capture_status=func():return {"wild":true,"balls":practice.balls,"reason":practice.capture_reason(),"help":practice.capture_help()}
    stage_view=battle_view
    add_child(stage_view)
    theme=battle_view.theme
    _build_coach()
func _camp(upgrade := false) -> void:
    _clear_stage()
    practice=TutorialLesson.camp_practice(upgrade)
    camp_view=load("res://scripts/ui/tutorial_camp_view.gd").new()
    camp_view.set("teacher",self);camp_view.journey=practice
    stage_view=camp_view;add_child(stage_view)
    theme=camp_view.theme
    _build_coach()
func restart_lesson() -> void:
    step=0;_finishing=false
    _battle()
func permits(action:String,uid:=0) -> bool:
    if is_instance_valid(battle_view) and (battle_view.busy or battle_view._overlay_open()):return false
    match action:
        "card":return (step==2 and uid==TutorialLesson.FIRST_CARD) or (step==3 and uid==TutorialLesson.SWITCH_CARD) or (step==4 and uid==TutorialLesson.GUARD_CARD)
        "end":return step==5
        "capture":return step==7
        "rest":return step==8
        "upgrade":return step==10
    return false
func _build_coach() -> void:
    if is_instance_valid(coach) and coach.is_inside_tree():
        remove_child(coach);coach.queue_free()
    if is_instance_valid(frame) and frame.is_inside_tree():
        remove_child(frame);frame.queue_free()
    coach=Control.new();coach.name="TutorialCoach";coach.z_index=210
    coach.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    coach.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(coach)
    var camp:=step>=8
    var rect:=Rect2(550,78,1190,174) if camp else Rect2(552,144,524,278)
    var panel:=W.panel(coach,rect,Color("14282f"),W.GOLD,12)
    panel.mouse_filter=Control.MOUSE_FILTER_STOP
    W.label(panel,"조작 연습 · %d / %d"%[step+1,LESSONS.size()],Rect2(22,10,400,28),15,W.MUTED)
    W.label(panel,LESSONS[step][0],Rect2(22,42,rect.size.x-44,38),23,W.GOLD)
    body_label=W.label(panel,LESSONS[step][1],Rect2(22,83,rect.size.x-44,80 if camp else 112),17,W.TEXT)
    body_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    next_button=null
    if not str(LESSONS[step][2]).is_empty():
        next_button=W.button(panel,Rect2(rect.size.x-226,rect.size.y-57,204,42),advance,LESSONS[step][2])
        next_button.name="TutorialNext"
        if camp:body_label.size.x-=230
    exit_button=W.button(coach,Rect2(1460,14,180,44),leave.bind(false),"연습 나가기")
    exit_button.name="TutorialExit"
    frame=Panel.new();frame.z_index=205;frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var style:=W.box(Color.TRANSPARENT,W.GOLD,10);style.set_border_width_all(3)
    frame.add_theme_stylebox_override("panel",style);add_child(frame)
func advance() -> void:
    if step not in [0,1,6,9]:return
    step+=1
    if step==7:_battle(true)
    elif step==10:_camp(true)
    else:_build_coach()
func _process(_delta:float) -> void:
    if _finishing:return
    if is_instance_valid(battle_view):
        var covered:=battle_view._overlay_open() or is_instance_valid(get_node("/root/Preferences").panel)
        coach.visible=not covered
        frame.visible=not covered and not battle_view.busy
        if battle_view.busy:return
        var b:=practice.battle
        if (step in [2,3,4] and not b.hand.any(func(c:BattleCardInstance):return c.uid==[TutorialLesson.FIRST_CARD,TutorialLesson.SWITCH_CARD,TutorialLesson.GUARD_CARD][step-2])) or (step==5 and b.turn>1):
            step+=1;_build_coach()
        elif step==7 and b.phase==TacticalBattle.WON:
            step=8;_camp();return
    elif is_instance_valid(camp_view):
        coach.visible=not camp_view.deck_open and camp_view.upgrade_preview_uid==0 and not is_instance_valid(get_node("/root/Preferences").panel)
        frame.visible=coach.visible
        if step in [8,10] and practice.step in practice.rested_steps:
            if step==10:_complete();return
            step=9;_build_coach()
    _highlight()
func _highlight() -> void:
    var target:Control
    if is_instance_valid(battle_view):
        match step:
            1:target=battle_view.intent_label
            2,3,4:target=battle_view.trainer_buttons.get([TutorialLesson.FIRST_CARD,TutorialLesson.SWITCH_CARD,TutorialLesson.GUARD_CARD][step-2])
            5:target=battle_view.end_button
            7:target=battle_view.capture_button
    elif is_instance_valid(camp_view):
        if step==8:target=camp_view.rest_button
        elif step==10:target=camp_view.page.find_child("Upgrade",true,false)
    if not is_instance_valid(target) or not target.is_visible_in_tree():frame.hide();return
    var rect:=target.get_global_rect().grow(5)
    frame.position=rect.position;frame.size=rect.size
func _complete() -> void:
    _finishing=true
    get_node("/root/Preferences").set_tutorial_status("completed")
    _clear_stage();coach.hide();frame.hide()
    stage_view=Control.new();stage_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(stage_view)
    W.panel(stage_view,Rect2(0,0,1920,1080),Color("09191f"),Color.TRANSPARENT,0)
    W.sprite(stage_view,4,Rect2(420,120,160,160));W.sprite(stage_view,7,Rect2(880,120,160,160));W.sprite(stage_view,1,Rect2(1340,120,160,160))
    W.label(stage_view,"연습 완료! 이제 원정을 준비해요",Rect2(180,300,1560,70),42,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    var hints:=[
        ["전투에서","상대 예고 → 카드 비용·예상 결과 → 마지막 출전 동료를 확인하세요.\n직접 교대는 에너지가 들지만 다른 동료의 기술은 추가 교대 비용이 없습니다."],
        ["야영지에서","휴식·강화·희귀 단서 조사는 한 곳에서 하나만 선택합니다.\n가방에서는 회복약을, 장비·유물에서는 지닌 물건을 준비하세요.\n기술머신·포켓몬 연구도 이용할 수 있습니다. 회복약은 야영지 전용입니다."],
        ["원정의 목표","배지 8개 → 사천왕 4명 → 챔피언을 이기세요. 새 원정은 도전 난도입니다.\nF1 전투 도움말 · Esc 메뉴 · Q/W/E/R 카드 · 1/2/3 직접 교대 · Enter 턴 종료 · C 포획"],
    ]
    for i in hints.size():
        var row:=W.panel(stage_view,Rect2(270,400+i*137,1380,120),Color("14282f"),Color("344b51"))
        W.label(row,hints[i][0],Rect2(24,12,180,92),23,W.GOLD)
        W.label(row,hints[i][1],Rect2(220,12,1130,92),20,W.TEXT)
    W.label(stage_view,"이 연습의 포획·카드 강화는 본 원정에 적용되지 않습니다. 시작 화면에서 언제든 다시 연습할 수 있습니다.",Rect2(200,825,1520,44),18,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    W.button(stage_view,Rect2(480,910,420,70),leave.bind(false),"시작 화면으로").name="TutorialHome"
    W.button(stage_view,Rect2(1020,910,420,70),leave.bind(true),"스타팅 선택으로").name="TutorialStartJourney"
func leave(choose_starters:bool) -> void:
    if choose_starters:get_node("/root/BattleSession").open_starter_selection=true
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
