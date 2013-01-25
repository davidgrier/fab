;+
; NAME:
;    recorder
;
; PURPOSE:
;    Widget-based video recorder
;
; CATEGORY:
;    Holographic optical trapping
;
; CALLING SEQUENCE:
;    recorder
;
; KEYWORD PARAMETERS:
;    FPS: frames per second for video.  Setting this number
;         too high leads to jerky playback.
;         Default: 15
;
;    CAMERA_OBJECT: String containing name of the camera object to
;         use.  Default is to try all known camera classes in sequence
;         from most functional to least.
;
; SIDE EFFECTS:
;    Opens a GUI interface on the present display device.
;    Interacts with hardware on the system.
;
; MODIFICATION HISTORY:
; 12/29/2010 Written by David G. Grier, New York University
; 01/04/2011 DGG First complete version.
; 01/25/2011 DGG Trap creation, grouping, translation and in-plane
;   rotation, all with GPU acceleration. 
; 01/27/2011 DGG Help system based on xdisplayfile.
; 01/30/2011 DGG 3D rotations with quaternions.
; 02/04/2011 DGG Fixed SEL_GRP_ADD.  Completed CALXY.
; 02/05/2011 DGG Added (*s).cal for filename to store calibration constants.
;   Implemented incremental refinement of holograms.
;   FAB_GROUPROI sets action to 1 (normal) if no traps were grouped
;   and no selection was active.
; 02/08/2011 DGG Small clean-up of event loop, and improvements to 
;   comments and documentation.
; 03/22/2011 DGG Fix SEL_GRP_ADD if no group is selected.
; 03/28/2011 DGG snap image on every event for smoother video.
; 04/11/2011 DGG Various bug fixes associated with camera geometry.
;   Documentation fixes.
;
; Copyright (c) 2010-2011, David G. Grier
;-

;;;;;
;
; RECORDER_HELP
;
; Display and maintain help window
;
pro recorder_help, event ;s, title, helpfile

widget_control, event.id, get_uval = uval

case uval of 
   'USAGE': begin
      helpfile = 'fab_usage.txt'
      title = 'Record Movies with RECORDER'
   end
   'ABOUT' : begin
      helpfile = 'fab_about.txt'
      title = 'About RECORDER'
   end
else:
endcase
   
; look for filename
filename = file_which(helpfile)
if strlen(filename) lt strlen(helpfile) then $
   return

widget_control, event.top, get_uvalue = s

; clean up help browser, if needed
if widget_info((*s).w.help, /valid_id) then $
   widget_control, (*s).w.help, /destroy

; open new help browser
xdisplayfile, filename,                 $
              title       = title,      $
              group       = (*s).w.tlb, $
              return_id   = id,         $
              done_button = 'OK'
(*s).w.help = id
                   
end
                 
;;;;;
;
; RECORDER_STATUS
;
; Update the status line
;
pro recorder_status, s, status

COMPILE_OPT IDL2, HIDDEN

widget_control, $
   (*s).w.status, $
   set_value = (n_params() eq 2) ? "Status: " + status : 'Status'
end

;;;;;
;
; RECORDER_QUIT
;
pro recorder_quit, event

widget_control, event.top, /destroy
end

;;;;;
;
; RECORDER_EVENT
;
; Process the XMANAGER event queue
;
pro recorder_event, event

COMPILE_OPT IDL2, HIDDEN

; only timer events are processed in the main loop

widget_control, event.top, get_uvalue = s

(*s).o.camera.snap
(*s).o.screen.draw              ; update the screen

if (*s).recording then begin
   fn = (*s).recdir + dgtimestamp() + '.gdf'
   (*s).o.camera.write, fn
   recorder_status, s, 'Recorded ' + fn
endif

widget_control, event.top, timer = (*s).timer ; reset timer

end

;;;;;
;
; RECORDER_CLEANUP
;
; Free resources used by the UI.
;
pro recorder_cleanup, tlb

COMPILE_OPT IDL2, HIDDEN

widget_control, tlb, get_uvalue = s, /no_copy
ptr_free, s
end

;;;;;
;
; RECORDER
;
; The main routine
;
pro recorder, fps = fps, $
              camera_object = camera_object, $
              _extra = e

COMPILE_OPT IDL2

if xregistered('recorder') then begin
   message, 'Not starting: Another instance of recorder is running.',  /inf
   return
endif

timer = 0.01                  ; as fast as possible
if n_elements(fps) eq 1 then $
   timer = 1./fps

;;;; GUI
;;; graphics object hierarchy for video with overlayed trapping pattern
;;     camera object for video
if isa(camera_object, 'String') then $
   camera = obj_new(camera_object, /gray,  _extra = e)
;if ~isa(camera, 'DGGgrCam') then $
;   camera = DGGgrCAM_PVAPI(_extra =  e)
if ~isa(camera, 'DGGgrCam') then $
   camera = DGGgrCAM_V4L2(/gray, _extra = e)
if ~isa(camera, 'DGGgrCam') then $
   camera = DGGgrCAM_OpenCV(_extra = e)
if ~isa(camera, 'DGGgrCam') then $
   camera = DGGgrCAM(/gray, dimensions = [640, 480])
camera.getproperty, dimensions = dimensions

;;     screen for viewing images
image = IDLgrView(viewplane_rect = [0L, 0, dimensions])
imodel = IDLgrModel()
imodel.add, camera
image.add, imodel

;; The scene consists of the viewscreen
scene = IDLgrScene()
scene.add, image

;;; widget hierarchy for the user interface
;; top level widget
wtlb = widget_base(/column, title = "recorder", mbar = bar, tlb_frame_attr = 5)

;; menu bar
file_menu = widget_button(bar, value = 'File', /menu)
void = widget_button(file_menu, value = 'Quit', EVENT_PRO = "recorder_quit")

help_menu = widget_button(bar, value = 'Help', /menu)
void = widget_button(help_menu, value = 'About recorder',  $
                     EVENT_PRO = "recorder_help", UVALUE = 'ABOUT')
void = widget_button(help_menu, value = 'Instructions', $
                     EVENT_PRO = "recorder_help", UVALUE = 'USAGE')

;; window for drawing images
wscreen = widget_draw(wtlb, $
                      xsize = dimensions[0], $ ; geometry
                      ysize = dimensions[1], $
                      graphics_level = 2     $ ; object graphics
                     )
;; status line
wstatusline = widget_base(wtlb, /row)
wstatus = widget_text(wstatusline, value = 'Status', xsize = 60)
void = widget_button(wstatusline, value = 'Record', $
                     EVENT_PRO = "fab_togglerecord")

;; realize the widget hierarchy
widget_control, wtlb, /realize

;; create the state structure for the widget hierarchy
;      a draw screen's object representation is available
;      only after the draw widget is realized
widget_control, wscreen, get_value = screen
screen->setproperty, graphics_tree = scene

objects = {screen:  screen,  $
           scene:   scene,   $
           camera:  camera  $
          }

widgets = {tlb:    wtlb,     $  ; top-level widget base
           screen: wscreen,  $  ; draw widget
           status: wstatus,  $  ; status bar
           help:   0L        $  ; help browser (when instantiated)
          }

; the state structure
s = {o:         objects,     $  ; the state structure
     w:         widgets,     $  ; widget for displaying changes in status
     timer:     timer,       $  ; time between snapshots [seconds]
     recdir:   "",           $  ; directory for recording images
     recording: 0            $  ; flag when recording
    }

ps = ptr_new(s, /no_copy)       ; pass a pointer for efficiency

;; register the state structure with the top-level widget
widget_control, wtlb, set_uvalue = ps, /no_copy

;; start the event manager
xmanager, 'recorder', wtlb, /no_block, cleanup = 'recorder_cleanup'

;; start processing images
widget_control, wtlb, timer = 0.

end
