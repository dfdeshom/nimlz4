import lz4
import clz4frame
#var input = readFile("/home/dfdeshom/code/lz4/lz4_Frame_format.md")
var input = readFile("/home/dfdeshom/code/lz4/lib/lz4.c")
#var input = readFile("big.txt")
#var input = readFile("LICENSE")

proc test_compress_fast() = 
  var compressed = compress(input,level=1)
  echo("compressed: " & $compressed)
  echo("compressed length: " & $compressed.len)
  echo("original length: " & $input.len)

  var uncompressed = uncompress(compressed)
  echo("uncompressed==input: " & $(uncompressed==input))

  var prefs:LZ4F_preferences

proc test_compress_frame() =
  var prefs = newLZ4F_preferences()
  #prefs.frameInfo.contentChecksumFlag = LZ4F_contentChecksum.LZ4F_contentChecksumEnabled
  var compressed = compress_frame(input,prefs)
  #echo ($compressed)
  #echo ($compressed.len)
  for i in 0..1:
    var decompressed = decompress_frame(compressed)
  #echo("\n\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n" & decompressed)
  #writeFile("res",decompressed)
    echo (input == decompressed)

  
test_compress_frame()
