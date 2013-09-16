;+
; NAME:
;    DGGgrCam
;
; PURPOSE:
;    Object class for acquiring and displaying images from a camera.
;    This is the basic video camera class from which should be
;    inherited by classes that provide support for specific categories
;    of cameras.
;
; CATEGORY:
;    Image acquisition, hardware control, object graphics
;
; SYNTAX:
;    obj = OBJ_NEW('DGGgrCam' [, imagedata] [, PROPERTY=value])
;
; SUPERCLASSES
;    IDLgrImage
;    IDL_Object
;
; PROPERTIES:
;    DIMENSIONS: [w,h] dimensions of image (pixels)
;    GRAYSCALE: if set, images should be cast to grayscale.
;    TIMESTAMP: Double-precision system time at which frame was acquired.
;
; METHODS:
;    DGGgrCam::GetProperty
;
;    DGGgrCam::SetProperty
;
;    DGGgrCam::Snap: Take a picture and transfer it to the underlying 
;        IDLgrImage
;
;    DGGgrCam::Snap(): Take a picture, transfer it to the underlying 
;        IDLgrImage, and then return the image data from the Image object.
;
;    DGGgrCam::Image(): Returns image data from the underlying image object.
;
;    DGGgrCam::Reset: Reset the capture stream.
;
; NOTES:
;    Proper support for color.
;    Controls with ranges
;
; MODIFICATION HISTORY:
; 01/20/2011 Written by David G. Grier, New York University
; 02/01/2011 DGG DGGgrCam::Snap() now respects the image's
;     ORDER keyword.
; 02/16/2011 DGG added DGGgrCam::Reset
; 03/23/2011 DGG use _ref_extra in Set/GetProperty and Init
; 03/31/2011 DGG implemented DGGgrCam::Write
; 04/29/2011 DGG introduced hooks for registered properties.
; 10/14/2011 DGG DGGgrCam::Image().  Used for Snap().
; 05/16/2012 DGG Inherits IDL_Object for implicit Get/SetProperty
; methods.
; 05/24/2012 DGG Snap() method requires order from IDLgrImage
; 09/16/2013 DGG Support for timestamps.  Simplify object syntax.
; 
; Copyright (c) 2011-2013 David G. Grier
;-

;;;;;
;
; DGGgrCam::Reset
; 
; Reset the capture stream.  Useful for synchronizing image
; acquisition with external events in cameras that implement
; deep image buffers.
;
pro DGGgrCam::Reset

COMPILE_OPT IDL2, HIDDEN

; nothing to do -- should be overridden by subclasses
end

;;;;;
;
; DGGgrCam::Image()
;
; Returns current image data
;
function DGGgrCam::Image

COMPILE_OPT IDL2, HIDDEN

if self.order eq 0 then $
   return, *self.data

ndx = (self.grayscale) ? 2 : 3
return, reverse(*self.data, ndx)
end

;;;;;
;
; DGGgrCam::Snap()
;
; Special function to return the data in the IDLgrImage object
;
function DGGgrCam::Snap

COMPILE_OPT IDL2, HIDDEN

self.snap
return, self.image()
end

;;;;;
;
; DGGgrCam::Snap
;
; Transfer camera data to the IDLgrImage object.
; NOTE: This should be overridden by instances that have real cameras
;
pro DGGgrCam::Snap

COMPILE_OPT IDL2, HIDDEN

; Blank image
;data = bytarr(self.dimensions[0], self.dimensions[1])

; Poisson statistics makes a "slow" camera
;data = byte(randomu(seed, self.dimensions[0],self.dimensions[1], poisson = 127))

; Uniformly distributed random values
data = byte(255*randomu(seed, self.dimensions[0], self.dimensions[1]))
self.timestamp = systime(1)
self.IDLgrImage::SetProperty, data = data
end

;;;;;
;
; DGGgrCam::Write
;
; Save current image to a file
;
pro DGGgrCam::Write, filename, format = format

COMPILE_OPT IDL2, HIDDEN

if ~isa(filename, 'STRING') then return

if isa(format, 'STRING') then $
   write_image, filename, self.image(), format $
else $
   write_gdf, *self.image(), filename
end

;;;;;
;
; DGGgrCam::SetProperty
;
; Set properties of the underlying IDLgrImage objects
;
pro DGGgrCam::SetProperty, grayscale = grayscale, $
                           debug = debug, $
                           _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self->IDLgrImage::SetProperty, _extra = re

if arg_present(grayscale) then $
   self.grayscale = keyword_set(grayscale)

if arg_present(debug) then $
   self.debug = keyword_set(debug)

end

;;;;;
;
; DGGgrCam::GetProperty
;
; Get properties of the underlying IDLgrImage objects
;
pro DGGgrCam::GetProperty, grayscale = grayscale, $
                           timestamp = timestamp, $
                           debug = debug, $
                           _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self->IDLgrImage::GetProperty, _extra = re

if arg_present(grayscale) then $
   grayscale = self.grayscale

if arg_present(timestamp) then $
   timestamp = self.timestamp

if arg_present(debug) then $
   debug = self.debug

end

;;;;;
;
; DGGgrCam::Cleanup
;
; Handled by IDLgrImage::Cleanup
;
pro DGGgrCam::Cleanup

COMPILE_OPT IDL2, HIDDEN

self->IDLgrImage::Cleanup
end

;;;;;
;
; DGGgrCam::Init
;
; Define the Image object and add it to the underlying
; Model.
;
function DGGgrCam::Init, imagedata, $
                         grayscale = grayscale, $
                         debug = debug, $
                         _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

if isa(imagedata, /NUMBER, /ARRAY) then $
   ok = self->IDLgrImage::Init(imagedata, _extra = re) $
else $
   ok = self->IDLgrImage::Init(_extra = re)
if ~ok then $
   return, 0B

if self.dimensions[0] eq 0 then $
   self.dimensions = [640, 480]

self.grayscale = keyword_set(grayscale)
self.debug = keyword_set(debug)

self.name = 'DGGgrCam'
self.description = 'Camera'
self->registerproperty, 'name', /STRING, NAME = 'NAME', /HIDE

return, 1
end

;;;;;
;
; DGGgrCam__define
;
; Define a generic (non-functional) video camera object
; that returns a blank "video" frame.
;
pro DGGgrCam__define

COMPILE_OPT IDL2

struct = {DGGgrCam, $
          inherits IDLgrImage, $
          inherits IDL_Object, $
          timestamp: 0D,       $ ; time at which last frame was acquired
          grayscale: 0L,       $ ; acquire grayscale image
          debug:     0L        $ ; internal variable for hardware interface
         }
end
