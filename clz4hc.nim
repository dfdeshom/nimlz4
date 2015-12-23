{.deadCodeElim: on.}
when defined(windows): 
  const 
    liblz4* = "liblz4.dll"
elif defined(macosx): 
  const 
    liblz4* = "liblz4.dylib"
else: 
  const 
    liblz4* = "liblz4.so.1"

const
  LZ4_STREAMHCSIZE* = 262192
  LZ4_STREAMHCSIZE_SIZET* = (LZ4_STREAMHCSIZE div sizeof((int)))

type
  LZ4_streamHC_t* = object
    table*: array[LZ4_STREAMHCSIZE_SIZET, csize]

#*************************************
#  Block Compression
#************************************

proc LZ4_compress_HC*(src: cstring; dst: cstring; srcSize: cint; maxDstSize: cint;
                     compressionLevel: cint): cint {.cdecl,
    importc: "LZ4_compress_HC", dynlib: liblz4.}
#
#LZ4_compress_HC :
#    Destination buffer 'dst' must be already allocated.
#    Compression completion is guaranteed if 'dst' buffer is sized to handle worst circumstances (data not compressible)
#    Worst size evaluation is provided by function LZ4_compressBound() (see "lz4.h")
#      srcSize  : Max supported value is LZ4_MAX_INPUT_SIZE (see "lz4.h")
#      compressionLevel : Recommended values are between 4 and 9, although any value between 0 and 16 will work.
#                         0 means "use default value" (see lz4hc.c).
#                         Values >16 behave the same as 16.
#      return : the number of bytes written into buffer 'dst'
#            or 0 if compression fails.
#
# Note :
#   Decompression functions are provided within LZ4 source code (see "lz4.h") (BSD license)
#

proc LZ4_sizeofStateHC*(): cint {.cdecl, importc: "LZ4_sizeofStateHC", dynlib: liblz4.}
proc LZ4_compress_HC_extStateHC*(state: pointer; src: cstring; dst: cstring;
                                srcSize: cint; maxDstSize: cint;
                                compressionLevel: cint): cint {.cdecl,
    importc: "LZ4_compress_HC_extStateHC", dynlib: liblz4.}
#
#LZ4_compress_HC_extStateHC() :
#   Use this function if you prefer to manually allocate memory for compression tables.
#   To know how much memory must be allocated for the compression tables, use :
#      int LZ4_sizeofStateHC();
#
#   Allocated memory must be aligned on 8-bytes boundaries (which a normal malloc() will do properly).
#
#   The allocated memory can then be provided to the compression functions using 'void* state' parameter.
#   LZ4_compress_HC_extStateHC() is equivalent to previously described function.
#   It just uses externally allocated memory for stateHC.
#
#*************************************
#  Streaming Compression
#************************************
#
#  LZ4_streamHC_t
#  This structure allows static allocation of LZ4 HC streaming state.
#  State must then be initialized using LZ4_resetStreamHC() before first use.
#
#  Static allocation should only be used in combination with static linking.
#  If you want to use LZ4 as a DLL, please use construction functions below, which are future-proof.
#

proc LZ4_createStreamHC*(): ptr LZ4_streamHC_t {.cdecl,
    importc: "LZ4_createStreamHC", dynlib: liblz4.}
proc LZ4_freeStreamHC*(streamHCPtr: ptr LZ4_streamHC_t): cint {.cdecl,
    importc: "LZ4_freeStreamHC", dynlib: liblz4.}
#
#  These functions create and release memory for LZ4 HC streaming state.
#  Newly created states are already initialized.
#  Existing state space can be re-used anytime using LZ4_resetStreamHC().
#  If you use LZ4 as a DLL, use these functions instead of static structure allocation,
#  to avoid size mismatch between different versions.
#

proc LZ4_resetStreamHC*(streamHCPtr: ptr LZ4_streamHC_t; compressionLevel: cint) {.
    cdecl, importc: "LZ4_resetStreamHC", dynlib: liblz4.}
proc LZ4_loadDictHC*(streamHCPtr: ptr LZ4_streamHC_t; dictionary: cstring;
                    dictSize: cint): cint {.cdecl, importc: "LZ4_loadDictHC",
    dynlib: liblz4.}
proc LZ4_compress_HC_continue*(streamHCPtr: ptr LZ4_streamHC_t; src: cstring;
                              dst: cstring; srcSize: cint; maxDstSize: cint): cint {.
    cdecl, importc: "LZ4_compress_HC_continue", dynlib: liblz4.}
proc LZ4_saveDictHC*(streamHCPtr: ptr LZ4_streamHC_t; safeBuffer: cstring;
                    maxDictSize: cint): cint {.cdecl, importc: "LZ4_saveDictHC",
    dynlib: liblz4.}
#
#  These functions compress data in successive blocks of any size, using previous blocks as dictionary.
#  One key assumption is that previous blocks (up to 64 KB) remain read-accessible while compressing next blocks.
#  There is an exception for ring buffers, which can be smaller 64 KB.
#  Such case is automatically detected and correctly handled by LZ4_compress_HC_continue().
#
#  Before starting compression, state must be properly initialized, using LZ4_resetStreamHC().
#  A first "fictional block" can then be designated as initial dictionary, using LZ4_loadDictHC() (Optional).
#
#  Then, use LZ4_compress_HC_continue() to compress each successive block.
#  It works like LZ4_compress_HC(), but use previous memory blocks as dictionary to improve compression.
#  Previous memory blocks (including initial dictionary when present) must remain accessible and unmodified during compression.
#  As a reminder, size 'dst' buffer to handle worst cases, using LZ4_compressBound(), to ensure success of compression operation.
#
#  If, for any reason, previous data blocks can't be preserved unmodified in memory during next compression block,
#  you must save it to a safer memory space, using LZ4_saveDictHC().
#  Return value of LZ4_saveDictHC() is the size of dictionary effectively saved into 'safeBuffer'.
#


