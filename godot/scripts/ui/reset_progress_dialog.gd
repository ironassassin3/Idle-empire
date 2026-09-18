class_name ResetProgressDialog
extends RefCounted


## Confirm-then-wipe flow shared by the shell config screen and the legacy game screen.
static func open(host: Node) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Reset all progress?"
	dialog.dialog_text = (
		"This permanently deletes your empire, purchases made with in-game "
		+ "currency, Influence, prestige progress, and settings.\n\n"
		+ "This cannot be undone."
	)
	dialog.ok_button_text = "Delete Everything"
	dialog.cancel_button_text = "Keep My Progress"
	dialog.confirmed.connect(func():
		SaveManager.delete_save()
		GameState.reset_new_game()
		host.get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	host.add_child(dialog)
	dialog.popup_centered_ratio(0.88)
