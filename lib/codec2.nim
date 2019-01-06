 {.deadCodeElim: on.}
when defined(windows):
  const
    codec2dll* = "codec2.dll"
elif defined(macosx):
  const
    codec2dll* = "libcodec2.dylib"
else:
  const
    codec2dll* = "libcodec2.so"
## ---------------------------------------------------------------------------*\
##
##   FILE........: codec2.h
##   AUTHOR......: David Rowe
##   DATE CREATED: 21 August 2010
##
##   Codec 2 fully quantised encoder and decoder functions.  If you want use
##   Codec 2, these are the functions you need to call.
##
## \*---------------------------------------------------------------------------
##
##   Copyright (C) 2010 David Rowe
##
##   All rights reserved.
##
##   This program is free software; you can redistribute it and/or modify
##   it under the terms of the GNU Lesser General Public License version 2.1, as
##   published by the Free Software Foundation.  This program is
##   distributed in the hope that it will be useful, but WITHOUT ANY
##   WARRANTY; without even the implied warranty of MERCHANTABILITY or
##   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
##   License for more details.
##
##   You should have received a copy of the GNU Lesser General Public License
##   along with this program; if not, see <http://www.gnu.org/licenses/>.
##

const
  CODEC2_VERSION_MAJOR* = 0
  CODEC2_VERSION_MINOR* = 8
  CODEC2_VERSION_PATCH* = 1
  CODEC2_VERSION* = "0.8.1"

const
  CODEC2_MODE_3200* = 0
  CODEC2_MODE_2400* = 1
  CODEC2_MODE_1600* = 2
  CODEC2_MODE_1400* = 3
  CODEC2_MODE_1300* = 4
  CODEC2_MODE_1200* = 5
  CODEC2_MODE_700* = 6
  CODEC2_MODE_700B* = 7
  CODEC2_MODE_700C* = 8
  CODEC2_MODE_WB* = 9

type
  CODEC2* {.bycopy.} = object


proc codec2_create*(mode: cint): ptr CODEC2 {.cdecl, importc: "codec2_create",
    dynlib: codec2dll.}
proc codec2_destroy*(codec2_state: ptr CODEC2) {.cdecl, importc: "codec2_destroy",
    dynlib: codec2dll.}
proc codec2_encode*(codec2_state: ptr CODEC2; bits: ptr cuchar; speech_in: ptr cshort) {.
    cdecl, importc: "codec2_encode", dynlib: codec2dll.}
proc codec2_decode*(codec2_state: ptr CODEC2; speech_out: ptr cshort; bits: ptr cuchar) {.
    cdecl, importc: "codec2_decode", dynlib: codec2dll.}
proc codec2_decode_ber*(codec2_state: ptr CODEC2; speech_out: ptr cshort;
                       bits: ptr cuchar; ber_est: cfloat) {.cdecl,
    importc: "codec2_decode_ber", dynlib: codec2dll.}
proc codec2_samples_per_frame*(codec2_state: ptr CODEC2): cint {.cdecl,
    importc: "codec2_samples_per_frame", dynlib: codec2dll.}
proc codec2_bits_per_frame*(codec2_state: ptr CODEC2): cint {.cdecl,
    importc: "codec2_bits_per_frame", dynlib: codec2dll.}
proc codec2_set_lpc_post_filter*(codec2_state: ptr CODEC2; enable: cint;
                                bass_boost: cint; beta: cfloat; gamma: cfloat) {.
    cdecl, importc: "codec2_set_lpc_post_filter", dynlib: codec2dll.}
proc codec2_get_spare_bit_index*(codec2_state: ptr CODEC2): cint {.cdecl,
    importc: "codec2_get_spare_bit_index", dynlib: codec2dll.}
proc codec2_rebuild_spare_bit*(codec2_state: ptr CODEC2; unpacked_bits: ptr cint): cint {.
    cdecl, importc: "codec2_rebuild_spare_bit", dynlib: codec2dll.}
proc codec2_set_natural_or_gray*(codec2_state: ptr CODEC2; gray: cint) {.cdecl,
    importc: "codec2_set_natural_or_gray", dynlib: codec2dll.}
proc codec2_set_softdec*(c2: ptr CODEC2; softdec: ptr cfloat) {.cdecl,
    importc: "codec2_set_softdec", dynlib: codec2dll.}
proc codec2_get_energy*(codec2_state: ptr CODEC2; bits: ptr cuchar): cfloat {.cdecl,
    importc: "codec2_get_energy", dynlib: codec2dll.}