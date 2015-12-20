import lz4
import clz4frame
var input:string
#input = readFile("/home/dfdeshom/code/lz4/lz4_Frame_format.md")
# input = readFile("/home/dfdeshom/code/lz4/lib/lz4.c")
input = readFile("big.txt")
# input = readFile("LICENSE")
input = readFile("/home/dfdeshom/cp.mp4")
echo ("uncompressed size: " & $input.len)

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
  #prefs.frameInfo.blockSizeID = LZ4F_max256KB
  var compressed = compress_frame(input,prefs)
  #echo ($compressed)
  #echo ($compressed.len)

  var decompressed = uncompress_frame(compressed)
  #echo("\n\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n" & decompressed)
  #writeFile("res",decompressed)
  echo (input == decompressed)

  
test_compress_frame()
