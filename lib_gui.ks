function create_gui{
    parameter width,height.
    global my_gui to gui(width,height).
    set my_gui:style:width to width.
    set my_gui:style:height to height.
    my_gui:show().
    
}
