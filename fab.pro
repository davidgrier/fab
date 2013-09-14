;+
; NAME:
;    fab
;
; PURPOSE:
;    Widget-based HOT interface
;
; CATEGORY:
;    Holographic optical trapping
;
; CALLING SEQUENCE:
;    fab
;
; KEYWORD PARAMETERS:
;    FPS: frames per second for video.  Setting this number
;         too high leads to jerky video.
;         Default: 15
;
;    CAMERA_OBJECT: String containing name of the camera object to
;         use.  Default is to try all known camera classes in sequence
;         from most functional to least.
;
;    CGH_OBJECT: String containing name of the CGH computation
;         pipeline to use.  Default is to try all known CGH classes
;         in sequence from fastest to slowest.
;
;    CALFILE: String containing name of file to use for saving 
;         and restoring calibration constants.
;
; INSTRUCTIONS: 
; LEFT MOUSE: Translating
;    CLICK-DRAG   to move a trap or group of traps in the plane
;    SHIFT-CLICK  create a trap in its own group
;    CTL-CLICK    to delete a trap or a group of traps
;    ALT-CLICK    to move a trap within a group
;
; MIDDLE MOUSE: Rotating
;    CLICK-DRAG   rotate the selected trap relative to the the
;                 center of its group.
;                 * dragging azimuthally rotates around z.  
;                 * dragging in or out rotates into or out of the
;                 plane. TODO
;    SHIFT-CLICK  create a trap in its own group (same as left mouse)
;    CTL-CLICK    delete a trap or group of traps (same as left click)
;
; RIGHT MOUSE: Grouping
;    CLICK:       add trap to active group, or enter grouping mode
;                 if no group is active
;    SHIFT-CLICK: create trap and add it to the active group
;    CTL-CLICK:   remove trap from a group
;    CLICK-DRAG:  select region of traps TODO
;
; MOUSE-WHEEL: Axial displacements
;    FORWARD:     displace selected group in positive z direction
;    BACKWARD:    displace selected group in negative z direction
;
; Mechanical motions, assuming compatible stage:
;    ARROW KEYS: Move stage
;    PG_UP/PG_DOWN: Axial motion
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
; 04/23/2011 DGG Button events handled with EVENT_PRO to clean up
;   the main event loop.  Associated code reorganization, with no
;   user-visible changes.
; 04/28/2011 DGG Heavily revised property sheet code.
;   Property sheet updates in real time, and accounts for changing
;   numbers of traps.
; 10/04/2011 DGG internal structures are named, rather than anonymous,
;   for easier reference outside FAB.
; 10/14/2011 DGG removed command-line reference to TRAPS; use
;   getfab.pro instead.  Implemented video recording with recorder
;   object.  Added Recorder to PROPERTIES menu.  Set recording
;   directory from FILE menu.  Select calibration file from
;   CALIBRATION memn.
; 11/20/2011 DGG Added FAB_SAVECALIBRATION to streamline saving
;   calibration constants.
; 12/06/2011 DGG & Daniel Evans (NYU): Implemented crude stage
;   controls with arrow keys and PgUp/PgDown
; 12/09/2011 DGG saved calibration constants include SLM center.
;   Added FAB_READCALIBRATION.  COMPILE_OPT for FAB_SAVECALIBRATION.
; 12/10/2011 DGG added support for DGGhwShutter.
; 12/19/2011 DGG fixed FAB_SAVECALIBRATION file selection.
; 05/04/2012 DGG Added CALFILE keyword.  Restore calibration on
;   startup.  Calibration->Restore restores calibration without dialog
;   to pick file.  Calibration->Read asks for filename.
;   Single quotes for strings.  Updated parameter checking.
; 06/12/2012 DGG Added FAB_PHASE to provide random phases for traps.
;
; Copyright (c) 2010-2012, David G. Grier and Daniel Evans
;-
;;;;;
;
; FAB_PHASE
;
; Random phase angle
;
function fab_phase, s

return, 2.*!pi*randomu((*s).seed, 1)
end

;;;;;
;
; FAB_STATUS
;
; Update the status line with feedback for the user
;
pro fab_status, s, status

COMPILE_OPT IDL2, HIDDEN

widget_control, $
   (*s).w.status, $
   set_value = (n_params() eq 2) ? 'Status: ' + status : 'Status'
end

;;;;; Event Handlers for Button Events
;;;;; Menus:
;;;;; 1. File
;;;;; 2. Calibrate
;;;;; 3. Properties
;;;;; 4. Help
;;;;; Buttons:
;;;;; 1. Record

;;;;;
;
; FAB_FILE
;
pro fab_file, event

COMPILE_OPT IDL2, HIDDEN

widget_control, event.top, get_uvalue = s
widget_control, event.id,  get_uvalue = uval

case uval of
   'CLEAR' : begin
      (*s).o.traps.clear
      fab_status, s, "Cleared the traps"
   end

   'RECDIR' : begin
      res = dialog_pickfile(title = 'Choose Recording Directory', $
                            /directory, /must_exist, /write, $
                            path = ((*s).o.recorder).dir, $
                            file = ((*s).o.recorder).dir)
      if strlen(res) gt 0 then $
         ((*s).o.recorder).dir = res
      fab_status, s, 'Recording Directory: ' + res
   end

   'QUIT' : begin
      (*s).o.traps.clear
      fab_status, s, 'Bye bye'
      widget_control, event.top, /destroy
   end

else:
endcase
end

;;;;;
;
; FAB_SAVECALIBRATION
;
; Save calibration constants
;
pro fab_savecalibration, s, pick = pick

COMPILE_OPT IDL2, HIDDEN

if keyword_set(pick) then begin
   filters = [['*.sav', '*.*'], $
              ['IDL Save Files', 'All Files']]
   res = dialog_pickfile(title = 'Save Calibration Constants', $
                         file = (*s).calfile, $
                         path = file_dirname((*s).calfile), $
                         default_extension = 'sav', $
                         filter = filters, $
                         /overwrite_prompt, $
                         /write)
   if strlen(res) gt 0 then $
      (*s).calfile = res
endif

; cannot save: directory not writable
if ~file_test(file_dirname((*s).calfile), /write) then begin
   fab_status, s, 'Could not write to ' + file_dirname((*s).calfile)
   return
endif

; cannot save: file exists but is not writable
if file_test((*s).calfile, /regular) then begin
   if ~file_test((*s).calfile, /write) then begin
      fab_status, s, 'Could not overwrite ' + (*s).calfile
      return
   endif
endif

(*s).o.cgh.getproperty, rc = rc, mat = mat, kc = kc
save, rc, mat, kc, $
      DESCRIPTION = 'FAB calibration constants', $
      FILENAME = (*s).calfile
fab_status, s, 'Saved calibration constants to ' + $
            (*s).calfile

end

;;;;;
;
; FAB_READCALIBRATION
;
; Restore calibration constants
;
pro fab_readcalibration, s, pick = pick

COMPILE_OPT IDL2, HIDDEN

if keyword_set(pick) then begin
   res = dialog_pickfile(title = 'Restore Calibration Constants', $
                         file = (*s).calfile, $
                         path = file_dirname((*s).calfile), $
                         default_extension = 'sav', $
                         filter = ['*.sav'], $
                         /read, /must_exist)
   if strlen(res) gt 0 then $
      (*s).calfile = res
endif
if file_test((*s).calfile, /read, /regular) then begin
   restore, FILENAME = (*s).calfile
   (*s).o.cgh.setproperty, rc = rc, mat = mat, kc = kc
   fab_status, s, 'Restored calibration constants from ' + $
               (*s).calfile
endif else $
   fab_status, s, 'could not read ' + (*s).calfile
end

;;;;;
;
; FAB_CALIBRATE
;
; Run calibration routines
;
pro fab_calibrate, event

COMPILE_OPT IDL2, HIDDEN

widget_control, event.top, get_uvalue = s
widget_control, event.id,  get_uvalue = uval

case uval of
   'CLEAR': begin
      (*s).o.camera.getproperty, dimensions = dim
      rc = [dim/2., 0]
      mat = [[1., 0, 0], [0, 1, 0], [0, 0, 1]]
      kc = ((*s).o.slm).dim/2.
      (*s).o.cgh.setproperty, rc = rc, mat = mat, kc = kc
      fab_status, s, 'Reset calibration constants'
   end

   'XY': begin               ; Calibrate XY coordinates
      resolve_routine, 'fab_calphase'
      fab_clearselection, s
      fab_calxy, s
   end

   'APERTURE': begin
      resolve_routine, 'fab_calaperture'
      fab_clearselection, s
      fab_calaperture, s
   end

   'PHASE': begin
      resolve_routine, 'fab_calphase'
      fab_clearselection, s
      fab_calphase, s
   end

   'SAVE': fab_savecalibration, s

   'SAVEAS': fab_savecalibration, s, /pick

   'RESTORE': fab_readcalibration, s

   'READ': fab_readcalibration, s, /pick

else:
endcase
     
end

;;;;;
;
; FAB_HELP
;
; Display and maintain help window
;
pro fab_help, event

COMPILE_OPT IDL2, HIDDEN

; what do we want help about?
widget_control, event.id, get_uval = uval

case uval of
   'USAGE' : begin
      helpfile = 'fab_usage.txt'
      title = 'How to use FAB'
   end

   'ABOUT' : begin
      helpfile = 'fab_about.txt'
      title = 'About FAB'
   end

   'CALIBRATION' : begin
      helpfile = 'fab_calibrate.txt'
      title = 'Calibration'
   end

   'RECORD' : begin
      helpfile = 'fab_record.txt'
      title = 'Recording images'
   end
else:
endcase

; look for filename
filename = file_which(helpfile)
if strlen(filename) lt strlen(helpfile) then $
   return

; XXX is there another way to clean up old browser?
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
; FAB_RECORD
;
; Start or stop recording images
;
pro fab_record, event

COMPILE_OPT IDL2, HIDDEN

widget_control, event.top, get_uvalue = s
(*s).recording = ~(*s).recording
if (*s).recording then begin
   fab_status, s, 'Recording!'
   widget_control, event.id, set_value = 'Stop!'
endif else begin
   fab_status, s, ''
   widget_control, event.id, set_value = 'Record'
endelse
end

;;;;; Routines for handing GUI interactions with traps
       
;;;;;
;
; FAB_TRAPACTION
;
; Figure out what to do based on an event structure
;
; We obtain this information from the WIDGET_DRAW event:
; {WIDGET_DRAW, ID:0L, TOP:0L, HANDLER:0L, TYPE:0, $
;               X:0L, Y:0L, $
;               PRESS:0B, RELEASE:0B, CLICKS:0L, MODIFIERS:0L, $
;               CH:0B, KEY:0L}
; TYPE:
; 0 Button press
; 1 Button release
; 2 Motion
; ...
; 6 Keyboard
; 7 Wheel scroll
;
; PRESS/RELEASE:
; 1 Left
; 2 Middle
; 4 Right
;
; MODIFIERS
; 1 Shift
; 2 Control
; 4 Caps Lock (Really?)
; 8 Alt -- mapped to MOD1 key on Unix systems
;
; INPUTS
;    ev: WIDGET_DRAW event structure
;
; OUTPUTS
;    str: String describing action to be taken
;
function fab_trapaction, event

COMPILE_OPT IDL2, HIDDEN

if event.release ne 0 then $
   return, 'END_ACTION'

case event.type of
   7: return, 'MOV_Z'           ; wheel scroll
   6: begin                     ; keyboard press (stage motion?)
      case event.key of
         5:  return, 'STAGE_LEFT'  ; arrow keys
         6:  return, 'STAGE_RIGHT'
         7:  return, 'STAGE_UP'
         8:  return, 'STAGE_DOWN'
         9:  return, 'STAGE_ZUP'   ; page up  
         10: return, 'STAGE_ZDOWN' ; page down
         else: return, ''
      endcase
   end
   2: return, 'MOV'             ; motion
;   1: str =   'END'            ; button release
   0: str =   'SEL'             ; button click
   else: return, ''             ; not a fab_trapaction
endcase

case event.press of
   1: str += '_TRANS'           ; left mouse
   2: str += '_ROT'             ; middle mouse
   4: str += '_GRP'             ; right
   else: return, ''             ; ignore unresolvable interactions
endcase

case event.modifiers of
   1: str += '_ADD'             ; SHIFT
   2: str += '_REM'             ; CONTROL
   8: str += '_ALT'             ; ALT
else:
endcase

return, str
end

;;;;;
;
; FAB_FOUNDTRAP
;
; Return an object reference to a trap in the vicinity of a specified position
;
; INPUT
;    s: state structure of the fabrication system
;    xy: in-plane position at which a trap is being sought
;
; KEYWORD PARAMETERS
;    trap: on output, a pointer to the particular trap within a group
;        that was selected
; 
; KEYWORD FLAGS:
;    movable: if set, only return a trapping group that can be moved.
;        Default: return immutable trapping groups if no movable
;        groups are found
;
; OUTPUT
;    group: pointer to the selected group, if found.  NULL pointer
;        otherwise.
;
function fab_foundtrap, s, xy, $
                        trap = trap,   $     ; particular trap that was found
                        movable = movable    ; only return movable groups

COMPILE_OPT IDL2, HIDDEN

found = (*s).o.screen.select((*s).o.overlay, xy, dimensions = [10,10])

if ~obj_valid(found[0]) then $               ; nothing found
   return, ptr_new()

foreach trap, found do begin                 ; found at least one trap
   trap.getproperty, parent = group, rc = rc ; get trap's group and position
   group.setproperty, rs = rc                ; select group at trap's position
   if (group.ismoveable()) then $
      return, ptr_new(group)                 ; return first movable group
endforeach
                                
if keyword_set(movable) then $               ; no movable groups found
   return, ptr_new()

return, ptr_new(group)                       ; return an unmovable group

end

;;;;;
;
; FAB_GROUPROI
;
; Add groups within the ROI to the active group
;
pro fab_grouproi, s

COMPILE_OPT IDL2, HIDDEN

if ~isa((*s).roi) then $ ; no ROI: nothing to do
   return

groups = (*s).o.traps.get(/all, isa = 'DGGhotTrapGroup')
foreach group, groups do begin
   if ~isa(group, 'DGGhotTrapGroup') then begin
      if ~isa((*s).selected) then $
         (*s).action = 1
      break
   endif
   group->getproperty, trapdata = d
   found = *(*s).roi.containspoints(d[0:1,*])
   if min(found) gt 0 then begin ; add this group to the active group
      if isa((*s).selected) then begin
         *(*s).selected->add, group 
      endif else begin          ; this group becomes the active group
         group.setproperty, state = 4
         (*s).selected = ptr_new(group)
      endelse
   endif
endforeach

; clean up resources
obj_destroy, *(*s).roi
(*s).roi = ptr_new()

end

;;;;;
;
; FAB_CLEARSELECTION
;
; Clear the selected trapping group
;
pro fab_clearselection, s

COMPILE_OPT IDL2, HIDDEN

fab_status, s
if isa((*s).selected) then $
   *(*s).selected->setproperty, state = 1
(*s).selected = ptr_new()
(*s).action = 1
end

;;;;; The main event loop for the program

pro fab_gui_event, event

print, tag_names(event, /structure_name)
end

;;;;;
;
; FAB_EVENT
;
; Process the XMANAGER event queue
;
pro fab_event, event

COMPILE_OPT IDL2, HIDDEN

widget_control, event.top, get_uvalue = s

case tag_names(event, /structure_name) of
   'WIDGET_TIMER': begin
      widget_control, event.top, timer = (*s).timer ; reset timer
   end

   'WIDGET_DRAW': begin         ; GUI interaction with traps
      xy = [event.x, event.y]
      case fab_trapaction(event) of
         'END_ACTION' : begin
            if (*s).action eq 4 then $
               fab_grouproi, s $
            else $
               fab_clearselection, s
            widget_control, (*s).w.screen, draw_motion_events = 0
         end         
      
         'MOV_Z': begin         ; Axial motion
            this = fab_foundtrap(s, xy, /movable)
            if isa(this) then $
               *this->moveby, [0., 0., float(event.clicks)]
         end

         'MOV': begin           ; In-plane motion
            case (*s).action of
               2: *(*s).selected->moveto, xy
               3: *(*s).selected->rotateto, xy
               4: if isa((*s).roi) then $
                  *(*s).roi->setproperty, r1 = xy
               else:
            endcase
         end

         'SEL_TRANS': begin     ; Select a group of traps for in-plane motion
            fab_clearselection, s
            this = fab_foundtrap(s, xy, /movable) ; only select movable group
            if isa(this) then begin               ; ... got one
               *this->setproperty, state = 2      ; ... so translate it
               (*s).action = 2
               widget_control, (*s).w.screen, /draw_motion_events
               fab_status, s, "Translating"
            endif
            (*s).selected = this
           end

         'SEL_TRANS_ADD' : begin ; Add a trap in its own group
            fab_clearselection, s
            (*s).o.traps.add, $
               DGGhotTrapGroup(DGGhotTweezer(rc = xy, $
                                             phase = fab_phase(s)), state = 1)
            fab_status, s, 'Added a trap'
            fab_propertysheet, s, /reload
         end
         
         'SEL_TRANS_REM' : begin ; Remove a group of traps
            fab_clearselection, s
            this = fab_foundtrap(s, xy) ; any trap is fair game
            if isa(this) then begin     ; ... found one
               obj_destroy, *this       ; ... destroy it
               (*s).o.traps.project     ; ... update CGH and representation
               fab_status, s, 'Removed a trap'
            endif
            fab_propertysheet, s, /reload
         end

         'SEL_ROT' : begin      ; Select a group of traps for rotation
            fab_clearselection, s
            this = fab_foundtrap(s, xy, /movable) ; only choose movable group
            if isa(this) then begin               ; ... found one
               if *this.count() ge 2 then begin   ; if it has enough traps
                  (*s).selected = this            ; ... select it
                  *this->setcenter                ; ... update its center
                  *this->setproperty, state = 3   ; ... and rotate it
                  (*s).action = 3
                  widget_control, (*s).w.screen, /draw_motion_events
                  fab_status, s, "Rotating"
               endif
            endif
         end

         'SEL_ROT_ADD' : begin  ; Add a trap in its own group
            fab_clearselection, s
            (*s).o.traps.add, $
               DGGhotTrapGroup(DGGhotTweezer(rc = xy, $
                                             phase = fab_phase(s)))
            fab_status, s, 'Added a trap'
            fab_propertysheet, s, /reload
         end

         'SEL_ROT_REM' : begin  ; Remove a group of traps
            fab_clearselection, s
            this = fab_foundtrap(s, xy) ; any group is fair game
            if isa(this) then begin     ; ... found one
               obj_destroy, *this       ; ... destroy it
               (*s).o.traps.project     ; ... update CGH and representation
               fab_status, s, 'Removed a trap'
            endif
            fab_propertysheet, s, /reload
         end

         'SEL_GRP' : begin
            this = fab_foundtrap(s, xy, /movable) ; only group movable traps
            if isa(this) then begin               ; found a trap
               if isa((*s).selected) then begin   ; ... add to existing group
                  *(*s).selected->add, *this
               endif else begin                   ; or create new active group
                  *this->setproperty, state = 4
                  (*s).selected = this
               endelse
            endif else begin                      ; dragging to make group
               roi = fab_roi(r0 = xy)             ; ... create ROI
               (*s).o.overlay.add, roi            ; ... show it in GUI
               (*s).roi = ptr_new(roi, /no_copy)  ; ... use it to select traps
               widget_control, (*s).w.screen, /draw_motion_events
            endelse
            (*s).action = 4
            fab_status, s, "Grouping"
         end

         'SEL_GRP_ADD' : begin               ; Add a trap to the active group
            this = DGGhotTweezer(rc = xy, $  ; create new optical tweezer
                                 phase = fab_phase(s))
            if isa((*s).selected) then begin ; ... add to existing group
               *(*s).selected->add, this
               fab_status, s, "Added a trap to the group of traps"
            endif else begin                 ; ... or create new active group
               thisgroup = DGGhotTrapGroup(this, state = 4)
               (*s).action = 4
               (*s).o.traps.add, thisgroup
               (*s).selected = ptr_new(thisgroup)
               fab_status, s, "Created a new group of traps"
            endelse
            fab_propertysheet, s, /reload
         end

         'SEL_GRP_REM' : begin             ; Remove a trap from a group
            thisgroup = fab_foundtrap(s, xy, trap = thistrap, /movable)
            if isa(thisgroup) then begin   ; found a group
               *thisgroup->setproperty, state = 4
               (*s).action = 4             ; ... so now we're "grouping"
               (*s).selected = thisgroup   ; can only remove trap from group
               if *thisgroup.count() ge 2 then begin ; ... with enough traps
                  *thisgroup->remove, thistrap
                  (*s).o.traps.add, DGGhotTrapGroup(thistrap, state = 1)
                  fab_status, s, "Separated a trap from the group"
               endif
            endif
         end

         'STAGE_RIGHT' : (*s).o.stage->step, /right
         'STAGE_LEFT'  : (*s).o.stage->step, /left
         'STAGE_UP'    : (*s).o.stage->step, /up
         'STAGE_DOWN'  : (*s).o.stage->step, /down
         'STAGE_ZUP'   : (*s).o.stage->step, /zup
         'STAGE_ZDOWN' : (*s).o.stage->step, /zdown

         else:                  ; unsupported event
      endcase

      fab_propertysheet, s, /refresh
   end ; WIDGET_DRAW events

   else: help, event
endcase

(*s).o.camera.snap
(*s).o.screen.draw              ; update the screen
if (*s).recording then begin
   fn = (*s).o.recorder.write((*s).o.camera.image())
   fab_status, s, 'Wrote: '+fn
endif
end

;;;;;
;
; FAB_CLEANUP
;
; Free resources used by the UI.
;
pro fab_cleanup, tlb

COMPILE_OPT IDL2, HIDDEN

widget_control, tlb, get_uvalue = s, /no_copy
if isa((*s).selected) then $
   ptr_free, (*s).selected
ptr_free, s
end

;;;;;
;
; FAB
;
; The main routine
;
pro fab, fps = fps, $
         camera_object = camera_object, $
         cgh_object = cgh_object, $
         calfile = calfile, $
         _extra = e

COMPILE_OPT IDL2

if xregistered('fab') then begin
   message, 'Not starting: Another instance of fab already is running.',  /inf
   return
endif

timer = 1./24.                  ; cinema rates, why not?
if isa(fps, /scalar, /number) then $
   timer = 1./fps

if ~isa(calfile, 'string') then $
   calfile = '/tmp/calibration.sav'

;;; Hardware interfaces
;; camera object for video
if isa(camera_object, 'String') then $
   camera = obj_new(camera_object, /gray, _extra = e)
if ~isa(camera, 'DGGgrCam') then $
   camera = DGGgrCAM_PVAPI(_extra =  e)
if ~isa(camera, 'DGGgrCam') then $
   camera = DGGgrCAM_V4L2(/gray, /debug, _extra = e)
if ~isa(camera, 'DGGgrCam') then $
   camera = DGGgrCAM_OpenCV(/gray, _extra = e)
if ~isa(camera, 'DGGgrCam') then $
   camera = DGGgrCAM(/gray, dimensions = [640, 480])

;; SLM to project the CGH
slm = DGGhotSLM()
if ~isa(slm, 'DGGhotSLM') then begin
   message, 'Could not create an SLM object', /inf
   return
endif

;; Viper object for illumination
illumination = DGGhwViper()

;; Prior object for stage control
foreach device, file_search('/dev/ttyUSB*') do begin
   stage = DGGhwPrior(device, dx = 10, dy = 10, dz = 1, /quiet)
   if isa(stage, 'DGGhwPrior') then break
endforeach

;; IPGLaser object for trapping
foreach device, file_search('/dev/ttyUSB*') do begin
   laser = DGGhwIPGlaser(device, /quiet)
   if isa(laser, 'DGGhwIPGlaser') then break
endforeach

;; Thorlabs SC10 shutter controller
foreach device, file_search('/dev/ttyUSB*') do begin
   shutter = DGGhwShutter(device, /quiet)
   if isa(shutter, 'DGGhwShutter') then break
endforeach

;;; Objects that operate on data
;; Trapping pattern
traps = DGGhotTrappingPattern()

;; CGH pipeline to compute holograms for the pattern
if isa(cgh_object, 'String') then $
   cgh = obj_new(cgh_object)
if ~isa(cgh, 'DGGhotCGH') then $
   cgh = DGGhotCGHgpu()
if ~isa(cgh, 'DGGhotCGH') then $
   cgh = DGGhotCGHfast()
if ~isa(cgh, 'DGGhotCGH') then begin
   message, 'Could not create a CGH pipeline', /inf
   return
endif
camera.getproperty, dimensions = dimensions
cgh.setproperty, rc = [dimensions/2., 0.]
cgh.setproperty, slm = slm

traps.setproperty, cgh = cgh

;; Recorder object for recording videos
;; XXX pass options to recorder object
recorder = DGGgrRecorder(nthreads = 10, dir = '/tmp', fmt = 0)
if ~isa(recorder, 'DGGgrRecorder') then begin
   message, 'Could not create a video recorder object', /inf
   return
endif

;;; Graphics object hierarchy for video with overlayed trapping
;;; pattern

;; screen for viewing images
;; NOTE: camera objects are instances of IDLgrImage
camera.getproperty, dimensions = dimensions
image = IDLgrView(viewplane_rect = [0L, 0, dimensions])
imodel = IDLgrModel()
imodel.add, camera
image.add, imodel

;; trap objects are displayed on a transparent overlay
overlay = IDLgrView(viewplane_rect = [0L, 0, dimensions], /transparent)
overlay.add, traps

;; The scene consists of the image overlayed with the trapping pattern
scene = IDLgrScene()
scene.add, image
scene.add, overlay

;;; widget hierarchy for the user interface
;; top level widget
wtlb = widget_base(/column, title = 'fab', mbar = bar, tlb_frame_attr = 5)

;; menu bar
file_menu = widget_button(bar, value = 'File', /menu)
void = widget_button(file_menu, value = 'Clear', $
                     EVENT_PRO = 'fab_file', UVALUE = 'CLEAR')
void = widget_button(file_menu, value = 'Record to ...', $
                     EVENT_PRO = 'fab_file', UVALUE = 'RECDIR')
void = widget_button(file_menu, value = 'Quit', $
                     EVENT_PRO = 'fab_file', UVALUE = 'QUIT')

cal_menu = widget_button(bar, value = 'Calibration',  /menu)
void = widget_button(cal_menu, value = 'Save',    $
                     EVENT_PRO = 'fab_calibrate', UVALUE = 'SAVE')
void = widget_button(cal_menu, value = 'Save As ...',         $
                     EVENT_PRO = 'fab_calibrate', UVALUE = 'SAVEAS')
void = widget_button(cal_menu, value = 'Restore', $
                     EVENT_PRO = 'fab_calibrate', UVALUE = 'RESTORE')
void = widget_button(cal_menu, value = 'Read ...', $
                     EVENT_PRO = 'fab_calibrate', UVALUE = 'READ')
void = widget_button(cal_menu, value = 'Clear Calibration',   $
                     EVENT_PRO = 'fab_calibrate', UVALUE = 'CLEAR')
void = widget_button(cal_menu, value = 'Calibrate XY',        $
                     EVENT_PRO = 'fab_calibrate', UVALUE = 'XY')
;void = widget_button(cal_menu, value = 'Calibrate Aperture',  $
;                     EVENT_PRO = 'fab_calibrate', UVALUE = 'APERTURE')
;void = widget_button(cal_menu, value = 'Calibrate Phase',     $
;                     EVENT_PRO = 'fab_calibrate', UVALUE = 'PHASE')

prp_menu = widget_button(bar, value = 'Properties', /menu)
void = widget_button(prp_menu, value = 'Traps ...', $
                     EVENT_PRO = 'fab_propertysheet', UVALUE = 'TRAPS')
void = widget_button(prp_menu, value = 'CGH ...',    $
                     EVENT_PRO = 'fab_propertysheet', UVALUE = 'CGH')
void = widget_button(prp_menu, value = 'Camera ...', $
                     EVENT_PRO = 'fab_propertysheet', UVALUE = 'CAMERA')

;;; optional hardware
if isa(illumination) then $
void = widget_button(prp_menu, value = 'Illumination ...',  $
                     EVENT_PRO = 'fab_propertysheet', UVALUE = 'ILLUMINATION')
if isa(laser) then $
void = widget_button(prp_menu, value = 'Laser ...', $
                     EVENT_PRO = 'fab_propertysheet', UVALUE = 'LASER')
if isa(shutter) then $
void = widget_button(prp_menu, value = 'Shutter ...', $
                     EVENT_PRO = 'fab_propertysheet', UVALUE = 'SHUTTER')
if isa(stage) then $
void = widget_button(prp_menu, value = 'Stage ...', $
                     EVENT_PRO = 'fab_propertysheet', UVALUE = 'STAGE')

void = widget_button(prp_menu, value = 'Recorder ...', $
                     EVENT_PRO = 'fab_propertysheet', UVALUE = 'RECORDER')

;;; Help menu
help_menu = widget_button(bar, value = 'Help', /menu)
void = widget_button(help_menu, value = 'About fab', $
                     EVENT_PRO = 'fab_help', UVALUE = 'ABOUT')
void = widget_button(help_menu, value = 'Instructions', $
                     EVENT_PRO = 'fab_help', UVALUE = 'USAGE')
void = widget_button(help_menu, value = 'Calibration', $
                     EVENT_PRO = 'fab_help', UVALUE = 'CALIBRATION')
void = widget_button(help_menu, value = 'Recording', $
                     EVENT_PRO = 'fab_help', UVALUE = 'RECORD')

;; window for drawing images and traps
;wscreenbase = widget_base(wtlb, event_pro = 'fab_gui_event', /row)
wscreen = widget_draw(wtlb, $
                      xsize = dimensions[0], $  ; geometry
                      ysize = dimensions[1], $
                      graphics_level = 2,    $  ; object graphics
                      /button_events,        $  ; events
                      /wheel_events,         $
                      keyboard_events = isa(stage))

;; status line
wstatusline = widget_base(wtlb, /row)
wstatus = widget_text(wstatusline, value = 'Status', xsize = 60)
void = widget_button(wstatusline, value = 'Record', EVENT_PRO = 'fab_record')

;; realize the widget hierarchy
widget_control, wtlb, /realize

;; create the state structure for the widget hierarchy
;      a draw screen's object representation is available
;      only after the draw widget is realized
widget_control, wscreen, get_value = screen
screen->setproperty, graphics_tree = scene

objects = {fabobjects,                 $
           screen:       screen,       $
           camera:       camera,       $
           illumination: illumination, $
           stage:        stage,        $
           laser:        laser,        $
           shutter:      shutter,      $
           cgh:          cgh,          $
           slm:          slm,          $
           overlay:      overlay,      $
           traps:        traps,        $
           recorder:     recorder      $
          }

widgets = {fabwidgets,       $
           tlb:    wtlb,     $  ; top-level widget base
           screen: wscreen,  $  ; draw widget
           status: wstatus,  $  ; status bar
           prop:   0L,       $  ; property sheet (when instantiated)
           help:   0L        $  ; help browser (when instantiated)
          }

seed = long(systime(1))         ; seed for random number generator

; the state structure
s = {fabstate,             $
     o:         objects,   $  ; objects composing the instrument
     w:         widgets,   $  ; widget references for managing events
     timer:     timer,     $  ; time between snapshots [seconds]
     seed:      seed,      $  ; seed for random number generator
     selected:  ptr_new(), $  ; the group on which to operate
     action:    0,         $  ; 2: translating, 3: rotating, 4: grouping
     roi:       ptr_new(), $  ; region of interest
     calfile:   calfile,   $  ; file for saving calibration constants
     recording: 0          $  ; flag when recording
    }

ps = ptr_new(s, /no_copy)       ; pointer to state structure

;; register the state structure with the top-level widget
widget_control, wtlb, set_uvalue = ps

;; start the event manager
xmanager, 'fab', wtlb, /no_block, cleanup = 'fab_cleanup'

;; start processing images
widget_control, wtlb, timer = 0.

;; restore calibration constants
fab_readcalibration, ps

end
