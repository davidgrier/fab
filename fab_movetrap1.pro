;+
; NAME:
;    fab_movetrap
;
; PURPOSE:
;    Move an optical trap along a predefined trajectory at
;    a predefined speed
;
; CATEGORY:
;    Optical trapping, equipment control
;
; CALLING SEQUENCE:
;    fab_movetrap, trap, trajectory, dwell
;
; INPUTS:
;    trap: reference to an object of type DGGhotTrap
;
;    trajectory: [ndims,nsteps] array of positions along the
;        desired path [pixels]
;        ndims may be 2, for motion in the plane, or 3.
;        nsteps may take any value
;
; OPTIONAL INPUTS:
;    tdwell: time to dwell at each node of the trajectory [seconds]
;        Default: tmin
;
; KEYWORD PARAMETERS:
;    rmax: maximum displacement in one step [pixels]
;        Default: 1
;
;    tmin: minimum dwell time at each step [seconds]
;        Default: 0.1
;
;    u: desired speed [pixels/second]
;        Default: maximum speed = rmax/tmin
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
      if (*s).pause then break
      ndx = (*s).step
      widget_control, event.top, timer = (*s).q[-1, ndx]
      widget_control, (*s).progress, set_value = ndx/(*s).nsteps
      (*s).trap.rc = (*s).q[0:(*s).ndim-1, ndx]
      if isa((*s).step_pro, 'string') then $
         call_procedure, (*s).step_pro, s
      (*s).step++
      if (*s).step ge (*s).nsteps then $
         widget_control, event.top, /destroy
   end
endcase

end

pro fab_movetrap_cleanup, base

COMPILE_OPT IDL2, HIDDEN

widget_control, base, get_uvalue = s, /no_copy
if isa((*s).trap.parent, 'DGGhotTrapGroup') then $
   (*s).trap.parent.setproperty, state = (*s).ostate
ptr_free, s
end

pro fab_movetrap, trap, r, tdwell, $
                  rmax = rmax, $
                  tmin = tmin, $
                  u = u, $
                  step_pro = step_pro, $
                  node_pro = node_pro

COMPILE_OPT IDL2

if ~isa(trap, 'DGGhotTrap') then $
   return

ostate = 0
if isa(trap.parent, 'DGGhotTrapGroup') then begin
   trap.parent.getproperty, state = ostate
   trap.parent.setproperty, state = 0
endif

if ~isa(r, /number, /array) then $
   return
sz = size(r)
if sz[0] eq 1 then begin
   ndim = sz[1]
   npts = 1
endif else begin
   ndim = sz[1]
   npts = sz[2]
endelse

if ~isa(rmax, /number, /scalar) then $
   rmax = 1.

if ~isa(tmin, /number, /scalar) then $
   tmin = 0.1

umax = rmax/tmin

if ~isa(u, /number, /scalar) then $
   u = umax $
else $
   u = u < umax > 0

if n_params() eq 3 then begin
   if ~isa(tdwell, /number, /scalar) then $
      return
endif else $
   tdwell = tmin

if isa(step_pro, 'string') then begin
   print, 'step_pro'
   file_compile, step_pro, error = err, errmsg = msg
   if err ne 0 then begin
      message, 'Resolving STEP_PRO: ' + msg, /inf
      return
   endif
endif

if isa(node_pro, 'string') then begin
   file_compile, node_pro, error = err, errmsg = msg
   if err ne 0 then begin
      message, 'Resolving NODE_PRO: ' + msg, /inf
      return
   endif
endif

;;; calculate trajectory
trap.getproperty, rc = rc ; where the trap is now

p = fltarr(ndim, npts+1)
p[*, 0] = rc[0:ndim-1]
p[*, 1:*] = r

q = []
for i = 0, npts-1 do begin
   dp = p[*, i+1] - p[*, i]
   dist = sqrt(total(dp^2))
   nsteps = ceil(dist/rmax)
   if nsteps lt 1 then continue
   dp /= nsteps
   thisq = rebin(findgen(1, nsteps), ndim+1, nsteps)
   for j = 0, ndim-1 do $
      thisq[j, *] = thisq[j, *] * dp[j] + p[j, i]
   thisq[ndim, *] = tmin
   thisq[ndim, -1] = tdwell
   q = [[q], [thisq]]
endfor
nsteps = n_elements(q[0, *])

;;; widget hierarchy
base = widget_base(/column, title = 'moving trap')
prog = cw_progress(base, value = 0., /blue, xsize = 150, bg_color = 'white')
buttons = widget_base(base, /row)
stop = widget_button(buttons, value = 'Stop!', uvalue = 'STOP')
pause = widget_button(buttons, value = ' Pause ', uvalue = 'PAUSE')
widget_control, base, /realize

;;; state structure
s = {q:q, $
     trap:trap, $
     progress:prog, $
     ndim:ndim, $
     step:0., $
     nsteps:nsteps, $
     step_pro: step_pro, $
     node_pro: node_pro, $
     pause:0, $
     ostate:ostate }

ps = ptr_new(s, /no_copy)

widget_control, base, set_uvalue = ps, /no_copy

;;; start loop
xmanager, 'fab_movetrap', base, /no_block, cleanup = 'fab_movetrap_cleanup'

widget_control, base, timer = 0.

end
