module ncompress42;

/**
 * Used for emulating file reads, as the library is a port of ncompress.
 * The function must return the number of bytes read, 0 if EoF (or end of datasteam) has reached,
 * or -1 on errors.
 * rwCtxt can contain filenames if they're applicable.
 */
alias NCmpStreamReader = extern (C) int function(ubyte* bytes, size_t numBytes, void* rwCtxt);
/**
 * Used for emulating file writes.
 * It must return the number of files pushed, or -1 on error
 */
alias NCmpStreamWriter = extern (C) int function(const(ubyte)* bytes, size_t numBytes, void* rwCtxt);

/**
 * Used for storing function pointers and other contextual stuff.
 */
struct NCompressCtxt
{
    NCmpStreamReader reader;
    NCmpStreamWriter writer;
    void* rwCtxt; // context for the reader and writer

    void* priv;
}

/** 
 * Error codes, mainly from decompression.
 */
enum NCompressError
{
    NCMP_OK = 0,

    NCMP_READ_ERROR, // an error from the reader
    NCMP_WRITE_ERROR, // an error from the writer

    NCMP_DATA_ERROR, // invalid compressed data format
    NCMP_BITS_ERROR, // compressed with too large a bits parameter
    NCMP_OTHER_ERROR, // some other internal error
}

extern (C):
/** 
 * Initialise for compression.
 * Set the reader, writer and read-write context in
 * the CompressCtxt struct. Then call initCompress()
 * The bits parameter is only used when compressing. It sets the maximum
 * size of a code word. The value must be in the range 9 to 16 or else
 * zero to select the default of 16.
 */
void nInitCompress(NCompressCtxt* ctxt, int bits);
/**
 * Initialise for decompression.
 * Set the reader, writer and read-write context in
 * the CompressCtxt struct. Then call initDecompress()
 */
void nInitDecompress(NCompressCtxt* ctxt);
///Frees all buffers up.
void nFreeCompress(NCompressCtxt* ctxt);
///Compresses the datasteam
NCompressError nCompress(NCompressCtxt* ctxt);
///Decompresses the datastream
NCompressError nDecompress(NCompressCtxt* ctxt);
