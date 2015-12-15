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

#*************************************
#  Error management
#  ***********************************

type
  LZ4F_errorCode* = csize

proc LZ4F_isError*(code: LZ4F_errorCode): cuint {.cdecl, importc: "LZ4F_isError",
    dynlib: liblz4.}
proc LZ4F_getErrorName*(code: LZ4F_errorCode): cstring {.cdecl,
    importc: "LZ4F_getErrorName", dynlib: liblz4.}
# return error code string; useful for debugging 
#*************************************
#  Frame compression types
#  ***********************************

type
  LZ4F_blockSizeID* {.size: sizeof(cint).} = enum
    LZ4F_default = 0,
    LZ4F_max64KB = 4,
    LZ4F_max256KB = 5,
    LZ4F_max1MB = 6,
    LZ4F_max4MB = 7

  LZ4F_blockMode* {.size: sizeof(cint).} = enum
    LZ4F_blockLinked = 0,
    LZ4F_blockIndependent

  LZ4F_contentChecksum* {.size: sizeof(cint).} = enum
    LZ4F_noContentChecksum = 0,
    LZ4F_contentChecksumEnabled

  LZ4F_frameType* {.size: sizeof(cint).} = enum
    LZ4F_frame = 0,
    LZ4F_skippableFrame
 
  blockSizeID* = LZ4F_blockSizeID
  blockMode* = LZ4F_blockMode
  frameType* = LZ4F_frameType
  contentChecksum* = LZ4F_contentChecksum

  LZ4F_frameInfo* = object
    blockSizeID*: LZ4F_blockSizeID # max64KB, max256KB, max1MB, max4MB ; 0 == default 
    blockMode*: LZ4F_blockMode # blockLinked, blockIndependent ; 0 == default 
    contentChecksumFlag*: LZ4F_contentChecksum # noContentChecksum, contentChecksumEnabled ; 0 == default  
    frameType*: LZ4F_frameType # LZ4F_frame, skippableFrame ; 0 == default 
    contentSize*: culonglong   # Size of uncompressed (original) content ; 0 == unknown 
    reserved*: array[2, cuint]  # must be zero for forward compatibility 
  
  LZ4F_preferences* = object
    frameInfo*: LZ4F_frameInfo
    compressionLevel*: cint    # 0 == default (fast mode); values above 16 count as 16; values below 0 count as 0 
    autoFlush*: cuint          # 1 == always flush (reduce need for tmp buffer) 
    reserved*: array[4, cuint]  # must be zero for forward compatibility 

  PLZ4F_preferences* = ptr LZ4F_preferences
  
  LZ4F_compressionContext* = ptr object
    
  # must be aligned on 8-bytes 
  LZ4F_compressOptions* = object
    stableSrc*: cuint          # 1 == src content will remain available on future calls to LZ4F_compress(); avoid saving src content within tmp buffer as future dictionary 
    reserved*: array[3, cuint]


  LZ4F_decompressionContext* = ptr object

  # must be aligned on 8-bytes 
  LZ4F_decompressOptions* = object
    stableDst*: cuint          # guarantee that decompressed data will still be there on next function calls (avoid storage into tmp buffers) 
    reserved*: array[3, cuint]

const
  LZ4F_VERSION* = 100

#**********************************
#  Simple compression function
#  ********************************

proc LZ4F_compressFrameBound*(srcSize: csize;
                             preferencesPtr: ptr LZ4F_preferences): csize {.cdecl,
    importc: "LZ4F_compressFrameBound", dynlib: liblz4.}
proc LZ4F_compressFrame*(dstBuffer: pointer; dstMaxSize: csize;
                         srcBuffer: pointer;srcSize: csize;
                         preferencesPtr: PLZ4F_preferences): csize {.
    cdecl, importc: "LZ4F_compressFrame", dynlib: liblz4.}
# LZ4F_compressFrame()
#  Compress an entire srcBuffer into a valid LZ4 frame, as defined by specification v1.5.1
#  The most important rule is that dstBuffer MUST be large enough (dstMaxSize) to ensure compression completion even in worst case.
#  You can get the minimum value of dstMaxSize by using LZ4F_compressFrameBound()
#  If this condition is not respected, LZ4F_compressFrame() will fail (result is an errorCode)
#  The LZ4F_preferences structure is optional : you can provide NULL as argument. All preferences will be set to default.
#  The result of the function is the number of bytes written into dstBuffer.
#  The function outputs an error code if it fails (can be tested using LZ4F_isError())
# 
#*********************************
#  Advanced compression functions
#********************************

# Resource Management 
proc LZ4F_createCompressionContext*(cctxPtr: ptr LZ4F_compressionContext;
                                   version: cuint): LZ4F_errorCode {.cdecl,
    importc: "LZ4F_createCompressionContext", dynlib: liblz4.}
proc LZ4F_freeCompressionContext*(cctx: LZ4F_compressionContext): LZ4F_errorCode {.
    cdecl, importc: "LZ4F_freeCompressionContext", dynlib: liblz4.}
# LZ4F_createCompressionContext() :
#  The first thing to do is to create a compressionContext object, which will be used in all compression operations.
#  This is achieved using LZ4F_createCompressionContext(), which takes as argument a version and an LZ4F_preferences structure.
#  The version provided MUST be LZ4F_VERSION. It is intended to track potential version differences between different binaries.
#  The function will provide a pointer to a fully allocated LZ4F_compressionContext object.
#  If the result LZ4F_errorCode is not zero, there was an error during context creation.
#  Object can release its memory using LZ4F_freeCompressionContext();
# 
# Compression 

proc LZ4F_compressBegin*(cctx: LZ4F_compressionContext; dstBuffer: pointer;
                        dstMaxSize: csize; prefsPtr: PLZ4F_preferences): csize {.
    cdecl, importc: "LZ4F_compressBegin", dynlib: liblz4.}
# LZ4F_compressBegin() :
#  will write the frame header into dstBuffer.
#  dstBuffer must be large enough to accommodate a header (dstMaxSize). Maximum header size is 15 bytes.
#  The LZ4F_preferences_t structure is optional : you can provide NULL as argument, all preferences will then be set to default.
#  The result of the function is the number of bytes written into dstBuffer for the header
#  or an error code (can be tested using LZ4F_isError())
# 

proc LZ4F_compressBound*(srcSize: csize; prefsPtr: PLZ4F_preferences): csize {.
    cdecl, importc: "LZ4F_compressBound", dynlib: liblz4.}
# LZ4F_compressBound() :
#  Provides the minimum size of Dst buffer given srcSize to handle worst case situations.
#  Different preferences can produce different results.
#  prefsPtr is optional : you can provide NULL as argument, all preferences will then be set to cover worst case.
#  This function includes frame termination cost (4 bytes, or 8 if frame checksum is enabled)
# 

proc LZ4F_compressUpdate*(cctx: LZ4F_compressionContext; dstBuffer: pointer;
                         dstMaxSize: csize; srcBuffer: pointer; srcSize: csize;
                         cOptPtr: ptr LZ4F_compressOptions): csize {.cdecl,
    importc: "LZ4F_compressUpdate", dynlib: liblz4.}
# LZ4F_compressUpdate()
#  LZ4F_compressUpdate() can be called repetitively to compress as much data as necessary.
#  The most important rule is that dstBuffer MUST be large enough (dstMaxSize) to ensure compression completion even in worst case.
#  You can get the minimum value of dstMaxSize by using LZ4F_compressBound().
#  If this condition is not respected, LZ4F_compress() will fail (result is an errorCode).
#  LZ4F_compressUpdate() doesn't guarantee error recovery, so you have to reset compression context when an error occurs.
#  The LZ4F_compressOptions structure is optional : you can provide NULL as argument.
#  The result of the function is the number of bytes written into dstBuffer : it can be zero, meaning input data was just buffered.
#  The function outputs an error code if it fails (can be tested using LZ4F_isError())
# 

proc LZ4F_flush*(cctx: LZ4F_compressionContext; dstBuffer: pointer;
                dstMaxSize: csize; cOptPtr: ptr LZ4F_compressOptions): csize {.
    cdecl, importc: "LZ4F_flush", dynlib: liblz4.}
# LZ4F_flush()
#  Should you need to generate compressed data immediately, without waiting for the current block to be filled,
#  you can call LZ4_flush(), which will immediately compress any remaining data buffered within cctx.
#  Note that dstMaxSize must be large enough to ensure the operation will be successful.
#  LZ4F_compressOptions_t structure is optional : you can provide NULL as argument.
#  The result of the function is the number of bytes written into dstBuffer
#  (it can be zero, this means there was no data left within cctx)
#  The function outputs an error code if it fails (can be tested using LZ4F_isError())
# 

proc LZ4F_compressEnd*(cctx: LZ4F_compressionContext; dstBuffer: pointer;
                      dstMaxSize: csize; cOptPtr: ptr LZ4F_compressOptions): csize {.
    cdecl, importc: "LZ4F_compressEnd", dynlib: liblz4.}
# LZ4F_compressEnd()
#  When you want to properly finish the compressed frame, just call LZ4F_compressEnd().
#  It will flush whatever data remained within compressionContext (like LZ4_flush())
#  but also properly finalize the frame, with an endMark and a checksum.
#  The result of the function is the number of bytes written into dstBuffer (necessarily >= 4 (endMark), or 8 if optional frame checksum is enabled)
#  The function outputs an error code if it fails (can be tested using LZ4F_isError())
#  The LZ4F_compressOptions_t structure is optional : you can provide NULL as argument.
#  A successful call to LZ4F_compressEnd() makes cctx available again for next compression task.
# 
#**********************************
#  Decompression functions
#*********************************

# Resource management 

proc LZ4F_createDecompressionContext*(dctxPtr: ptr LZ4F_decompressionContext;
                                     version: cuint): LZ4F_errorCode {.cdecl,
    importc: "LZ4F_createDecompressionContext", dynlib: liblz4.}
proc LZ4F_freeDecompressionContext*(dctx: LZ4F_decompressionContext): LZ4F_errorCode {.
    cdecl, importc: "LZ4F_freeDecompressionContext", dynlib: liblz4.}
# LZ4F_createDecompressionContext() :
#  The first thing to do is to create an LZ4F_decompressionContext_t object, which will be used in all decompression operations.
#  This is achieved using LZ4F_createDecompressionContext().
#  The version provided MUST be LZ4F_VERSION. It is intended to track potential breaking differences between different versions.
#  The function will provide a pointer to a fully allocated and initialized LZ4F_decompressionContext_t object.
#  The result is an errorCode, which can be tested using LZ4F_isError().
#  dctx memory can be released using LZ4F_freeDecompressionContext();
#  The result of LZ4F_freeDecompressionContext() is indicative of the current state of decompressionContext when being released.
#  That is, it should be == 0 if decompression has been completed fully and correctly.
# 
# Decompression 

proc LZ4F_getFrameInfo*(dctx: LZ4F_decompressionContext;
                       frameInfoPtr: ptr LZ4F_frameInfo; srcBuffer: pointer;
                       srcSizePtr: ptr csize): csize {.cdecl,
    importc: "LZ4F_getFrameInfo", dynlib: liblz4.}
# LZ4F_getFrameInfo()
#  This function decodes frame header information (such as max blockSize, frame checksum, etc.).
#  Its usage is optional : you can start by calling directly LZ4F_decompress() instead.
#  The objective is to extract frame header information, typically for allocation purposes.
#  LZ4F_getFrameInfo() can also be used anytime *after* starting decompression, on any valid LZ4F_decompressionContext_t.
#  The result is *copied* into an existing LZ4F_frameInfo_t structure which must be already allocated.
#  The number of bytes read from srcBuffer will be provided within *srcSizePtr (necessarily <= original value).
#  The function result is an hint of how many srcSize bytes LZ4F_decompress() expects for next call,
#                         or an error code which can be tested using LZ4F_isError()
#                         (typically, when there is not enough src bytes to fully decode the frame header)
#  You are expected to resume decompression from where it stopped (srcBuffer + *srcSizePtr)
# 

proc LZ4F_decompress*(dctx: LZ4F_decompressionContext; dstBuffer: pointer;
                     dstSizePtr: ptr csize; srcBuffer: pointer;
                     srcSizePtr: ptr csize; dOptPtr: ptr LZ4F_decompressOptions): csize {.
    cdecl, importc: "LZ4F_decompress", dynlib: liblz4.}
# LZ4F_decompress()
#  Call this function repetitively to regenerate data compressed within srcBuffer.
#  The function will attempt to decode *srcSizePtr bytes from srcBuffer, into dstBuffer of maximum size *dstSizePtr.
# 
#  The number of bytes regenerated into dstBuffer will be provided within *dstSizePtr (necessarily <= original value).
# 
#  The number of bytes read from srcBuffer will be provided within *srcSizePtr (necessarily <= original value).
#  If number of bytes read is < number of bytes provided, then decompression operation is not completed.
#  It typically happens when dstBuffer is not large enough to contain all decoded data.
#  LZ4F_decompress() must be called again, starting from where it stopped (srcBuffer + *srcSizePtr)
#  The function will check this condition, and refuse to continue if it is not respected.
# 
#  dstBuffer is supposed to be flushed between each call to the function, since its content will be overwritten.
#  dst arguments can be changed at will with each consecutive call to the function.
# 
#  The function result is an hint of how many srcSize bytes LZ4F_decompress() expects for next call.
#  Schematically, it's the size of the current (or remaining) compressed block + header of next block.
#  Respecting the hint provides some boost to performance, since it does skip intermediate buffers.
#  This is just a hint, you can always provide any srcSize you want.
#  When a frame is fully decoded, the function result will be 0 (no more data expected).
#  If decompression failed, function result is an error code, which can be tested using LZ4F_isError().
# 
#  After a frame is fully decoded, dctx can be used again to decompress another frame.
# 
# #if defined (__cplusplus) 
# } 
# #endif 
