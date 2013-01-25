;+
; NAME:
;    fabcam
;
; PURPOSE:
;    Widget-based camera app
;
; CATEGORY:
;    multimedia
;
; CALLING SEQUENCE:
;    fabcam
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
;    Plays the video feem from any camera that can be 
;    viewed with the OpenCV interface.
;
; PROCEDURE:
;    Uses IDL object graphics to display video images frame by frame.
;
; EXAMPLE:
;    fabcam, /grayscale
;
; MODIFICATION HISTORY:
; 12/28/2010 Written by David G. Grier, New York University
;
; Copyright (c) 2010 David G. Grier
;
;-

;
; FABCAM_EVENT
;
; Process the XMANAGER event queue
;
pro fabcam_event, event

COMPILE_OPT IDL2, HIDDEN

widget_control, event.top, get_uvalue = s

case tag_names(event, /structure_name) of
   'WIDGET_TIMER': begin
      if ((*s).pause ne 0) then begin ; eat this timer event ...
         (*s).pause = 0               ; ... but not the next one
      endif else if available_videoframe((*s).stream) then begin
         o = (*s).objs
         widget_control, event.top, timer = 1./30.
         a = read_videoframe((*s).stream)
         o.image->setproperty, data = a, /no_copy
         o.draw->draw, o.view
      endif
   end

   'WIDGET_BUTTON': begin
      widget_control, event.id, get_uvalue = uval

      case uval of
         'PLAY': widget_control, event.top, timer = 0.01
         'PAUSE': (*s).pause = 1
         'DONE': widget_control, event.top, /destroy
         else:                  ; do nothing
      endcase
   end

   else: help, event
endcase
end

;
; FABCAM_CLEANUP
;
; Shut down the video stream.
; Free resources used by the UI.
;
pro fabcam_cleanup, w

COMPILE_OPT IDL2, HIDDEN

widget_control, w, get_uvalue = s
close_video, (*s).stream
ptr_free, s
end

;
; FABCAM
;
; The main routine
;
pro fabcam, grayscale = grayscale, geometry = geometry

COMPILE_OPT IDL2

stream = open_videocamera(grayscale = grayscale, geometry = geometry)

if ~is_videostream(stream) then return

base = widget_base(/column, title = "fabcam", tlb_frame_attr = 1)

draw = widget_draw(base, $
                   xsize = stream.geometry[0], $
                   ysize = stream.geometry[1], $
                   graphics_level = 2)

; base for the buttons
buttons = widget_base(base, /row, /align_center)
void = widget_button(buttons, value = 'Play', uvalue = 'PLAY', $
                     uname = 'PLAY')
void = widget_button(buttons, value = 'Pause', uvalue = 'PAUSE', $
                     uname = 'PAUSE')
void = widget_button(buttons, value = 'Done', UVALUE = 'DONE', $
                     uname = 'DONE')

; realize the widget hierarchy
widget_control, base, /realize

a = read_videoframe(stream)
widget_control, draw, get_value = odraw
oview = obj_new('IDLgrView', viewplane_rect = [0., 0., stream.geometry])
omodel = obj_new('IDLgrModel')
oimage = obj_new('IDLgrImage', a)
omodel->add, oimage
oview->add, omodel
objs = {draw:odraw, view:oview, image:oimage}

xmanager, 'fabcam', base, /no_block, cleanup = 'fabcam_cleanup'

; state variable
s = {stream:stream, objs:objs, pause:0}
ps = ptr_new(s, /no_copy)

widget_control, base, set_uvalue = ps, /no_copy

; start processing images
widget_control, base, timer = 1./30.
odraw->draw, oview

end
