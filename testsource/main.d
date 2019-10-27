module testsource.main;

import ncompress42;

import std.stdio;

File source;
ubyte[] buffer0, buffer1, buffer2;
size_t position;

void main(string[] args)
{
	writeln(args[1]);
    NCompressCtxt context;
    source = File(args[1], "rb");
    buffer2.length = cast(size_t) source.size;
    buffer2 = source.rawRead(buffer2);
    extern (C) int memoryReader(ubyte* bytes, size_t numBytes, void* rwCtxt)
    {
        import core.stdc.string : memcpy;
		writeln(numBytes," is being read from buffer2. Remaining: ", buffer2.length - position);
        if (position + numBytes < buffer2.length)
        {
            memcpy(bytes, buffer2.ptr + position, numBytes);
            position += numBytes;
            return cast(int) numBytes;
        }
        else if (position + numBytes == buffer2.length)
        {
            return 0;
        }
        else
        {
            numBytes = buffer2.length - position;
            memcpy(bytes, buffer2.ptr + position, numBytes);
            position += numBytes;
            return cast(int) numBytes;
        }
    }

    extern (C) int memoryWriter(const(ubyte)* bytes, size_t numBytes, void* rwCtxt)
    {
        //import core.stdc.string : memcpy;
        const(ubyte)[] buffer3 = bytes[0 .. numBytes];
        buffer1 ~= buffer3.dup;
        return numBytes;
    }

    context.reader = &memoryReader;
    context.writer = &memoryWriter;
    nInitCompress(&context, 0);
	writeln("Compression initialized");
    NCompressError result = nCompress(&context);
    writeln(result);
    nFreeCompress(&context);
    buffer0 = buffer2;
    buffer2 = buffer1;
    context.reader = &memoryReader;
    context.writer = &memoryWriter;
    nInitDecompress(&context);
	position = 0;
	buffer1 = [];
	writeln("Decompression initialized");
    result = nDecompress(&context);
    writeln(result);
    writeln(buffer1 == buffer0);
	writeln(buffer0.length);
	writeln(buffer1.length);
}
