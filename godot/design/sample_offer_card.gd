extends Control
## /godot-design sample — proves the kit API renders through design_preview.gd.
## Throwaway reference design; not wired into the game.


func _ready() -> void:
	var card: PanelContainer = $Center/Card
	card.add_theme_stylebox_override("panel", GameTheme.overlay_ledger_style())

	var title: Label = $Center/Card/Margin/VBox/Title
	title.add_theme_font_override("font", GameFonts.heading())
	title.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)

	var flavor: Label = $Center/Card/Margin/VBox/Flavor
	GameTheme.apply_flavor_label(flavor)

	var price: Label = $Center/Card/Margin/VBox/Price
	price.add_theme_font_override("font", GameFonts.mono(true))
	price.add_theme_color_override("font_color", GameTheme.TEXT)

	var fmt: Node = get_node("/root/FormatUtil")
	price.text = "%s  ·  one-time" % fmt.format_money(24999.0)

	GameTheme.apply_overlay_cta($Center/Card/Margin/VBox/BuyBtn, true)
	GameTheme.apply_overlay_cta($Center/Card/Margin/VBox/LaterBtn, false)
