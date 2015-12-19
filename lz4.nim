#
# Nim high-level API to LZ4
#

import clz4
import clz4frame
import marshal

type
  LZ4Exception* = object of Exception

# A little helper to do pointer arithmetics, borrowed from:
#   https://github.com/fowlmouth/nimlibs/blob/master/fowltek/pointer_arithm.nim
proc offset[cstring](some: cstring; b: int): cstring =
  result = cast[cstring](cast[int](some) + (b * 1))
  
proc store_header(source:var string, value:uint32) =
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
  return (c0 or (c1 shl 8) or (c2 shl 16) or (c3 shl 23))

proc printable_header(s:string):string =
  result = ""
  for i in 0..100:
    result.add($int(s[i]) & "|")

proc print_char_values(s:string):string =
  result = ""
  for i in s.low..s.high:
    result.add($int(s[i]) & "|")

proc print_char_values(s:cstring,num:int):string =
  result = ""
  for i in 0..num:
    result.add($int(s[i]) & "|")

proc compress*(source:string, level:int=1):string =
  ## Compress a string.
  ## The compressed string contains a header that stores
  ## the size of `source`. This is useful for decompression later
  
  let compress_bound =  LZ4_compressBound(source.len) + HEADER_SIZE
  if compress_bound == 0:
    raise newException(LZ4Exception,"Input size to large")
 
  var dest = newString(compress_bound)
  for i in 0..dest.len:
    dest[i] = 'a'
    
  let bytes_written = LZ4_compress_fast(source=cstring(source),
                                        dest=(cstring(dest)).offset(HEADER_SIZE),
                                        sourceSize=cast[cint](source.len),
                                        maxDestSize=cast[cint](compress_bound),
                                        acceleration=cast[cint](level))
                                        
  if bytes_written == 0:
    raise newException(LZ4Exception,"Destination buffer too small")
 
  store_header(dest,cast[uint32](source.len))

  dest.setLen(bytes_written+HEADER_SIZE)
  echo ("header info:" & printable_header(dest) & "\n")
  echo ("first chars:" & print_char_values(dest[0..100]) & "\n")
  echo ("last chars:" & print_char_values(dest[1000..1200]) & "\n")
  echo ("bytes_written: " & $bytes_written)
  result = dest
  

proc uncompress*(source:string):string =
  ## Decompress a string. The compressed string is assumed to have
  ## a header entry that stores the size of the original string
  let uncompressed_size = load_header(source)
  var dest = newString(uncompressed_size)
  let bytes_decompressed = LZ4_decompress_safe(source=(cstring(source)).offset(HEADER_SIZE),
                                               dest=cstring(dest),
                                               compressedSize=cast[cint](source.len-HEADER_SIZE),
                                               maxDecompressedSize=cast[cint](uncompressed_size))

  echo("bytes_decompressed:" & $bytes_decompressed)
  if bytes_decompressed < 0 :
    raise newException(LZ4Exception,"Invalid input or buffer too small")
   
  result = dest


#
# Framing API
#

proc newLZ4F_frameInfo*():LZ4F_frameInfo =
  var info:LZ4F_frameInfo
  info.blockSizeID = LZ4F_blockSizeID.LZ4F_default
  info.blockMode = LZ4F_blockMode.LZ4F_blockLinked
  info.contentChecksumFlag = LZ4F_contentChecksum.LZ4F_noContentChecksum
  info.frameType = LZ4F_frameType.LZ4F_frame
  info.contentSize = 0
  result = info

# Simple frame compression and decompression
proc compress_frame*(source:string,
                     preferences:var LZ4F_preferences): string =
  ## Compress an entire string loaded into memory
  ## into a LZ4 frame
  let csource:cstring = cstring(source)
  let pprefs = addr(preferences)
  
  let dest_max_size =  LZ4F_compressFrameBound(csource.len,pprefs)
  if dest_max_size == 0:
    raise newException(LZ4Exception,"Input size to large")
 
  var dest = newString(dest_max_size)
  let bytes_written = LZ4F_compressFrame(dstBuffer=cstring(dest),
                                         dstMaxSize=dest_max_size,
                                         srcBuffer=csource,
                                         srcSize=csource.len,
                                         preferencesPtr=pprefs)

  if LZ4F_isError(bytes_written) == 1:
    let error = LZ4F_getErrorName(bytes_written)
    raise newException(LZ4Exception,$error)

  # Note: The last 4 bytes of the resulting compressed string
  # will be 0000, according to the LZ4 frame format
  dest.setLen(bytes_written)
  result = dest
  
proc decompress_frame*(source:string): string =
  # create decompression context
  var dcontext:LZ4F_decompressionContext
  let context_status = LZ4F_createDecompressionContext(addr(dcontext),
                                                       cuint(LZ4F_VERSION))
  if LZ4F_isError(context_status) == 1:
    let error = LZ4F_getErrorName(context_status)
    raise newException(LZ4Exception,$error)

  var csource = cstring(source)
  var dest_size:int = source.len 
  var dest:ptr char
  dest = cast[ptr char](alloc0(sizeof(char) * dest_size))
    
  var options:LZ4F_decompressOptions
  let src_size:int = source.len
  
  var start:int = 0
  var stop:int = src_size
  let initial = stop
  var i = 0
  result = ""

  # find initial amount to read for `stop`
  var frame = newLZ4F_frameInfo()
  var d = source.len 
  let initial_hint = LZ4F_getFrameInfo(dcontext,
                                      addr(frame),
                                      csource,
                                      addr(d))
  if LZ4F_isError(initial_hint) == 1:
      let error = LZ4F_getErrorName(initial_hint)
      raise newException(LZ4Exception,$error)
    
  dest_size = initial_hint
  start = d
  echo ("got initial hint:" & $stop)
  echo ("frame info:" & $$frame)
  
  while true:
    echo ("bef start:" & $start)
    echo ("bef stop:" & $stop)
    echo ("bef initial:" & $initial)
    var hint_src_size_bytes = LZ4F_decompress(dcontext,
                                              dest,
                                              addr(dest_size),
                                              csource.offset(start),
                                              addr(stop),
                                              addr(options))
    
    if LZ4F_isError(hint_src_size_bytes ) == 1:
      let error = LZ4F_getErrorName(hint_src_size_bytes )
      raise newException(LZ4Exception,$error)

    var t = stop + start
    echo ("stop + start:" & $t)
    echo ("start:" & $start)
    echo ("stop/hint:" & $stop)
    if t >= initial:
      echo ("XXX")
    
    #echo("\ndest so far:" & print_char_values(dest[(dest_size-30)..(dest_size)]))
    #echo("\ncdest len: " & $cstring(dest).len)
    if hint_src_size_bytes == 0:
      echo("decoding done!")
      echo ("done start:" & $start)
      echo ("done stop:" & $stop)
      break

      
    start += stop
    stop = hint_src_size_bytes
    echo ("aft start:" & $start)
    echo ("aft stop/hint:" & $stop)
   
    i += 1
    if i > 100_000:
      echo("break!!")
      break

    result = result & $cstring(dest)
    #result.add($dest)
    zeroMem(dest,dest_size)
    echo("\n")
    
  # we are done, free the context
  let free_status = LZ4F_freeDecompressionContext(dcontext)
  if LZ4F_isError(free_status) == 1:
    let error = LZ4F_getErrorName(free_status)
    raise newException(LZ4Exception,$error)

  result = result & $cstring(dest)
  #result.add($dest)
  echo ("result.len:" & $result.len)
  #result.setLen(hints)
  echo ("result.len after resize:" & $result.len)
  echo("\nres last values:" & print_char_values(result[result.high-30..(result.high)]))

  dealloc(dest)
  
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

