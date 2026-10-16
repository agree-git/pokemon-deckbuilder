extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    var descriptors: Array[Dictionary] = []
    var catalog := VisualCatalog.new()
    descriptors.assign(catalog.biomes)
    for group: String in ["elite","champions"]:
        for room: Dictionary in BattleBackdrops.data()[group].values(): descriptors.append(room)
    descriptors.append(BattleBackdrops.data()["fallback_champion"])
    check(descriptors.size() == 48,"Every active and reserve background is covered")
    var fractional := {"ally":[201.6,297.6],"enemy":[598.6,246.1]}
    check(BattlefieldLayout.frame(fractional,Vector2(1920,1080),Vector2(768,1024.0/3)).position.y == -179,"297.6 JSON coordinate must not lose a camera pixel through Vector2 precision")
    fractional["ally"][1] = 287.2
    check(BattlefieldLayout.frame(fractional,Vector2(1920,1080),Vector2(768,1024.0/3)).position.y == -153,"287.2 JSON coordinate uses the same camera floor as the HTML editor")
    var battle := TacticalBattle.new(2026)
    var before := battle.snapshot()
    var ui := TacticalUI.new()
    ui.battle = battle
    root.add_child(ui)
    await process_frame
    var canvas := ui.stage.canvas
    for descriptor: Dictionary in descriptors:
        canvas.set_backdrop(descriptor)
        var profile := canvas.battlefield_layout
        check(not profile.is_empty(),"Measured floor exists for "+str(descriptor))
        var texture_size := canvas.background.get_size()
        var frame := BattlefieldLayout.frame(profile,Vector2(1920,1080),texture_size)
        for ally: bool in [true,false]:
            var p := BattlefieldLayout.point(profile,ally)
            check(Rect2(Vector2.ZERO,texture_size).has_point(p),"Floor coordinate stays inside the correct atlas cell")
            var projected := frame.position+p*(frame.size.x/texture_size.x)
            check(canvas.foot_anchor(ally).distance_to(projected) < 0.01,"Sprite and background use exactly the same projection")
        check(canvas.foot_anchor(true).y > canvas.foot_anchor(false).y+40,"Every room preserves the lower ally/upper enemy diagonal")
        check(absf(canvas.foot_anchor(true).y-565) <= 1,"Camera leaves room for the hand and HP HUD")
        for id: int in [1,3,6,9,93,130,143,201,249,321,386]:
            canvas.set_species(id,id,catalog)
            canvas._process(0)
            ui._position_combat_hud()
            ui._position_intent()
            check(not ui.get_node("Intent").get_rect().intersects(canvas.sprite_rect(false)),"Intent clears the Pokemon in each room")
            for ally: bool in [true,false]:
                var sprite := canvas.source_sprite if ally else canvas.target_sprite
                var bounds := canvas.sprite_bounds(sprite.texture)
                var offset := Vector2(bounds.position.x+bounds.size.x/2.0,bounds.end.y)-sprite.texture.get_size()/2
                check((sprite.position+offset*canvas.zoom_for(ally)).distance_to(canvas.foot_anchor(ally)) <= 0.71,"Actual opaque feet meet the calibrated ground")
                var roster := ui.ally_roster if ally else ui.enemy_roster
                check(not roster.get_rect().intersects(canvas.sprite_rect(ally)),"Large sprites clear the party roster")
                check(canvas.sprite_rect(ally).position.y >= 132,"Sprite stays below the top HUD")
                var label := ui.ally_label if ally else ui.enemy_label
                check(label.position.y >= canvas.foot_anchor(ally).y+24,"HP follows the floor below the sprite")
                check(label.position.y+165 < 786,"Shield/status rows stay above the hand")
        # Rendering and an in-flight scale must not move the camera or foot target.
        var foot := canvas.foot_anchor(false)
        canvas.target_factor = 0.2
        canvas._process(0)
        var bounds := canvas.sprite_bounds(canvas.target_sprite.texture)
        var offset := Vector2(bounds.position.x+bounds.size.x/2.0,bounds.end.y)-canvas.target_sprite.texture.get_size()/2
        check((canvas.target_sprite.position+offset*canvas.target_sprite.scale.x).distance_to(foot) <= 0.71,"Release/recall scaling remains grounded")
        check(BattlefieldLayout.frame(profile,Vector2(1920,1080),texture_size) == frame,"Animation cannot move the background")
        canvas.target_factor = 1
        for size: Vector2 in [Vector2(1280,720),Vector2(2560,1440)]:
            canvas.canvas_size = size
            canvas.layout_battlefield()
            var expected := BattlefieldLayout.project(profile,false,size,texture_size)
            check((canvas.target_anchor+Vector2(0,88)).distance_to(expected) < 0.01,"Resize updates the effect/body anchor with the same projection")
        canvas.canvas_size = Vector2(1920,1080)
        canvas.layout_battlefield()
    check(battle.snapshot() == before,"Floor/HUD queries and species previews never change battle state or RNG")
    var profile := BattlefieldLayout.for_backdrop(descriptors[0])
    profile["ally"][0] = -99
    check(BattlefieldLayout.for_backdrop(descriptors[0])["ally"][0] >= 0,"Layout callers cannot mutate shared calibration data")
    ui.free()
    print("BATTLEFIELD_LAYOUT ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
