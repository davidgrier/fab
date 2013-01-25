;+
; NAME:
;    DGGgrRecorder
;
; PURPOSE:
;    This object saves data files to a specified directory
;    using IDL_IDLBridges to obtain low-latency operation.
;    Its intended use is to save frame-accurate sequences of
;    images for digital video applications.
;
; CATEGORY:
;    Object graphics
;
; PROPERTIES:
;    DIR:      [IGS] String containing directory for saving images
;              Default: './' current directory
;
;    FMT:      [IGS] Integer index of image format in the FORMATS list
;              Default: 0, which corresponds to 'gdf'
;
;    FORMATS:  [ G ] String array of supported formats
;
;    NTHREADS: [IGS] Number of threads for saving images
;              Default: 1
;              Each thread is responsible for saving one image.
;              Increasing the number of threads improves performance
;              by increasing the number of file-save operations that
;              can occur concurrently at the expense of increasing
;              memory requirements.  This reduces the chance of
;              dropped frames.  Performance ultimately depends on the
;              speed of the hardware, however, and adding too many
;              threads can overwhelm hardware and reduce performance.
;               
;    TIMEZONE: [IGS] Offset in hours from GMT, used for timestamps
;              Default: -4
;
; METHODS:
;    NOTE: DGGgrRecorder inherits IDL_Object, and thus can
;        call GetProperty and SetProperty implicitly.
;
;    DGGgrRecorder::GetProperty
;
;    DGGgrRecorder::SetProperty
;
;    DGGgrRecorder::Write
;    SYNTAX:
;        res = DGGgrRecorder::Write(image)
;        
;    INPUT:
;        image: data to be written to the data directory in the
;            selected format with the current timestamp for a file name.
;
;    OUTPUT:
;        res: file name on success, empty string on failure
;
; NOTES:
;    Implement preprocessing: flipx, flipy, grayscale
;
; MODIFICATION HISTORY:
; 10/13/2011: Written by David G. Grier, New York University
; 05/04/2012 DGG Make sure that parameters have the correct type.
; 05/15/2012 DGG Write method returns empty string on failure.
;
; Copyright (c) 2011-2012, David G. Grier
;-

;;;;;
;
; DGGgrRecorder::Write
;
; Save one image to a file
; Return the file name as a string, or an empty string on failure.
;
function DGGgrRecorder::Write, a

fn = self.dir + self.timestamp() + '.' + self.formats[self.fmt]

nbridges = n_elements(*self.bridges)
foreach bridge, *self.bridges do begin
   if bridge.status() eq 0 then begin
      bridge.setvar, 'A', a
      bridge.setvar, 'FN', fn
      bridge.execute, self.cmd, /NOWAIT
      return, fn
   endif
endforeach

return, ''

end

;;;;;
;
; DGGgrRecorder::TimeStamp
;
; returns current system time as a string
;
function DGGgrRecorder::TimeStamp

COMPILE_OPT IDL2, HIDDEN

t = systime(1) + self.timezone * 3600D
dsecs = t - floor(t/86400D) * 86400D
return, string(dsecs, format = '(F012.6)')
end

;;;;;
;
; DGGgrRecorder::MakeCommand
;
; Create the command line for the IDL_IDLBridge
;
pro DGGgrRecorder::MakeCommand

COMPILE_OPT IDL2, HIDDEN

case self.fmt of
   0 : self.cmd = 'write_gdf,  A, FN'
   1 : self.cmd = 'write_bmp,  FN, A'
   2 : self.cmd = 'write_gif,  FN, A'
   3 : self.cmd = 'write_jpeg, FN, A, QUALITY=100' ; order
   4 : self.cmd = 'write_png,  FN, A'
   5 : self.cmd = 'write_ppm,  FN, A'
   6 : self.cmd = 'write_srf,  FN, A' ; order
   7 : self.cmd = 'write_tiff, FN, A' ; compression, orientation
   else: message, self.fmt + ' not a recognized format'
endcase

end

;;;;;
;
; DGGgrRecorder::SetProperty
;
; Set properties of the recorder object
;
pro DGGgrRecorder::SetProperty, dir = dir, $
                                fmt = fmt, $
                                nthreads = nthreads, $
                                timezone = timezone, $
                                _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self.IDLitComponent::SetProperty, _extra = re

if isa(dir, 'String') then begin
   if file_test(dir, /directory, /write) then begin
      self.dir = dir
      if ~stregex(dir, '/$', /boolean) then $
         self.dir += '/'
   endif else begin
      message, 'Cannot open '+dir+' for writing', /inf
      message, 'Continuing to write to '+self.dir, /inf
   endelse
endif

if isa(fmt, /scalar, /number) then begin
   if fmt ge 0 and fmt lt n_elements(self.formats) then begin
      self.fmt = fmt
      self.MakeCommand
   endif
endif

if isa(nthread, /scalar, /number) then begin
   self.FreeBridges
   res = self.AllocateBridges(nthreads)
   if res ne 1 then begin
      message, 'Failed to reallocate threads ... Cleaning up', /inf
      obj_destroy, self
   endif
endif

if isa(timezone, /scalar, /number) then $
   self.timezone = double(timezone)

end

;;;;;
;
; DGGgrRecorder::GetProperty
;
; Get properties of the recorder object
;
pro DGGgrRecorder::GetProperty,  dir = dir, $
                                 fmt = fmt, $
                                 formats = formats, $
                                 nthreads = nthreads, $
                                 timezone = timezone, $
                                 _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self.IDLitComponent::GetProperty, _extra = re

if arg_present(dir) then $
   dir = self.dir

if arg_present(fmt) then $
   fmt = self.fmt

if arg_present(formats) then $
   formats = self.formats

if arg_present(nthreads) then $
   nthreads = n_elements(*self.bridges)

if arg_present(timezone) then $
   timezone = self.timezone

end

;;;;;
;
; DGGgrRecorder::AllocateBridges
;
; Allocate IDL_IDLBridges
;
function DGGgrRecorder::AllocateBridges, nbridges

COMPILE_OPT IDL2, HIDDEN

if nbridges lt 1 then $
   return, 0

bridges = objarr(nbridges)
for i = 0, nbridges-1 do begin
   bridges[i] = IDL_IDLBridge()
   if ~isa(bridges[i]) then $
      return, 0
endfor

if isa(self.bridges) then $
   ptr_free, self.bridges

self.bridges = ptr_new(bridges, /no_copy)

return, 1
end

;;;;;
;
; DGGgrRecorder::FreeBridges
;
; Free up resources used for IDL_IDLBridge objects
;
pro DGGgrRecorder::FreeBridges

COMPILE_OPT IDL2, HIDDEN

if isa(*self.bridges) then begin
   foreach bridge, *self.bridges do begin
      while bridge.status() eq 1 do $
         wait, 0.1
      obj_destroy, bridge
   endforeach
   ptr_free, self.bridges
endif

end

;;;;;
;
; DGGgrRecorder::Init
;
; Initialize the recorder object
;
function DGGgrRecorder::Init, dir = dir, $
                              nthreads = nthreads, $
                              fmt = fmt, $
                              timezone = timezone

COMPILE_OPT IDL2, HIDDEN

if ~self.IDLitComponent::Init() then $
   return, 0

if isa(timezone, /scalar, /number) then $
   self.timezone = double(timezone) $
else $
   self.timezone = -4D

if ~isa(dir, 'String') then $
   dir = './'                   ; default to current working directory
if ~stregex(dir, '/$', /boolean) then $
   dir += '/'
if ~file_test(dir, /directory, /write) then begin
   message, 'Cannot write to '+dir, /inf
   return, 0
endif
self.dir = dir

nbridges = 1
if isa(nthreads, /scalar, /number) then $
    nbridges = long(nthreads)

self.formats = ['gdf', 'bmp', 'gif', 'jpeg', 'png', 'ppm', 'srf', 'tiff']

if isa(fmt, /scalar, /number) then begin
   if fmt ge 0 and fmt lt n_elements(self.formats) then $
      self.fmt = fmt $
   else $
      return, 0
endif else $
   self.fmt = 0

self.MakeCommand
                    
res = self.AllocateBridges(nbridges)

self.name = 'DGGgrRecorder'
self.description = 'Video Recorder'
self->registerproperty, 'name', /STRING, NAME = 'NAME', /HIDE
self->registerproperty, 'dir', /STRING, NAME = 'DIR', SENSITIVE = 0, $
                        DESCRIPTION = 'Recording Directory'
self->registerproperty, 'fmt', ENUMLIST = self.formats, $
                        NAME = 'FMT', DESCRIPTION = 'Image Format'
self->registerproperty, 'nthreads', /INTEGER, VALID_RANGE = [1, 15], $
                        NAME = 'NTHREADS', $
                        DESCRIPTION = 'Number of Threads'
return, res
end

;;;;;
;
; DGGgrRecorder::Cleanup
;
pro DGGgrRecorder::Cleanup

COMPILE_OPT IDL2, HIDDEN

self->FreeBridges

end

;;;;;
;
; DGGgrRecorder__define
;
; Define the object structure for a DGGgrRecorder
;
pro DGGgrRecorder__define

COMPILE_OPT IDL2

struct = {DGGgrRecorder,            $
          inherits  IDL_Object,     $
          inherits  IDLitComponent, $
          bridges:  ptr_new(),      $ ; array of bridge objects
          dir:      '',             $ ; directory for recording images
          fmt:      0,              $ ; file format
          formats:  strarr(8),      $ ; known formats
          timezone: 0D,             $ ; current offset from GMT
          cmd:      ''              $ ; IDL_IDLBridge, execute=cmd
         }
end
