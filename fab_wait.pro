;+
; NAME:
;    fab_wait
;
; PURPOSE:
;    Wait for fixed time during programmatic interaction with FAB,
;    while continuing to update video.
;
; CATEGORY:
;    FAB
;
; CALLING SEQUENCE:
;    fab_wait, delay
;
; INPUTS:
;    delay: delay time [seconds]
;
; SIDE EFFECTS:
;    Does not allow for user interaction during waiting period.
;
; MODIFICATION HISTORY:
; 09/12/13 Written by David G. Grier, New York University
; 09/16/13 DGG Uses fab_video_update for better integration.
;
; Copyright (c) 2013 David G. Grier
;-

pro fab_wait, delay

COMPILE_OPT IDL2

t0 = systime(1)

s = getfab()
if ~ptr_valid(s) then begin
   wait, delay
   return
endif

if ~isa(*s, 'fabstate') then begin
   waid, delay
   return
endif

if delay lt (*s).timer then begin
   wait, delay
   return
endif

;widget_control, (*s).w.tlb, /clear_events ; is this necessary?

repeat begin
   t1 = systime(1)
   fab_video_update, s
   t2 = systime(1)
   wait, ((*s).timer - (t2 - t1)) > 0
endrep until (delay - (t2 - t0)) le (*s).timer

widget_control, (*s).w.timer, timer = (*s).timer

wait, (delay - (systime(1) - t0)) > 0

end
