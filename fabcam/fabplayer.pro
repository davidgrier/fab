;+
; NAME:
;    fabplayer
;
; PURPOSE:
;    Widget-based movie player
;
; CATEGORY:
;    multimedia
;
; CALLING SEQUENCE:
;    fabplayer, title
;
; INPUTS:
;    title: file name of movie.
;
; KEYWORD FLAGS:
;    grayscale: If set, run movie in grayscale.
;
; KEYWORD PARAMETERS:
;    geometry: [width, height]
;
; SIDE EFFECTS:
;    Opens a GUI interface on the present display device.
;
; RESTRICTIONS:
;    Plays any movie that can be viewed with the OpenCV interface.
;
; PROCEDURE:
;    Uses IDL object graphics to display movies frame by frame.
;
; EXAMPLE:
;    fabplayer, "mymovie.avi"
;
; MODIFICATION HISTORY:
; 12/28/2010 Written by David G. Grier, New York University
;
; Copyright (c) 2010 David G. Grier
;
;-

;
; FABPLAYER_EVENT
;
; Process the XMANAGER event queue
;
pro fabplayer_event, event

COMPILE_OPT IDL2, HIDDEN

widget_control, event.top, get_uvalue = s

case tag_names(event, /structure_name) of
   'WIDGET_TIMER': begin
      if ((*s).pause ne 0) then begin ; eat this timer event ...
         (*s).pause = 0               ; ... but not the next one
      endif else if available_videoframe((*s).stream) then begin
         widget_control, event.top, timer = 1./30.
         (*s).im->putdata, read_videoframe((*s).stream)
      endif
   end

   'WIDGET_BUTTON': begin
      widget_control, event.id, get_uvalue = uval

      case uval of
         'PLAY': widget_control, event.top, timer = 0.01
         'PAUSE': (*s).pause = 1
         'RESTART': if is_videostream((*s).stream) then begin
            filename = (*s).stream.filename
            grayscale = (*s).stream.grayscale
            geometry = (*s).stream.geometry
            if (geometry[0] eq -1) then $
               geometry = [(*s).stream.width, (*s).stream.height]
            close_video, (*s).stream
            (*s).stream = open_videofile(filename, $
                                         grayscale = grayscale, $
                                         geometry = geometry)
            widget_control, event.top, timer = 0.01
         endif
         'DONE': widget_control, event.top, /destroy
         else:                  ; do nothing
      endcase
   end

   'WIDGET_BASE': begin
      widget_control, event.id, tlb_get_size = newsize
      xy = newsize - (*s).pad
      widget_control, (*s).wImage, $
                      draw_xsize = xy[0], draw_ysize = xy[1], $
                      scr_xsize = xy[0], scr_ysize = xy[1]
   end
   
   else: help, event
endcase
end

;
; FABPLAYER_CLEANUP
;
; Shut down the video stream.
; Free resources used by the UI.
;
pro fabplayer_cleanup, w

COMPILE_OPT IDL2, HIDDEN

widget_control, w, get_uvalue = s
close_video, (*s).stream
ptr_free, s
end

;
; FABPLAYER
;
; The main routine
;
pro fabplayer, filename, grayscale = grayscale, geometry = geometry

COMPILE_OPT IDL2

stream = open_videofile(filename, grayscale = grayscale, geometry = geometry)

if ~is_videostream(stream) then return

base = widget_base(/column, title = "fabplayer", /tlb_size_events)

wImage = widget_window(base, uvalue = 'image', uname = 'IMAGE')

; base for the buttons
buttons = widget_base(base, /row, /align_center)
play = widget_button(buttons, value = 'Play', uvalue = 'PLAY', $
                    uname = 'PLAY')
pause = widget_button(buttons, value = 'Pause', uvalue = 'PAUSE', $
                      uname = 'PAUSE')
restart = widget_button(buttons, value = 'Restart', uvalue = 'RESTART', $
                       uname = 'RESTART')
done = widget_button(buttons, value = 'Done', UVALUE = 'DONE', $
                    uname = 'DONE')

; realize the widget
widget_control, base, /realize

xmanager, 'fabplayer', base, /no_block, cleanup = 'fabplayer_cleanup'

; get the window object
widget_control, wImage, get_value = win
win.select
; read image
a = read_videoframe(stream)
; draw image in window
im = image(a, margin = 0, /current)

widget_control, base, tlb_get_size = basesize
xpad = basesize[0] - 640
ypad = basesize[1] - 512
pad = [xpad, ypad]

; state variable
s = {stream:stream, im:im, wImage:wImage, pad:pad, pause:0}
ps = ptr_new(s, /no_copy)

widget_control, base, set_uvalue = ps, /no_copy

; start processing images
widget_control, base, timer = 0.01

end
