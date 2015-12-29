#
# Nim high-level API to LZ4
#

import clz4/clz4
import clz4/clz4frame
import clz4/clz4hc
import sequtils

type
  LZ4Exception* = object of Exception

# A little helper to do pointer arithmetics, borrowed from:
#   https://github.com/fowlmouth/nimlibs/blob/master/fowltek/pointer_arithm.nim
proc offset[cstring](some: cstring; b: int): cstring =
  result = cast[cstring](cast[int](some) + (b * 1))

proc store_header(source:var string, value:int) =
  ## store header information in `source`. We pre-pad this
  ## information to any compressed bytes we have
  source[0] = cast[char](value and 0xff)
  source[1] = cast[char]((value shr 8) and 0xff)
  source[2] = cast[char]((value shr 16) and 0xff)
  source[3] = cast[char]((value shr 24) and 0xff)
  
proc load_header(source:string):int =
  ## Extract header information from some bytes
  let c0 = cast[int](source[0])
  let c1 = cast[int](source[1])
  let c2 = cast[int](source[2])
  let c3 = cast[int](source[3])
  return (c0 or (c1 shl 8) or (c2 shl 16) or (c3 shl 24))

#
# LZ4 block API
#
proc compress*(source:string, level:int=1):string =
  ## Compress a string.
  ## The compressed string contains a header that stores
  ## the size of `source`. This is useful for decompression later
  ## Data compressed by this function can only reliably be decompressed
  ## by `uncompress`. To have a portable LZ4 format, use the LZ4 frame
  ## functions
  let compress_bound =  LZ4_compressBound(source.len) + HEADER_SIZE
  if compress_bound == 0:
    raise newException(LZ4Exception,"Input size too large")
 
  var dest = newString(compress_bound)
    
  let bytes_written = LZ4_compress_fast(source=cstring(source),
                                        dest=(cstring(dest)).offset(HEADER_SIZE),
                                        sourceSize=cast[cint](source.len),
                                        maxDestSize=cast[cint](compress_bound),
                                        acceleration=cast[cint](level))
                                        
  if bytes_written == 0:
    raise newException(LZ4Exception,"Destination buffer too small")
 
  store_header(dest,source.len)
  
  dest.setLen(bytes_written+HEADER_SIZE)
  result = dest
  

proc uncompress*(source:string):string =
  ## Decompress a string. The compressed string is assumed to have
  ## a header entry that stores the size of the original string
  ## Data decompressed by this function assumes it was already compressed
  ## by the `compress` function. To use a portable LZ4 format, use the LZ4 frame
  ## functions
  let uncompressed_size = load_header(source)
  var dest = newString(uncompressed_size)
  let bytes_decompressed = LZ4_decompress_safe(source=(cstring(source)).offset(HEADER_SIZE),
                                               dest=cstring(dest),
                                               compressedSize=cast[cint](source.len-HEADER_SIZE),
                                               maxDecompressedSize=cast[cint](uncompressed_size))

  if bytes_decompressed < 0 :
    raise newException(LZ4Exception,"Invalid input or buffer too small")
   
  result = dest

# High compression mode
proc compress_more*(source:string,level:int=4):string =
  ## High block compression mode for LZ4. Achieve a higher compression
  ## ratio at the expense of CPU time
  let compress_bound =  LZ4_compressBound(source.len) + HEADER_SIZE
  if compress_bound == 0:
    raise newException(LZ4Exception,"Input size too large")
 
  var dest = newString(compress_bound)
    
  let bytes_written = LZ4_compress_HC(src=cstring(source),
                                      dst=(cstring(dest)).offset(HEADER_SIZE),
                                      srcSize=cast[cint](source.len),
                                      maxDstSize=cast[cint](compress_bound),
                                      compressionLevel=cast[cint](level))
                                        
  if bytes_written == 0:
    raise newException(LZ4Exception,"Destination buffer too small")
 
  store_header(dest,source.len)
  
  dest.setLen(bytes_written+HEADER_SIZE)
  result = dest
  
  
#
# LZ4 Frame API
#

proc newLZ4F_frameInfo*():LZ4F_frameInfo =
  var info:LZ4F_frameInfo
  info.blockSizeID = LZ4F_blockSizeID.LZ4F_default
  info.blockMode = LZ4F_blockMode.LZ4F_blockLinked
  info.contentChecksumFlag = LZ4F_contentChecksum.LZ4F_noContentChecksum
  info.frameType = LZ4F_frameType.LZ4F_frame
  info.contentSize = 0
  result = info

proc newLZ4F_preferences*(frame_info:LZ4F_frameInfo,
                         compressionLevel:int=0,
                         autoFlush:int=1):LZ4F_preferences =
  var res:LZ4F_preferences
  res.frameInfo = frame_info
  res.compressionLevel = cint(compressionLevel)
  res.autoFlush = cuint(autoFlush)
  result = res

proc newLZ4F_preferences*(compressionLevel:int=0,
                         autoFlush:int=1):LZ4F_preferences =
  var res:LZ4F_preferences
  res.frameInfo = newLZ4F_frameInfo()
  res.compressionLevel = cint(compressionLevel)
  res.autoFlush = cuint(autoFlush)
  result = res

proc blockSizeId_to_bytes(b:LZ4F_blockSizeID): int =
  ## Get the right number of bytes from a `LZ4F_blockSizeID`
  case b
  of LZ4F_default:
    result = 64 * 1024
  of LZ4F_max64KB:
    result = 64 * 1024
  of LZ4F_max256KB:
    result = 256 * 1024
  of LZ4F_max1MB:
    result = 1024 * 1024
  of LZ4F_max4MB:
    result = 4 * 1024 * 1024


# Simple frame compression and decompression
proc compress_frame*(source: var string,
                     preferences:var LZ4F_preferences): string =
  ## Compress an entire string loaded into memory
  ## into a LZ4 frame.
  
  let source_len = source.len
  let pprefs = addr(preferences)
  
  let dest_max_size =  LZ4F_compressFrameBound(source_len,pprefs)
  if dest_max_size == 0:
    raise newException(LZ4Exception,"Input size to large")
 
  var dest = cast[ptr char](alloc0(sizeof(char) * dest_max_size))
  let bytes_written = LZ4F_compressFrame(dstBuffer=dest,
                                         dstMaxSize=dest_max_size,
                                         srcBuffer=addr(source[0]),
                                         srcSize=source_len,
                                         preferencesPtr=pprefs)

  if LZ4F_isError(bytes_written) == 1:
    let error = LZ4F_getErrorName(bytes_written)
    raise newException(LZ4Exception,$error)

  # Note: The last 4 bytes of the resulting compressed string
  # will be 0000, according to the LZ4 frame format.
  # This happens only if content checksum disabled
  # `LZ4F_preferences` (the default)
  result = newString(bytes_written)
  copyMem(addr(result[0]), dest, bytes_written)
  dealloc(dest)
    
proc uncompress_frame*(source: var string): string =
  ## decompress a string that uses the LZ4 frame format
      
  var dcontext:LZ4F_decompressionContext
  var dest:ptr char = nil
  var csource: ptr char = nil
  
  try:
    let context_status = LZ4F_createDecompressionContext(addr(dcontext),
                                                         cuint(LZ4F_VERSION))
    if LZ4F_isError(context_status) == 1:
      let error = LZ4F_getErrorName(context_status)
      raise newException(LZ4Exception,$error)
  
    # make source into a char ptr
    var src_size:int = source.len
    csource = cast[ptr char](alloc0(sizeof(char) * src_size))
    copyMem(csource,addr(source[0]),Natural(src_size))

    var start = 0
    var stop = src_size

    # try to get frame header info to allocate
    # the right size for the destination buffer
    var frame = newLZ4F_frameInfo()
    let initial_hint = LZ4F_getFrameInfo(dcontext,
                                        addr(frame),
                                        csource,
                                        addr(src_size))
    if LZ4F_isError(initial_hint) == 1:
        let error = LZ4F_getErrorName(initial_hint)
        raise newException(LZ4Exception,$error)

    # if frame.contentSize is set, use that
    # else get max frame size from the blockSizeID
    var dest_size:int
    var block_size:int
    let content_size = int(frame.contentSize)
    if  content_size > 0:
      dest_size = content_size
    else:
      block_size = blockSizeId_to_bytes(frame.blockSizeID)
      dest_size = block_size

    dest = cast[ptr char](alloc0(sizeof(char) * dest_size))

    # after calling `LZ4F_getFrameInfo`, we must move
    # to the next bytes
    start = src_size

    result = newString(dest_size)
    # index of the last element of the result buffer
    var resbeg = 0
    # size so far of the result buffer
    var cumulative_size = dest_size
    # LZ4 options
    var options:LZ4F_decompressOptions
    while true:
      let hint_src_size_bytes = LZ4F_decompress(dcontext,
                                                dest,
                                                addr(dest_size),
                                                csource.offset(start),
                                                addr(stop),
                                                addr(options))

      if LZ4F_isError(hint_src_size_bytes ) == 1:
        let error = LZ4F_getErrorName(hint_src_size_bytes)
        raise newException(LZ4Exception,$error)

      if hint_src_size_bytes == 0:
        break

      start += stop
      stop = hint_src_size_bytes

      moveMem(addr(result[resbeg]),dest,dest_size)
      resbeg += dest_size 
      cumulative_size += dest_size
      result.setLen(resbeg+dest_size)
      zeroMem(dest,dest_size)

    # # we are done, free the context
    # let free_status = LZ4F_freeDecompressionContext(dcontext)
    # if LZ4F_isError(free_status) == 1:
    #   let error = LZ4F_getErrorName(free_status)
    #   raise newException(LZ4Exception,$error)

    moveMem(addr(result[resbeg]),dest,dest_size)

    # when done reading the source buffer, the dest buffer
    # might only be partially-filled. Get exactly
    # how many spaces to chop up from the result buffer
    let unfilled_space = block_size - dest_size
    result.setLen(cumulative_size-unfilled_space)

  finally:
    
    if dest != nil:
      dealloc(dest)
      
    if csource != nil:  
      dealloc(csource)

    let free_status = LZ4F_freeDecompressionContext(dcontext)
    if LZ4F_isError(free_status) == 1:
      let error = LZ4F_getErrorName(free_status)
      raise newException(LZ4Exception,$error)


const
  BLOCK_BYTES = 1024

type
  page = object
    first:ptr char
    sec:ptr char

proc `[]`(p:page,index:int): ptr char =
  if index mod 2 == 0 :
    result = p.first
  else:
    result = p.sec
    
proc stream_compress(source:var string): string =
  var inbuf:page
  var inbufindex = 0
  
  var lz4stream:PLZ4Stream
  LZ4_resetStream(lz4stream)

  let size:int = LZ4_compressBound(BLOCK_BYTES) 
  var cmpbuf:ptr char
  cmpbuf = cast[ptr char](alloc0(sizeof(char) * size))

  #var source_seq = source[0..100] #
  var source_seq = toSeq(source[0..100])
  while true:
    var inptr:ptr char = inbuf[inbufindex]
    inptr = cast[ptr char](alloc0(sizeof(char) * size))
    # get input from stream
    var inbytes = source_seq.distribute(Positive(100),false) #source[0..100].len
    #if inbytes == 0:
    #  break
        
    var cmpbytes = LZ4_compress_fast_continue(lz4stream,
                                              inptr,
                                              cmpbuf,
                                              cint(inbytes.len),
                                              cint(sizeof(cmpbuf)),
                                              cint(1))
    if cmpbytes < 0 :
      break

    # write size and compressed output to out buffer

    inbufindex = (inbufindex+1) mod 2 

  dealloc(cmpbuf)
  dealloc(inbuf[0])
  dealloc(inbuf[1])
  result = ""
