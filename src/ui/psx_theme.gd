class_name PSXTheme
extends RefCounted
## PSX-style UI theme generator - creates cohesive retro aesthetic

# Color palette matching arena aesthetic
const BG_DARK := Color(0.04, 0.02, 0.08, 0.95)
const BG_MID := Color(0.08, 0.04, 0.12, 0.9)
const BG_LIGHT := Color(0.12, 0.06, 0.18, 0.85)
const ACCENT_PRIMARY := Color(0.85, 0.25, 0.35, 1.0)    # Blood red
const ACCENT_SECONDARY := Color(0.75, 0.55, 0.2, 1.0)  # Gold
const ACCENT_CYAN := Color(0.2, 0.8, 0.9, 1.0)         # Cyan highlight
const TEXT_BRIGHT := Color(0.95, 0.92, 0.88, 1.0)
const TEXT_DIM := Color(0.6, 0.55, 0.5, 1.0)
const BORDER_COLOR := Color(0.4, 0.2, 0.25, 0.8)
const GLOW_COLOR := Color(0.85, 0.25, 0.35, 0.3)

static func create_theme() -> Theme:
	var theme := Theme.new()

	# Button styling
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = BG_MID
	btn_normal.border_color = BORDER_COLOR
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(0)  # Sharp corners for PSX look
	btn_normal.set_content_margin_all(12)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = BG_LIGHT
	btn_hover.border_color = ACCENT_PRIMARY
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(0)
	btn_hover.set_content_margin_all(12)
	btn_hover.shadow_color = GLOW_COLOR
	btn_hover.shadow_size = 4

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = ACCENT_PRIMARY.darkened(0.3)
	btn_pressed.border_color = ACCENT_SECONDARY
	btn_pressed.set_border_width_all(2)
	btn_pressed.set_corner_radius_all(0)
	btn_pressed.set_content_margin_all(12)

	var btn_focus := StyleBoxFlat.new()
	btn_focus.bg_color = BG_LIGHT
	btn_focus.border_color = ACCENT_SECONDARY
	btn_focus.set_border_width_all(2)
	btn_focus.set_corner_radius_all(0)
	btn_focus.set_content_margin_all(12)

	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("focus", "Button", btn_focus)
	theme.set_color("font_color", "Button", TEXT_BRIGHT)
	theme.set_color("font_hover_color", "Button", ACCENT_SECONDARY)
	theme.set_color("font_pressed_color", "Button", TEXT_BRIGHT)
	theme.set_font_size("font_size", "Button", 14)

	# Label styling
	theme.set_color("font_color", "Label", TEXT_BRIGHT)
	theme.set_font_size("font_size", "Label", 12)

	# Panel styling
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = BG_DARK
	panel_style.border_color = BORDER_COLOR
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(0)
	panel_style.set_content_margin_all(16)
	theme.set_stylebox("panel", "Panel", panel_style)

	# PanelContainer styling
	var panel_container := StyleBoxFlat.new()
	panel_container.bg_color = BG_MID
	panel_container.border_color = BORDER_COLOR
	panel_container.set_border_width_all(1)
	panel_container.set_corner_radius_all(0)
	panel_container.set_content_margin_all(8)
	theme.set_stylebox("panel", "PanelContainer", panel_container)

	# LineEdit styling
	var line_edit_normal := StyleBoxFlat.new()
	line_edit_normal.bg_color = BG_DARK
	line_edit_normal.border_color = BORDER_COLOR
	line_edit_normal.set_border_width_all(1)
	line_edit_normal.set_corner_radius_all(0)
	line_edit_normal.set_content_margin_all(8)

	var line_edit_focus := StyleBoxFlat.new()
	line_edit_focus.bg_color = BG_DARK
	line_edit_focus.border_color = ACCENT_PRIMARY
	line_edit_focus.set_border_width_all(2)
	line_edit_focus.set_corner_radius_all(0)
	line_edit_focus.set_content_margin_all(8)

	theme.set_stylebox("normal", "LineEdit", line_edit_normal)
	theme.set_stylebox("focus", "LineEdit", line_edit_focus)
	theme.set_color("font_color", "LineEdit", TEXT_BRIGHT)
	theme.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)
	theme.set_color("caret_color", "LineEdit", ACCENT_PRIMARY)
	theme.set_font_size("font_size", "LineEdit", 12)

	# ProgressBar styling
	var progress_bg := StyleBoxFlat.new()
	progress_bg.bg_color = BG_DARK
	progress_bg.border_color = BORDER_COLOR
	progress_bg.set_border_width_all(1)
	progress_bg.set_corner_radius_all(0)

	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = ACCENT_PRIMARY
	progress_fill.set_corner_radius_all(0)

	theme.set_stylebox("background", "ProgressBar", progress_bg)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)

	# HSlider styling
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = BG_DARK
	slider_bg.border_color = BORDER_COLOR
	slider_bg.set_border_width_all(1)
	slider_bg.set_corner_radius_all(0)
	slider_bg.set_content_margin_all(4)

	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = ACCENT_PRIMARY.darkened(0.2)
	slider_fill.set_corner_radius_all(0)

	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)

	# OptionButton styling
	theme.set_stylebox("normal", "OptionButton", btn_normal)
	theme.set_stylebox("hover", "OptionButton", btn_hover)
	theme.set_stylebox("pressed", "OptionButton", btn_pressed)
	theme.set_stylebox("focus", "OptionButton", btn_focus)
	theme.set_color("font_color", "OptionButton", TEXT_BRIGHT)
	theme.set_color("font_hover_color", "OptionButton", ACCENT_SECONDARY)
	theme.set_font_size("font_size", "OptionButton", 12)

	# PopupMenu styling
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = BG_DARK
	popup_style.border_color = ACCENT_PRIMARY.darkened(0.3)
	popup_style.set_border_width_all(2)
	popup_style.set_corner_radius_all(0)
	popup_style.set_content_margin_all(4)

	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color = ACCENT_PRIMARY.darkened(0.5)
	popup_hover.set_corner_radius_all(0)

	theme.set_stylebox("panel", "PopupMenu", popup_style)
	theme.set_stylebox("hover", "PopupMenu", popup_hover)
	theme.set_color("font_color", "PopupMenu", TEXT_BRIGHT)
	theme.set_color("font_hover_color", "PopupMenu", ACCENT_SECONDARY)
	theme.set_font_size("font_size", "PopupMenu", 12)

	# HSeparator
	var separator_style := StyleBoxFlat.new()
	separator_style.bg_color = BORDER_COLOR
	separator_style.set_content_margin_all(0)
	theme.set_stylebox("separator", "HSeparator", separator_style)
	theme.set_constant("separation", "HSeparator", 2)

	return theme

static func create_health_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT_PRIMARY
	style.set_corner_radius_all(0)
	return style

static func create_stamina_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT_CYAN
	style.set_corner_radius_all(0)
	return style

static func create_shield_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.5, 0.9, 1.0)
	style.set_corner_radius_all(0)
	return style
