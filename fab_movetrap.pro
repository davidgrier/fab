;+
; NAME:
;    fab_movetrap
;
; PURPOSE:
;    Move an optical trap or a group of traps 
;    along a predefined trajectory at a predefined speed
;
; CATEGORY:
;    Optical trapping, equipment control
;
; CALLING SEQUENCE:
;    fab_movetrap, trap, trajectory, [tdwell]
;
; INPUTS:
;    trap: reference to an object of type DGGhotTrap or DGGhotTrapGroup
;
;    trajectory: [ndims,npts] array of positions along the
;        desired path [pixels]
;        ndims may be 2, for motion in the plane, or 3.
;        nsteps may take any value
;
; OPTIONAL INPUTS:
;    tdwell: time to dwell at each node of the trajectory [seconds]
;        Default: tmin
;
; KEYWORD PARAMETERS:
;    smax: maximum displacement in one step [pixels]
;        Default: 1
;
;    tmin: minimum dwell time at each step [seconds]
;        Default: 0.1
;
;    u: desired speed [pixels/second]
;        Default: maximum speed = smax/tmin
;
; REQUIREMENTS:
;    Calls CW_PROGRESS, written by Robert Dimeo
;    http://www.ncnr.nist.gov/staff/dimeo/idlprograms/cw_progress.pro
;
; SIDE EFFECTS:
;    Opens a widget that displays progress.
;    If TRAP is activated in a running FAB session, this routine
;    will actually move the trap.  During motion, the trap's state
;    is set to 'immutable' to prevent user interaction from
;    interfering with programmed motion.
;
; PROCEDURE:
;    Uses object reference to update trap on a schedule set by
;    timer events.
;
; EXAMPLE:
;    IDL> traps = fab_gettraps()            ; get the active traps
;    IDL> fab_movetrap, trap[0], [100, 100] ; move fist trap to [100, 100] 
;
; MODIFICATION HISTORY:
; 05/17/2012 Written by David G. Grier, New York University
; 06/12/2012 DGG Operate on DGGhotTrapGroup as well as DGGhotTrap.
;    Enables rigid simultaneous motion of multiple traps.
;
; Copyright (c) 2012 David G. Grier
;-

pro fab_movetrap_event, event

COMPILE_OPT IDL2, HIDDEN

widget_control, event.top, get_uvalue = s

case tag_names(event, /structure_name) of
   'WIDGET_BUTTON': begin
      widget_control, event.id, get_uvalue = uval
      case uval of
         'STOP': widget_control, event.top, /destroy
         'PAUSE': begin
            if (*s).pause then begin
               widget_control, event.id, set_value = ' Pause '
               (*s).pause = 0
               widget_control, event.top, timer = 0.
            endif else begin
               widget_control, event.id, set_value = 'Resume'
               (*s).pause = 1 - (*s).pause
            endelse
         end
      endcase
   end

   'WIDGET_TIMER': begin
      if (*s).pause then break  ; don't do anything if paused

      n = (*s).n                 ; index of target node
      dr = (*s).r[*,n] - (*s).rc ; displacement to target node
      ds = sqrt(total(dr^2))     ; distance to target node
      if ds gt (*s).dsmax then begin ; cannot reach node
         dostep = 1                  ; ... so this is a step
         widget_control, event.top, timer = (*s).tstep
         dr *= (*s).dsmax/ds         ; scale to maximum step size
         ds = (*s).dsmax
      endif else begin          ; reached node
         dostep = 0             ; ... so not a step
         widget_control, event.top, timer = (*s).tnode            
         (*s).n++               ; update target
      endelse
      (*s).rc += dr                       ; update position
      (*s).trap.moveby, dr, /override     ; move trap
      (*s).s += ds                        ; increment total displacement
      widget_control, (*s).progress, set_value = (*s).s/(*s).smax

      if dostep then begin
         if isa((*s).step_pro, 'string') then $
            call_procedure, (*s).step_pro, s
      endif else begin
         if isa((*s).node_pro, 'string') then $
            call_procedure, (*s).node_pro, s
      endelse

      if (*s).n gt (*s).nmax then $ ; reached last node
         widget_control, event.top, /destroy
   end
endcase

end

pro fab_movetrap_cleanup, base

COMPILE_OPT IDL2, HIDDEN

widget_control, base, get_uvalue = s, /no_copy
if isa((*s).trap, 'DGGhotTrapGroup') then $
   (*s).trap.setproperty, state = (*s).ostate $
else if isa((*s).trap.parent, 'DGGhotTrapGroup') then $
   (*s).trap.parent.setproperty, state = (*s).ostate
ptr_free, s
end

pro fab_movetrap, trap, rn, tdwell, $
                  dsmax = dsmax, $
                  tmin = tmin, $
                  u = u, $
                  step_pro = step_pro, $
                  node_pro = node_pro

COMPILE_OPT IDL2

ostate = 0
if isa(trap, 'DGGhotTrapGroup') then begin
   trap.getproperty, state = ostate 
   trap.setproperty, state = 0
endif else if isa(trap, 'DGGhotTrap') then begin
   if isa(trap.parent, 'DGGhotTrapGroup') then begin
      trap.parent.getproperty, state = ostate
      trap.parent.setproperty, state = 0
   endif
endif else $
   return

;;; create trajectory
if ~isa(rn, /number, /array) then $
   return
sz = size(rn)
if sz[0] eq 1 then begin
   ndim = sz[1]
   nmax = 1
endif else begin
   ndim = sz[1]
   nmax = sz[2]
endelse
if ndim lt 2 or ndim gt 3 then begin
   message, 'trajectory must be two- or three-dimensional', /inf
   return
endif

trap.getproperty, rc = rc                      ; present location
r = [[rc[0:ndim-1]],[rn]]                      ; trajectory
smax = total(sqrt(total((r[*,1:*] - r)^2, 1))) ; total length of trajectory

if ~isa(dsmax, /number, /scalar) then $
   dsmax = 1.

if ~isa(tmin, /number, /scalar) then $
   tmin = 0.1

umax = dsmax/tmin

if ~isa(u, /number, /scalar) then $
   u = umax $
else $
   u = u < umax > 0

if n_params() eq 3 then begin
   if isa(tdwell, /number, /scalar) then begin
      tnode = tdwell > tmin
   endif else begin
      message, 'tdwell must be a number', /inf
      return
   endelse 
endif else $
   tnode = tmin

if isa(step_pro, 'string') then begin
   fn = file_which(step_pro+'.pro', /include_current_dir)
   if strlen(fn) le 0 then begin
      message, step_pro+'.pro is not in your IDL_PATH', /inf
      return
   endif
   file_compile, fn, error = err, errmsg = msg
   if err ne 0 then begin
      message, 'Resolving STEP_PRO: ' + msg, /inf
      return
   endif
endif else $
   step_pro = -1

if isa(node_pro, 'string') then begin
   fn = file_which(node_pro+'.pro', /include_current_dir)
   if strlen(fn) le 0 then begin
      message, node_pro+'.pro is not in your IDL_PATH', /inf
      return
   endif
   file_compile, fn, error = err, errmsg = msg
   if err ne 0 then begin
      message, 'Resolving NODE_PRO: ' + msg, /inf
      return
   endif
endif else $
   node_pro = -1

fab = getfab()                  ; running fab instance (if any)

;;; widget hierarchy
base = widget_base(/column, title = 'moving trap')
progress = cw_progress(base, value = 0., /blue, xsize = 150, bg_color = 'white')
buttons = widget_base(base, /row)
stop  = widget_button(buttons, value = 'Stop!', uvalue = 'STOP')
pause = widget_button(buttons, value = ' Pause ', uvalue = 'PAUSE')
widget_control, base, /realize

;;; state structure
s = {trap: trap, $             ; object reference of trap to move
     r: r, $                   ; trajectory
     rc: r[*,0], $             ; present position
     n: 1, $                   ; index of target node
     nmax: nmax, $             ; number of nodes in complete trajectory
     dsmax: dsmax, $           ; maximum displacement in each step
     s: 0., $                  ; distance travelled
     smax: smax, $             ; target distance
     tstep: tmin, $            ; time to wait between steps
     tnode: tnode, $           ; time to wait at each node
     step_pro: step_pro, $     ; procedure to run at each step
     node_pro: node_pro, $     ; procedure to run at each node
     progress:progress, $      ; widget ID of progress bar
     pause:0, $                ; flag: set if paused
     fab: fab, $               ; pointer to running fab instance
     ostate:ostate }           ; initial state of the trap or group

ps = ptr_new(s, /no_copy)

widget_control, base, set_uvalue = ps, /no_copy

;;; start loop
xmanager, 'fab_movetrap', base, /no_block, cleanup = 'fab_movetrap_cleanup'

widget_control, base, timer = 0.

end
