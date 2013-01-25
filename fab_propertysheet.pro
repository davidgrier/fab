;+
; NAME:
;    fab_propertysheet
;
; PURPOSE:
;    Create a propertysheet tailored for FAB objects
;
; MODIFICATION HISTORY:
; 04/11/2011 Written by David G. Grier, New York University
; 10/13/2011 DGG Fixed crash when last trap is deleted.
; 11/04/2011 DGG Minor fix to refresh method.
; 12/10/2011 DGG Added support for shutter properties.
;    Added COMPILE_OPT.
;
; Copyright (c) 2011, David G. Grier
;-

;;;;;
;
; FAB_PROPERTYSHEET_XSIZE
;
; Set the width of a property sheet
;
function fab_propertysheet_xsize, objarray

COMPILE_OPT IDL2, HIDDEN

ncols = (n_elements(objarray) > 1) + 1
return, 13 * ncols
end

;;;;;
;
; FAB_PROPERTYSHEET_RELOAD
;
; Reload properties for an object that may have changed
;
pro fab_propertysheet_reload, s

COMPILE_OPT IDL2, HIDDEN

if ((*s).w.prop eq 0) then return

widget_control, (*s).w.prop, get_value = obj
if ~isa(obj) or isa(obj, 'DGGhotTrap') or isa(obj, /ARRAY) then begin
   (*s).o.traps->getproperty, traps = traps
   widget_control, (*s).w.prop, set_value = traps
   xsize = fab_propertysheet_xsize(traps)
   ysize = isa(traps) ? n_elements(traps[0].queryproperty()) - 1 : 0
   widget_control, (*s).w.prop, XSIZE = xsize, YSIZE = ysize
endif

end

;;;;;
;
; FAB_PROPERTYSHEET_REFRESH
;
; Refresh properties that may have changed for an existing object
; NOTE: no perceived effect if one object is being displayed but
; another calls for a refresh event.
;
pro fab_propertysheet_refresh, s

COMPILE_OPT IDL2, HIDDEN

if (*s).w.prop then $
   widget_control, (*s).w.prop, /refresh_property
end

;;;;;
;
; FAB_PROPERTYSHEET_UPDATE
;
; Update object properties in response to user input
;
pro fab_propertysheet_update, event

COMPILE_OPT IDL2, HIDDEN

if (event.type eq 0) then begin
   value = widget_info(event.ID, COMPONENT = event.component, $
                       PROPERTY_VALUE = event.identifier)
   event.component->SetPropertyByIdentifier, event.identifier, value
endif
 
end
 
;;;;;
;
; FAB_PROPERTYSHEET_EVENT
;
; Handle resize events and quit button
;
pro fab_propertysheet_event, event

COMPILE_OPT IDL2, HIDDEN

case tag_names(event, /structure_name) of
   'WIDGET_BUTTON': begin
      widget_control, event.top, /destroy
   end
   else: begin
      widget_control, event.top, get_uvalue = s
      widget_control, (*s).w.prop, SCR_XSIZE = event.x, SCR_YSIZE = event.y
   end
endcase

end

;;;;;
;
; FAB_PROPERTYSHEET_CLEANUP
;
; Inform calling program that the propertysheet is closed
;
pro fab_propertysheet_cleanup, wid

COMPILE_OPT IDL2, HIDDEN

widget_control, wid, get_uvalue = s
if ptr_valid(s) then $
   (*s).w.prop = 0L
end

;;;;;
;
; FAB_PROPERTYSHEET
;
; The main routine
;
pro fab_propertysheet, fab_event, refresh = refresh, reload = reload

COMPILE_OPT IDL2

if keyword_set(refresh) then begin
   fab_propertysheet_refresh, fab_event
   return
endif

if keyword_set(reload) then begin
   fab_propertysheet_reload, fab_event
   return
endif

widget_control, fab_event.top, get_uvalue = s
widget_control, fab_event.id,  get_uvalue = uval

case uval of
   'TRAPS' : begin
      (*s).o.traps->getproperty, traps = traps
      obj = traps
   end

   'CGH' : obj = (*s).o.cgh

   'CAMERA' : obj = (*s).o.camera

   'RECORDER' : obj = (*s).o.recorder

   'STAGE' : obj = (*s).o.stage

   'ILLUMINATION': obj = (*s).o.illumination

   'LASER': obj = (*s).o.laser

   'SHUTTER': obj = (*s).o.shutter

   else: return
endcase

xsize = fab_propertysheet_xsize(obj)

;;; Property sheet already realized -- display new object
if ((*s).w.prop ne 0) then begin
   widget_control, (*s).w.prop, set_value = obj
   widget_control, (*s).w.prop, XSIZE = xsize
   return
endif

;;; Otherwise create a new property sheet
base = WIDGET_BASE(/TLB_SIZE_EVENT, TITLE = 'FAB Property Sheet', /COLUMN)

nentries = n_elements(obj)

prop = WIDGET_PROPERTYSHEET(base, VALUE = obj, $
                            EVENT_PRO = 'fab_propertysheet_update', $
                            /FRAME, $
                            XSIZE = xsize)

done = WIDGET_BUTTON(base, VALUE = 'DONE', UVALUE = 'DONE')

(*s).w.prop = prop
widget_control, base, set_uvalue = s, /no_copy
 
; Activate the widgets.
WIDGET_CONTROL, base, /REALIZE
 
XMANAGER, 'fab_propertysheet', base, /NO_BLOCK, $
          group_leader = fab_event.top, $
          cleanup = 'fab_propertysheet_cleanup'
end
