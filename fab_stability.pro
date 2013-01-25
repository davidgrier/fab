pro fab_stability_event, event

COMPILE_OPT IDL2, HIDDEN

widget_control, event.top, get_uvalue = s

widget_control, (*s).wtext, $
                set_value = 'Frame: ' + strtrim((*s).ndx)

(*s).buf[*, *, (*s).ndx] = fab_snap(/grayscale)

(*s).ndx--

if (*s).ndx lt 0 then $
   widget_control, event.top, /destroy $
else $
   widget_control, event.top, timer = 0.1 ; reset timer
end

pro fab_stability_cleanup, tlb

COMPILE_OPT IDL2, HIDDEN

widget_control, tlb, get_uvalue = s, /no_copy

a = float(reform((*s).buf[*,*,0]))
b = median((*s).buf, dim = 3) > 1.
spheretool, a/b

ptr_free, s
end

pro fab_stability, duration

COMPILE_OPT IDL2

;;; widget hierarchy
;; top level widget
wtlb = widget_base(/column, title = "fab stability")
wtext = widget_text(wtlb, value = 'Acquiring Images ...')
widget_control, wtlb, /realize

delay = 0.1
if n_params() lt 1 then duration = 10.

;;; allocate buffer for median filter
ndx = duration / delay
a = fab_snap(/grayscale)
sz = size(a, /dimensions)
buf = bytarr(sz[0], sz[1], ndx+1)
buf[0, 0, ndx] = a

;;; state structure
s = {wtext: wtext, $
     buf: buf, $
     ndx: ndx}
ps = ptr_new(s, /no_copy)
widget_control, wtlb, set_uvalue = ps, /no_copy

;;; start loop
xmanager, 'fab_stability', wtlb, /no_block, $
          cleanup = 'fab_stability_cleanup'

widget_control, wtlb, timer = 0.
end
