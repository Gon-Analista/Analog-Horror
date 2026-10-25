extends Node
## Dev check for the EOS setup: login, host a lobby, print its code, leave.
##   godot --headless --path game res://scenes/dev/eos_check.tscn
## Prints "EOS_CHECK ok code=XXXXX" or "EOS_CHECK fail <reason>".


func _ready() -> void:
	HLog.log_level = HLog.LogLevel.DEBUG
	var peer := await EosNet.host_async()
	if peer == null:
		print("EOS_CHECK fail ", EosNet.error)
	else:
		print("EOS_CHECK ok code=%s user=%s" % [EosNet.code, HAuth.product_user_id])
		peer.close()
		await EosNet.leave_async()
	# leave_async resumes inside the EOS tick: release the platform after it.
	await get_tree().process_frame
	EosNet.shutdown_platform()
	get_tree().quit()
