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

#  lz4.h provides block compression functions, and gives full buffer control to programmer.
#  If you need to generate inter-operable compressed data (respecting LZ4 frame specification),
#  and can let the library handle its own memory, please use lz4frame.h instead.
#
#*************************************
#  Version
#************************************
    
const
  LZ4_VERSION_MAJOR* = 1
  LZ4_VERSION_MINOR* = 7
  LZ4_VERSION_RELEASE* = 1
  LZ4_VERSION_NUMBER* = (LZ4_VERSION_MAJOR * 100 * 100 + LZ4_VERSION_MINOR * 100 +
      LZ4_VERSION_RELEASE)

proc LZ4_version*(): cint {.cdecl, importc: "LZ4_versionNumber", dynlib: liblz4.}
#*************************************
#  Tuning parameter
#************************************
#
#  LZ4_MEMORY_USAGE :
#  Memory usage formula : N->2^N Bytes (examples : 10 -> 1KB; 12 -> 4KB ; 16 -> 64KB; 20 -> 1MB; etc.)
#  Increasing memory usage improves compression ratio
#  Reduced memory usage can improve speed, due to cache effect
#  Default value is 14, for 16KB, which nicely fits into Intel x86 L1 cache
# 

const
  LZ4_MEMORY_USAGE* = 14

#*************************************
#  Simple Functions
#************************************

proc LZ4_compress_default*(source: cstring; dest: cstring; sourceSize: cint;
                          maxDestSize: cint): cint {.cdecl,
    importc: "LZ4_compress_default", dynlib: liblz4.}
proc LZ4_decompress_safe*(source: cstring; dest: cstring; compressedSize: cint;
                         maxDecompressedSize: cint): cint {.cdecl,
    importc: "LZ4_decompress_safe", dynlib: liblz4.}
#
#LZ4_compress_default() :
#    Compresses 'sourceSize' bytes from buffer 'source'
#    into already allocated 'dest' buffer of size 'maxDestSize'.
#    Compression is guaranteed to succeed if 'maxDestSize' >= LZ4_compressBound(sourceSize).
#    It also runs faster, so it's a recommended setting.
#    If the function cannot compress 'source' into a more limited 'dest' budget,
#    compression stops *immediately*, and the function result is zero.
#    As a consequence, 'dest' content is not valid.
#    This function never writes outside 'dest' buffer, nor read outside 'source' buffer.
#        sourceSize  : Max supported value is LZ4_MAX_INPUT_VALUE
#        maxDestSize : full or partial size of buffer 'dest' (which must be already allocated)
#        return : the number of bytes written into buffer 'dest' (necessarily <= maxOutputSize)
#              or 0 if compression fails
#
#LZ4_decompress_safe() :
#    compressedSize : is the precise full size of the compressed block.
#    maxDecompressedSize : is the size of destination buffer, which must be already allocated.
#    return : the number of bytes decompressed into destination buffer (necessarily <= maxDecompressedSize)
#             If destination buffer is not large enough, decoding will stop and output an error code (<0).
#             If the source stream is detected malformed, the function will stop decoding and return a negative result.
#             This function is protected against buffer overflow exploits, including malicious data packets.
#             It never writes outside output buffer, nor reads outside input buffer.
#
#*************************************
#  Advanced Functions
#************************************

const
  LZ4_MAX_INPUT_SIZE* = 0x7E000000

template LZ4_COMPRESSBOUND*(isize: expr): expr =
  (if cast[cuint](isize) > cast[cuint](LZ4_MAX_INPUT_SIZE): 0 else: (isize) +
      ((isize) div 255) + 16)

#
#LZ4_compressBound() :
#    Provides the maximum size that LZ4 compression may output in a "worst case" scenario (input data not compressible)
#    This function is primarily useful for memory allocation purposes (destination buffer size).
#    Macro LZ4_COMPRESSBOUND() is also provided for compilation-time evaluation (stack memory allocation for example).
#    Note that LZ4_compress_default() compress faster when dest buffer size is >= LZ4_compressBound(srcSize)
#        inputSize  : max supported value is LZ4_MAX_INPUT_SIZE
#        return : maximum output size in a "worst case" scenario
#              or 0, if input size is too large ( > LZ4_MAX_INPUT_SIZE)
#

proc LZ4_compressBound*(inputSize: cint): cint {.cdecl, importc: "LZ4_compressBound",
    dynlib: liblz4.}
#
#LZ4_compress_fast() :
#    Same as LZ4_compress_default(), but allows to select an "acceleration" factor.
#    The larger the acceleration value, the faster the algorithm, but also the lesser the compression.
#    It's a trade-off. It can be fine tuned, with each successive value providing roughly +~3% to speed.
#    An acceleration value of "1" is the same as regular LZ4_compress_default()
#    Values <= 0 will be replaced by ACCELERATION_DEFAULT (see lz4.c), which is 1.
#

proc LZ4_compress_fast*(source: cstring; dest: cstring; sourceSize: cint;
                       maxDestSize: cint; acceleration: cint): cint {.cdecl,
    importc: "LZ4_compress_fast", dynlib: liblz4.}
#
#LZ4_compress_fast_extState() :
#    Same compression function, just using an externally allocated memory space to store compression state.
#    Use LZ4_sizeofState() to know how much memory must be allocated,
#    and allocate it on 8-bytes boundaries (using malloc() typically).
#    Then, provide it as 'void* state' to compression function.
#

proc LZ4_sizeofState*(): cint {.cdecl, importc: "LZ4_sizeofState", dynlib: liblz4.}
proc LZ4_compress_fast_extState*(state: pointer; source: cstring; dest: cstring;
                                inputSize: cint; maxDestSize: cint;
                                acceleration: cint): cint {.cdecl,
    importc: "LZ4_compress_fast_extState", dynlib: liblz4.}
#
#LZ4_compress_destSize() :
#    Reverse the logic, by compressing as much data as possible from 'source' buffer
#    into already allocated buffer 'dest' of size 'targetDestSize'.
#    This function either compresses the entire 'source' content into 'dest' if it's large enough,
#    or fill 'dest' buffer completely with as much data as possible from 'source'.
#        sourceSizePtr : will be modified to indicate how many bytes where read from 'source' to fill 'dest'.
#                         New value is necessarily <= old value.
#        return : Nb bytes written into 'dest' (necessarily <= targetDestSize)
#              or 0 if compression fails
#

proc LZ4_compress_destSize*(source: cstring; dest: cstring; sourceSizePtr: ptr cint;
                           targetDestSize: cint): cint {.cdecl,
    importc: "LZ4_compress_destSize", dynlib: liblz4.}
#
#LZ4_decompress_fast() :
#    originalSize : is the original and therefore uncompressed size
#    return : the number of bytes read from the source buffer (in other words, the compressed size)
#             If the source stream is detected malformed, the function will stop decoding and return a negative result.
#             Destination buffer must be already allocated. Its size must be a minimum of 'originalSize' bytes.
#    note : This function fully respect memory boundaries for properly formed compressed data.
#           It is a bit faster than LZ4_decompress_safe().
#           However, it does not provide any protection against intentionally modified data stream (malicious input).
#           Use this function in trusted environment only (data to decode comes from a trusted source).
#

proc LZ4_decompress_fast*(source: cstring; dest: cstring; originalSize: cint): cint {.
    cdecl, importc: "LZ4_decompress_fast", dynlib: liblz4.}
#
#LZ4_decompress_safe_partial() :
#    This function decompress a compressed block of size 'compressedSize' at position 'source'
#    into destination buffer 'dest' of size 'maxDecompressedSize'.
#    The function tries to stop decompressing operation as soon as 'targetOutputSize' has been reached,
#    reducing decompression time.
#    return : the number of bytes decoded in the destination buffer (necessarily <= maxDecompressedSize)
#       Note : this number can be < 'targetOutputSize' should the compressed block to decode be smaller.
#             Always control how many bytes were decoded.
#             If the source stream is detected malformed, the function will stop decoding and return a negative result.
#             This function never writes outside of output buffer, and never reads outside of input buffer. It is therefore protected against malicious data packets
#

proc LZ4_decompress_safe_partial*(source: cstring; dest: cstring;
                                 compressedSize: cint; targetOutputSize: cint;
                                 maxDecompressedSize: cint): cint {.cdecl,
    importc: "LZ4_decompress_safe_partial", dynlib: liblz4.}

#
# Nim high-level API
#
type LZ4Exception* = object of Exception

# A little helper to do pointer arithmetics, borrowed from:
#   https://github.com/fowlmouth/nimlibs/blob/master/fowltek/pointer_arithm.nim
proc offset[A](some: ptr A; b: int): ptr A =
  result = cast[ptr A](cast[int](some) + (b * sizeof(A)))
  
proc store_header(source:ptr char ,value:int):string =
  #var c = offset(source,0)
  #c = value and 0xff
  source[0] = 'c'
  
proc extract_header(s:string):int =
  result = 0
  
proc compress*(source:string, level:int=1):string =
  let compress_bound =  LZ4_compressBound(source.len)
  if compress_bound == 0:
    raise newException(LZ4Exception,"Input size to large")
  var dest = newStringOfCap(compress_bound)
  let bytes_written = LZ4_compress_fast(source=cast[cstring](source),
                                        dest=cast[cstring](dest),
                                        sourceSize=cast[cint](source.len),
                                        maxDestSize=cast[cint](compress_bound),
                                        acceleration=cast[cint](level))
  if bytes_written == 0:
    raise newException(LZ4Exception,"Compression failed")

  if bytes_written < 0:
    raise newException(LZ4Exception,"Destination buffer too small")
  
  dest.setLen(bytes_written)
  result = dest

proc uncompress*(source:string):string =
  result = ""

#**********************************************
#  Streaming Compression Functions
#*********************************************

const
  LZ4_STREAMSIZE_U64* = ((1 shl (LZ4_MEMORY_USAGE - 3)) + 4)
  LZ4_STREAMSIZE* = (LZ4_STREAMSIZE_U64 * sizeof(clonglong))

#
#  LZ4_stream_t
#  information structure to track an LZ4 stream.
#  important : init this structure content before first use !
#  note : only allocated directly the structure if you are statically linking LZ4
#         If you are using liblz4 as a DLL, please use below construction methods instead.
# 

type
  LZ4_stream_t* = object
    table*: array[LZ4_STREAMSIZE_U64, clonglong]


#
#  LZ4_resetStream
#  Use this function to init an allocated LZ4_stream_t structure
# 

proc LZ4_resetStream*(streamPtr: ptr LZ4_stream_t) {.cdecl,
    importc: "LZ4_resetStream", dynlib: liblz4.}
#
#  LZ4_createStream will allocate and initialize an LZ4_stream_t structure
#  LZ4_freeStream releases its memory.
#  In the context of a DLL (liblz4), please use these methods rather than the static struct.
#  They are more future proof, in case of a change of LZ4_stream_t size.
# 

proc LZ4_createStream*(): ptr LZ4_stream_t {.cdecl, importc: "LZ4_createStream",
    dynlib: liblz4.}
proc LZ4_freeStream*(streamPtr: ptr LZ4_stream_t): cint {.cdecl,
    importc: "LZ4_freeStream", dynlib: liblz4.}
#
#  LZ4_loadDict
#  Use this function to load a static dictionary into LZ4_stream.
#  Any previous data will be forgotten, only 'dictionary' will remain in memory.
#  Loading a size of 0 is allowed.
#  Return : dictionary size, in bytes (necessarily <= 64 KB)
# 

proc LZ4_loadDict*(streamPtr: ptr LZ4_stream_t; dictionary: cstring; dictSize: cint): cint {.
    cdecl, importc: "LZ4_loadDict", dynlib: liblz4.}
#
#  LZ4_compress_fast_continue
#  Compress buffer content 'src', using data from previously compressed blocks as dictionary to improve compression ratio.
#  Important : Previous data blocks are assumed to still be present and unmodified !
#  'dst' buffer must be already allocated.
#  If maxDstSize >= LZ4_compressBound(srcSize), compression is guaranteed to succeed, and runs faster.
#  If not, and if compressed data cannot fit into 'dst' buffer size, compression stops, and function returns a zero.
# 

proc LZ4_compress_fast_continue*(streamPtr: ptr LZ4_stream_t; src: cstring;
                                dst: cstring; srcSize: cint; maxDstSize: cint;
                                acceleration: cint): cint {.cdecl,
    importc: "LZ4_compress_fast_continue", dynlib: liblz4.}
#
#  LZ4_saveDict
#  If previously compressed data block is not guaranteed to remain available at its memory location
#  save it into a safer place (char* safeBuffer)
#  Note : you don't need to call LZ4_loadDict() afterwards,
#         dictionary is immediately usable, you can therefore call LZ4_compress_fast_continue()
#  Return : saved dictionary size in bytes (necessarily <= dictSize), or 0 if error
# 

proc LZ4_saveDict*(streamPtr: ptr LZ4_stream_t; safeBuffer: cstring; dictSize: cint): cint {.
    cdecl, importc: "LZ4_saveDict", dynlib: liblz4.}
#***********************************************
#  Streaming Decompression Functions
#**********************************************

const
  LZ4_STREAMDECODESIZE_U64* = 4
  LZ4_STREAMDECODESIZE* = (LZ4_STREAMDECODESIZE_U64 * sizeof(culonglong))

type
  LZ4_streamDecode_t* = object
    table*: array[LZ4_STREAMDECODESIZE_U64, culonglong]


#
#  LZ4_streamDecode_t
#  information structure to track an LZ4 stream.
#  init this structure content using LZ4_setStreamDecode or memset() before first use !
# 
#  In the context of a DLL (liblz4) please prefer usage of construction methods below.
#  They are more future proof, in case of a change of LZ4_streamDecode_t size in the future.
#  LZ4_createStreamDecode will allocate and initialize an LZ4_streamDecode_t structure
#  LZ4_freeStreamDecode releases its memory.
# 

proc LZ4_createStreamDecode*(): ptr LZ4_streamDecode_t {.cdecl,
    importc: "LZ4_createStreamDecode", dynlib: liblz4.}
proc LZ4_freeStreamDecode*(LZ4_stream: ptr LZ4_streamDecode_t): cint {.cdecl,
    importc: "LZ4_freeStreamDecode", dynlib: liblz4.}
#
#  LZ4_setStreamDecode
#  Use this function to instruct where to find the dictionary.
#  Setting a size of 0 is allowed (same effect as reset).
#  Return : 1 if OK, 0 if error
# 

proc LZ4_setStreamDecode*(LZ4_streamDecode: ptr LZ4_streamDecode_t;
                         dictionary: cstring; dictSize: cint): cint {.cdecl,
    importc: "LZ4_setStreamDecode", dynlib: liblz4.}
#
#_continue() :
#    These decoding functions allow decompression of multiple blocks in "streaming" mode.
#    Previously decoded blocks *must* remain available at the memory position where they were decoded (up to 64 KB)
#    In the case of a ring buffers, decoding buffer must be either :
#    - Exactly same size as encoding buffer, with same update rule (block boundaries at same positions)
#      In which case, the decoding & encoding ring buffer can have any size, including very small ones ( < 64 KB).
#    - Larger than encoding buffer, by a minimum of maxBlockSize more bytes.
#      maxBlockSize is implementation dependent. It's the maximum size you intend to compress into a single block.
#      In which case, encoding and decoding buffers do not need to be synchronized,
#      and encoding ring buffer can have any size, including small ones ( < 64 KB).
#    - _At least_ 64 KB + 8 bytes + maxBlockSize.
#      In which case, encoding and decoding buffers do not need to be synchronized,
#      and encoding ring buffer can have any size, including larger than decoding buffer.
#    Whenever these conditions are not possible, save the last 64KB of decoded data into a safe buffer,
#    and indicate where it is saved using LZ4_setStreamDecode()
#

proc LZ4_decompress_safe_continue*(LZ4_streamDecode: ptr LZ4_streamDecode_t;
                                  source: cstring; dest: cstring;
                                  compressedSize: cint; maxDecompressedSize: cint): cint {.
    cdecl, importc: "LZ4_decompress_safe_continue", dynlib: liblz4.}
proc LZ4_decompress_fast_continue*(LZ4_streamDecode: ptr LZ4_streamDecode_t;
                                  source: cstring; dest: cstring; originalSize: cint): cint {.
    cdecl, importc: "LZ4_decompress_fast_continue", dynlib: liblz4.}
#
#Advanced decoding functions :
#_usingDict() :
#    These decoding functions work the same as
#    a combination of LZ4_setStreamDecode() followed by LZ4_decompress_x_continue()
#    They are stand-alone. They don't need nor update an LZ4_streamDecode_t structure.
#

proc LZ4_decompress_safe_usingDict*(source: cstring; dest: cstring;
                                   compressedSize: cint;
                                   maxDecompressedSize: cint; dictStart: cstring;
                                   dictSize: cint): cint {.cdecl,
    importc: "LZ4_decompress_safe_usingDict", dynlib: liblz4.}
proc LZ4_decompress_fast_usingDict*(source: cstring; dest: cstring;
                                   originalSize: cint; dictStart: cstring;
                                   dictSize: cint): cint {.cdecl,
    importc: "LZ4_decompress_fast_usingDict", dynlib: liblz4.}
