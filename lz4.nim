#
# Nim high-level API to LZ4
#

import clz4

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
