;+
; NAME:
;    fabplayerc
;
; PURPOSE:
;    command-line controller for the fabplayer movie player
;
; CATEGORY:
;    multimedia
;
; CALLING SEQUENCE:
;    fabplayerc, [flags]
;
; KEYWORD FLAGS:
;    play: play current movie
;    pause: stop playing
;    restart: start movie over from beginning
;    done: quit
;
; COMMON BLOCKS:
;    managed: common block used by XMANAGER to store
;        information about realized widgets
;
; SIDE EFFECTS:
;    Influences the behavior of realized instances of fabplayer.
;
; RESTRICTIONS:
;    Currently only works with a single realized instance.
;
; PROCEDURE:
;    Simulates button-press events from the fabplayer UI.
;
; EXAMPLE:
;    fabplayer, "mymovie.avi"
;    fabplayerc, /pause
;
; MODIFICATION HISTORY:
; 12/27/2010 Written by David G. Grier, New York University
;
; Copyright (c) 2010 David G. Grier
;
;-

pro fabplayerc, play = play, pause = pause, restart = restart, done = done

COMPILE_OPT IDL2

common managed, ids, names, modalList

if ~keyword_set(ids) then begin
   message, "No instances of FABPLAYER are running", /inf
   return
endif

w = where(names eq 'fabplayer', nmanaged)

if nmanaged lt 1 then begin
   message, "No instances of FABPLAYER are running", /inf
   return
endif

top = ids[w[0]]

; simulate button pushes on UI
if keyword_set(play) then myname = 'PLAY'
if keyword_set(restart) then myname = 'RESTART'
if keyword_set(pause) then myname = 'PAUSE'
if keyword_set(done) then myname = 'DONE'
myid = widget_info(top, find_by_uname = myname)
myevent = {WIDGET_BUTTON, id:myid, top:top, handler:top, select:1}
widget_control, myid, send_event = myevent

end
