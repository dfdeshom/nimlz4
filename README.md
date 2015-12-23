# nimlz4
Nim wrapper for LZ4

## Simple compression (block API)
Use this API when you don't care about interoperability and assume
that you will only use this wrapper to compress and decompress strings:

    import lz4
    var input = readFile("LICENSE")
    var compressed = compress(input,level=1)
    var uncompressed = uncompress(compressed)
    echo(uncompressed==input)

If you would like a better compression ratio
at the expense of CPU timr, use `compress_more()`. 

## Frame compression (auto-framing API)
Use the frame API when you want your compressed data to be
decompressable by other programs.

    import lz4
    var prefs = newLZ4F_preferences()
    var compressed = compress_frame(input,prefs)
    var decompressed = uncompress_frame(compressed)
    echo(input == decompressed)
