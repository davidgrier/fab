

pro fab_calrho, s

compile_opt idl2

;if ~isa(s, 'pointer') then $
;   s = getfab()

v = {xi:0., eta:0.}

base = widget_base(title = 'Calibrate rho', $
                   uvalue = 'base', /column)

wxi = cw_fslider(base, title = 'xi', $
                 min = 0, max = 1000, $
                 /drag, /edit, $
                 uvalue = 'xi', value = v.xi)

weta = cw_fslider(base, title = 'eta', $
                 min = 0, max = 1000, $
                 /drag, /edit, $
                 uvalue = 'xi', value = v.eta)

wdone = widget_button(base, value = 'done')

; structure containing the widgets
w = {base: base, $
     wxi : wxi,  $
     weta: weta  $
    }

; current state of the program: widgets and values
widget_control, w.base, /realize
widget_control, w.base, set_uvalue = s

; start the event loop
xmanager, 'fab_calrho', w.base, /no_block

end
