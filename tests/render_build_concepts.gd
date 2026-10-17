extends "res://tests/test_build_concepts_ui.gd"
## Render-only companion to the pointer probe, using the same real card faces.
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-concepts")
    root.mode = Window.MODE_FULLSCREEN
    root.size = Vector2i(1920,1080)
    for concept: String in BuildConceptContent.GROUPS: await gallery(concept)
    print("CONCEPT_GALLERY: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
