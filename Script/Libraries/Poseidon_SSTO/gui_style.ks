// Shared passive presentation helpers, using the ascent / return palette.
// Apply once when constructing a panel; flight loops only update values.
function pos_gui_window_style {
    parameter panel, panel_width.
    set panel:style:width to panel_width.
    set panel:style:bg to "Libraries/gui_images/ascent_window.png".
    set panel:style:padding:h to 16.
    set panel:style:padding:v to 16.
    // Skin defaults are copied by subsequently created widgets. This also
    // styles popup lists, which have their own window and item styles.
    set panel:skin:label:fontsize to 14.
    set panel:skin:label:textcolor to RGBA(0.9,0.93,0.95,1).
    for control_style in list(panel:skin:button,panel:skin:textfield,
        panel:skin:popupmenu,panel:skin:popupmenuitem,panel:skin:toggle) {
        set control_style:fontsize to 14.
        set control_style:bg to "Libraries/gui_images/ascent_panel.png".
        set control_style:textcolor to RGBA(0.9,0.93,0.95,1).
        set control_style:hover:bg to "Libraries/gui_images/ascent_track.png".
        set control_style:hover:textcolor to RGBA(1,1,1,1).
        set control_style:active:bg to "Libraries/gui_images/ascent_fill.png".
        set control_style:active:textcolor to RGBA(1,1,1,1).
        set control_style:focused:bg to "Libraries/gui_images/ascent_track.png".
        set control_style:focused:textcolor to RGBA(1,1,1,1).
        set control_style:on:bg to "Libraries/gui_images/ascent_track.png".
        set control_style:on:textcolor to RGBA(1,1,1,1).
    }
    for control_style in list(panel:skin:button,panel:skin:toggle,panel:skin:popupmenuitem) {
        for on_state in list(control_style:hover_on,control_style:active_on,control_style:focused_on) {
            set on_state:bg to "Libraries/gui_images/ascent_track.png".
            set on_state:textcolor to RGBA(1,1,1,1).
        }
    }
    set panel:skin:popupwindow:bg to "Libraries/gui_images/ascent_window.png".
}

function pos_gui_label_style {
    parameter label_widget, text_size is 14, text_align is "left", muted_text is false.
    set label_widget:style:fontsize to text_size.
    set label_widget:style:align to text_align.
    set label_widget:style:textcolor to RGBA(0.9,0.93,0.95,1).
    if muted_text { set label_widget:style:textcolor to RGBA(0.69,0.74,0.78,1). }
}

