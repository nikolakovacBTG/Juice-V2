extends MainLoop

func _process(delta: float) -> bool:
    print("Testing...")
    var scene = load("res://demo/Scenes/Main_Demo_Scene.tscn").instantiate()
    print("Scene loaded: ", scene.name)
    return true

