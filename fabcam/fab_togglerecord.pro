pro fab_togglerecord, event

widget_control, event.top, get_uvalue = s
(*s).recording = ~(*s).recording
if (*s).recording and strlen((*s).recdir) eq 0 then begin
   res = dialog_pickfile(title = 'Select Recording Directory', $
                         /directory, /write)
   if ~file_test(res, /directory, /write) then begin
      recorder_status, s, 'Cannot open selected directory for writing'
      (*s).recording = 0
   endif else $
      (*s).recdir = res
endif
if (*s).recording then begin
   recorder_status, s, 'Recording!'
   widget_control, event.id, set_value = 'Stop!'
endif else begin
   recorder_status, s, ''
   widget_control, event.id, set_value = 'Record'
endelse
end
