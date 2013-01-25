;+
; NAME:
;    DGGhotSLM
;
; PURPOSE:
;    Object class for transmitting computed holograms to a
;    spatial light modulator whose interface is implemented
;    with an X-Window display.
;
; CATEGORY:
;    Computational holography, hardware control, object graphics
;
; PROPERTIES:
;    DATA         [  S] byte-valued hologram to be transmitted to the SLM.
;
;    DEVICE_NAME  [IG ] Name of the X-Window display.  Default: :0.1
;        If the display cannot be opened, a separate window is opened
;        on the current display device.
;
;    DIM:         [IG ] [w,h] dimensions of the SLM. Default: [512, 512]
;
; METHODS:
;    DGGhotSLM::SetProperty
;    DGGhotSLM::GetProperty
;
;    DGGhotSLM::Project
;        Display the current hologram on the device
;
; NOTES:
;    Implement hardware controls (gamma, e.g.)
;
; MODIFICATION HISTORY:
; 01/26/2011 Written by David G. Grier, New York University
; 02/02/2011 DGG removed RC and MAT calibration constants into
;    the definition of the DGGhotCGH class.  Added COMPILE_OPT.
; 11/04/2011 DGG updated object creation syntax.
; 12/09/2011 DGG inherit IDL_Object.  Remove KC.  Documentation fixes.
; 05/04/2012 DGG check that DIM is a number in Init
;
; Copyright (c) 2011-2012, David G. Grier
;-

;;;;;
;
; DGGhotSLM::Project
;
; Display the current data on the SLM
;
pro DGGhotSLM::Project

COMPILE_OPT IDL2, HIDDEN

self.slm.draw
end

;;;;;
;
; DGGhotSLM::SetProperty
;
; Set SLM properties
;
pro DGGhotSLM::SetProperty, data = data

COMPILE_OPT IDL2, HIDDEN

if n_elements(data) eq self.dim[0] * self.dim[1] then begin
   self.image.setproperty, data = data
   self.slm.draw
endif

end

;;;;;
;
; DGGhotSLM::GetProperty
;
; Get SLM properties
;
pro DGGhotSLM::GetProperty, device_name = device_name, $
                            dim = dim
                        
COMPILE_OPT IDL2, HIDDEN
    
device_name = self.device_name
dim = self.dim

end

;;;;;
;
; DGGhotSLM::FindDevice
;
; Return a good guess for the physical SLM device.
; Assume for now that SLM is attached as an X display.
;
function DGGhotSLM::FindDevice, device_name = device_name

COMPILE_OPT IDL2, HIDDEN

monitors = IDLsysMonitorInfo()

nm = monitors.getnumberofmonitors()
names = monitors.getmonitornames()
if nm le 1 then begin           ; single-head or no display: fake SLM
   self.device_name = names
   self.dim = [512L, 512]
endif else begin
   self.device_name = ''
   if n_elements(device_name) eq 1 then begin ; looking for a specific monitor
      slm = where(names eq device_name, nfound)
      if (nfound eq 0) then begin
         obj_destroy, monitors
         return, 1
      endif
   endif else $                 ; use secondary monitor
      slm = (monitors.getprimarymonitorindex() + 1) mod 2
   self.device_name = names[slm]
   rect = monitors.getrectangles()
   self.dim = rect[[2, 3], slm] - rect[[0, 1], slm]
endelse

obj_destroy, monitors

return, 0
end

;;;;;
;
; DGGhotSLM::Init
;
function DGGhotSLM::Init, device_name = device_name, $
                          dim = dim

COMPILE_OPT IDL2, HIDDEN

if isa(dim, /number) and n_elements(dim) eq 2 then $  ; asking for a fake SLM
   self.dim = dim $
else $                          ; look for a real SLM
   if (self.finddevice(device_name = device_name) ne 0) then $
      return, 0

self.wslm = widget_base(title = 'SLM', $
                        resource_name = 'SLM', $
                        display_name = self.device_name)
wdraw = widget_draw(self.wslm, $
                    xsize = self.dim[0], $
                    ysize = self.dim[1], $
                    graphics_level = 2)
widget_control, self.wslm, /realize
widget_control, wdraw, get_value = slm
self.slm = slm

data = bytarr(self.dim[0], self.dim[1])
self.image = IDLgrImage(data, /no_copy)

model = IDLgrModel()
model.add, self.image

view = IDLgrView(viewplane_rect = [0., 0, self.dim])
view.add, model

self.slm.setproperty, graphics_tree = view

return, 1
end

;;;;;
;
; DGGhotSLM::Cleanup
;
; Free resources used for SLM object
;
pro DGGhotSLM::Cleanup

COMPILE_OPT IDL2, HIDDEN

widget_control, self.wslm, /destroy

end

;;;;;
;
; DGGhotSLM__define
;
; Define an object that represents a spatial light modulator.
; Subclassed from IDLgrWindow
;
pro DGGhotSLM__define

COMPILE_OPT IDL2

struct = {DGGhotSLM, $
          inherits IDL_Object,       $
          device_name: '',           $ ; name of SLM device
          dim:         [512L, 512],  $ ; dimensions
          wslm:        0L,           $ ; top-level widget
          slm:         obj_new(),    $ ; object reference to SLM widget
          image:       obj_new()     $ ; image object for hologram
         }
end
