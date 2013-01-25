;+
; NAME:
;    fab_propertysheet
;
; PURPOSE:
;    Create a propertysheet tailored for FAB objects
;
; MODIFICATION HISTORY:
; 04/11/2011 Written by David G. Grier, New York University
;
; Copyright (c) 2011, David G. Grier
;-

pro fab_propertyevent, event

COMPILE_OPT IDL2, HIDDEN

help, event

if (event.type eq 0) then begin
   value = widget_info(event.ID, COMPONENT = event.component, $
                       PROPERTY_VALUE = event.identifier)
   event.component->SetPropertyByIdentifier, event.identifier, value
endif
 
end
 
; Handler for property sheet resize event.
pro fab_propertysheet_event, event

COMPILE_OPT IDL2, HIDDEN

prop = widget_info(event.top, FIND_BY_UNAME = 'PropSheet')

case tag_names(event, /structure_name) of
   'WIDGET_TIMER': begin
      widget_control, event.top, timer = 0.5
      widget_control, prop, /refresh_property
   end
   'WIDGET_BUTTON': begin
      widget_control, event.top, /destroy
   end
   else: begin
      widget_control, prop, SCR_XSIZE = event.x, SCR_YSIZE = event.y
   end
endcase

end
 
pro fab_propertysheet, obj, $
                       group_leader = group_leader, $
                       update = update

COMPILE_OPT IDL2

if xregistered('fab_propertysheet') then begin
   message,  'Another property sheet is open already.',  /inf
   return
endif

; Create a base and property sheet.
base = WIDGET_BASE(/TLB_SIZE_EVENT, TITLE = 'FAB Property Sheet', /COLUMN)

nentries = n_elements(obj)

prop = WIDGET_PROPERTYSHEET(base, VALUE = obj, $
                            EVENT_PRO = 'fab_propertyevent', $
                            UNAME = 'PropSheet', $
                            /FRAME, $
                            XSIZE = 14 * (nentries + 1))
done = WIDGET_BUTTON(base, VALUE = "DONE", UVALUE = "DONE")
 
; Activate the widgets.
WIDGET_CONTROL, base, SET_UVALUE = obj, /REALIZE
 
XMANAGER, 'fab_propertysheet', base, /NO_BLOCK, group_leader = group_leader

if keyword_set(update) then $
   widget_control, base, timer = 0.5
end
