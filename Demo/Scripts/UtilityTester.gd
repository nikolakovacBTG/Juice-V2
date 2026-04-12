extends Node

func on_method_called() -> void:
	print("[UtilityTester] Method successfully called by CallMethodJuiceUtility!")

func on_signal_relayed(msg: String = "No message") -> void:
	print("[UtilityTester] Signal relayed successfully. Message: ", msg)
