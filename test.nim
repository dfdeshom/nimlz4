import lz4
var input = readFile("LICENSE")
var compressed = compress(input,level=1)
echo("compressed: " & $compressed)
echo("compressed length: " & $compressed.len)
echo("original length: " & $input.len)

var uncompressed = uncompress(compressed)
echo("uncompressed==input: " & $(uncompressed==input))
