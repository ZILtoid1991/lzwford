module ncompress42;

//public import ncompress;

/**
 * Used for emulating file reads, as the library is a port of ncompress.
 * The function must return the number of bytes read, 0 if EoF (or end of datasteam) has reached,
 * or -1 on errors.
 * rwCtxt can contain filenames if they're applicable.
 */
// alias NCmpStreamReader = extern (C) int function(ubyte* bytes, size_t numBytes, void* rwCtxt);
/**
 * Used for emulating file writes.
 * It must return the number of files pushed, or -1 on error
 */
// alias NCmpStreamWriter = extern (C) int function(const(ubyte)* bytes, size_t numBytes, void* rwCtxt);

/**
 * Used for storing function pointers and other contextual stuff.
 */
// struct NCompressCtxt
// {
    // NCmpStreamReader reader;
    // NCmpStreamWriter writer;
    // void* rwCtxt; // context for the reader and writer
//
    // void* priv;
// }

/** 
 * Error codes, mainly from decompression.
 */
// enum NCompressError
// {
    // NCMP_OK = 0,
//
    // NCMP_READ_ERROR, // an error from the reader
    // NCMP_WRITE_ERROR, // an error from the writer
//
    // NCMP_DATA_ERROR, // invalid compressed data format
    // NCMP_BITS_ERROR, // compressed with too large a bits parameter
    // NCMP_OTHER_ERROR, // some other internal error
// }

// extern (C):
/** 
 * Initialise for compression.
 * Set the reader, writer and read-write context in
 * the CompressCtxt struct. Then call initCompress()
 * The bits parameter is only used when compressing. It sets the maximum
 * size of a code word. The value must be in the range 9 to 16 or else
 * zero to select the default of 16.
 */
// void nInitCompress(NCompressCtxt* ctxt, int bits);
/**
 * Initialise for decompression.
 * Set the reader, writer and read-write context in
 * the CompressCtxt struct. Then call initDecompress()
 */
// void nInitDecompress(NCompressCtxt* ctxt);
///Frees all buffers up.
// void nFreeCompress(NCompressCtxt* ctxt);
///Compresses the datasteam
// NCompressError nCompress(NCompressCtxt* ctxt);
///Decompresses the datastream
// NCompressError nDecompress(NCompressCtxt* ctxt);

import core.stdc.config;
import core.stdc.stdlib;
import core.stdc.string;

alias Byte = ubyte;

alias NCmpStreamReader = int delegate(Byte* bytes, size_t numBytes, void* rwCtxt);
alias NCmpStreamWriter = int delegate(const Byte* bytes, size_t numBytes, void* rwCtxt);

struct NCompressCtxt
{
    NCmpStreamReader reader;
    NCmpStreamWriter writer;
    void* rwCtxt;

    void* priv;
}

enum NCompressError
{
    NCMP_OK = 0,

    NCMP_READ_ERROR,
    NCMP_WRITE_ERROR,

    NCMP_DATA_ERROR,
    NCMP_BITS_ERROR,
    NCMP_OTHER_ERROR,

}

alias code_int = c_long;
alias count_int = c_long;
alias cmp_code_int = c_long;

struct PrivState
{
    int block_mode;
    int maxbits;

    count_int[(1<<17)] htab;
    ushort[(1<<17)] codetab;

    Byte[(8192 +64)] inbuf;
    Byte[(8192 +2048)] outbuf;


    c_long bytes_in;
    c_long bytes_out;
}

pragma (inline, true)
void clear_htab(PrivState* ps)
{
    memset(ps.htab.ptr, -1, (1<<17) * count_int.sizeof);
}

pragma (inline, true)
void clear_tab_prefixof(PrivState* ps)
{
    memset(ps.codetab.ptr, 0, 256);
}

static void
createPrivState(NCompressCtxt* ctxt, int bits)
{
    if (!ctxt.priv)
    {
        PrivState* priv = cast(PrivState*)malloc(PrivState.sizeof);

        memset(priv, 0, PrivState.sizeof);

        priv.block_mode = 0x80;
        priv.maxbits = bits;
        priv.bytes_in = 0;
        priv.bytes_out = 0;

        ctxt.priv = priv;
    }
}



void
nInitCompress(NCompressCtxt* ctxt, int bits)
{
    if (bits == 0)
    {
        bits = 16;
    }
    else
    if (bits < 9)
    {
        bits = 9;
    }
    else
    if (bits > 16)
    {
        bits = 16;
    }

    ctxt.priv = (cast(void*)0);
    createPrivState(ctxt, bits);
}



void
nInitDecompress(NCompressCtxt* ctxt)
{
    ctxt.priv = (cast(void*)0);
    createPrivState(ctxt, 0);
}



void
nFreeCompress(NCompressCtxt* ctxt)
{
    if (ctxt.priv)
    {
        free(ctxt.priv);
        ctxt.priv = (cast(void*)0);
    }
}



static int[256]
primetab =
[
     1013, -1061, 1109, -1181, 1231, -1291, 1361, -1429,
     1481, -1531, 1583, -1627, 1699, -1759, 1831, -1889,
     1973, -2017, 2083, -2137, 2213, -2273, 2339, -2383,
     2441, -2531, 2593, -2663, 2707, -2753, 2819, -2887,
     2957, -3023, 3089, -3181, 3251, -3313, 3361, -3449,
     3511, -3557, 3617, -3677, 3739, -3821, 3881, -3931,
     4013, -4079, 4139, -4219, 4271, -4349, 4423, -4493,
     4561, -4639, 4691, -4783, 4831, -4931, 4973, -5023,
     5101, -5179, 5261, -5333, 5413, -5471, 5521, -5591,
     5659, -5737, 5807, -5857, 5923, -6029, 6089, -6151,
     6221, -6287, 6343, -6397, 6491, -6571, 6659, -6709,
     6791, -6857, 6917, -6983, 7043, -7129, 7213, -7297,
     7369, -7477, 7529, -7577, 7643, -7703, 7789, -7873,
     7933, -8017, 8093, -8171, 8237, -8297, 8387, -8461,
     8543, -8627, 8689, -8741, 8819, -8867, 8963, -9029,
     9109, -9181, 9241, -9323, 9397, -9439, 9511, -9613,
     9677, -9743, 9811, -9871, 9941,-10061,10111,-10177,
    10259,-10321,10399,-10477,10567,-10639,10711,-10789,
    10867,-10949,11047,-11113,11173,-11261,11329,-11423,
    11491,-11587,11681,-11777,11827,-11903,11959,-12041,
    12109,-12197,12263,-12343,12413,-12487,12541,-12611,
    12671,-12757,12829,-12917,12979,-13043,13127,-13187,
    13291,-13367,13451,-13523,13619,-13691,13751,-13829,
    13901,-13967,14057,-14153,14249,-14341,14419,-14489,
    14557,-14633,14717,-14767,14831,-14897,14983,-15083,
    15149,-15233,15289,-15359,15427,-15497,15583,-15649,
    15733,-15791,15881,-15937,16057,-16097,16189,-16267,
    16363,-16447,16529,-16619,16691,-16763,16879,-16937,
    17021,-17093,17183,-17257,17341,-17401,17477,-17551,
    17623,-17713,17791,-17891,17957,-18041,18097,-18169,
    18233,-18307,18379,-18451,18523,-18637,18731,-18803,
    18919,-19031,19121,-19211,19273,-19381,19429,-19477
];

NCompressError
nCompress(NCompressCtxt* ctxt)
{
    c_long hp;
    int rpos;
    c_long fc;
    int outbits;
    int rlop;
    int rsize;
    int stcode;
    code_int free_ent;
    int boff;
    int n_bits;
    int ratio;
    c_long checkpoint;
    code_int extcode;
    PrivState* ps = cast(PrivState*)ctxt.priv;

    union fcode_t
    {
        c_long code;
        align(1) struct e_t
        {
            Byte c;
            ushort ent;
        }
        e_t e;
    }
    fcode_t fcode;

    ratio = 0;
    checkpoint = 10000;
    extcode = (1L << (n_bits = 9))+1;
    stcode = 1;
    free_ent = 257;

    ps.outbuf[0] = cast(Byte)'\037';
    ps.outbuf[1] = cast(Byte)'\235';
    ps.outbuf[2] = cast(char)(ps.maxbits | ps.block_mode);
    boff = outbits = (3<<3);
    fcode.code = 0;

    clear_htab(ps);

    while ((rsize = (ctxt.reader)(ps.inbuf.ptr, 8192, ctxt.rwCtxt)) > 0)
    {
        if (ps.bytes_in == 0)
        {
            fcode.e.ent = ps.inbuf[0];
            rpos = 1;
        }
        else
            rpos = 0;

        rlop = 0;

        do
        {
            if (free_ent >= extcode && fcode.e.ent < 257)
            {
                if (n_bits < ps.maxbits)
                {
                    boff = outbits = (outbits-1)+((n_bits<<3)-
                                ((outbits-boff-1+(n_bits<<3))%(n_bits<<3)));
                    if (++n_bits < ps.maxbits)
                        extcode = (1 << (n_bits))+1;
                    else
                        extcode = (1 << (n_bits));
                }
                else
                {
                    extcode = (1 << (16))+8192;
                    stcode = 0;
                }
            }

            if (!stcode && ps.bytes_in >= checkpoint && fcode.e.ent < 257)
            {
                c_long rat;

                checkpoint = ps.bytes_in + 10000;

                if (ps.bytes_in > 0x007fffff)
                {
                    rat = (ps.bytes_out + (outbits>>3)) >> 8;

                    if (rat == 0)
                        rat = 0x7fffffff;
                    else
                        rat = ps.bytes_in / rat;
                }
                else
                {
                    rat = (ps.bytes_in << 8) / (ps.bytes_out+(outbits>>3));
                }

                if (rat >= ratio)
                {
                    ratio = cast(int)rat;
                }
                else
                {
                    ratio = 0;

                    clear_htab(ps);
                    {
                        Byte *p = &(ps.outbuf)[(outbits)>>3];
                        c_long i = (cast(c_long)(256))<<((outbits)&0x7);
                        p[0] |= cast(Byte)(i);
                        p[1] |= cast(Byte)(i>>8);
                        p[2] |= cast(Byte)(i>>16);
                        (outbits) += (n_bits);
                    }

                    boff = outbits = (outbits-1)+((n_bits<<3)-
                                ((outbits-boff-1+(n_bits<<3))%(n_bits<<3)));

                    extcode = (1L << (n_bits = 9))+1;
                    free_ent = 257;
                    stcode = 1;
                }
            }

            if (outbits >= (8192<<3))
            {
                if ((ctxt.writer)(ps.outbuf.ptr, 8192, ctxt.rwCtxt) != 8192)
                {
                    return NCompressError.NCMP_WRITE_ERROR;
                }

                outbits -= (8192<<3);
                boff = -(((8192<<3)-boff)%(n_bits<<3));
                ps.bytes_out += 8192;

                memcpy(ps.outbuf.ptr, ps.outbuf.ptr+8192, (outbits>>3)+1);
                memset(ps.outbuf.ptr+(outbits>>3)+1, '\0', 8192);
            }

            {
                int i = rsize-rlop;

                if (cast(code_int)i > extcode-free_ent)
                {
                    i = cast(int)(extcode-free_ent);
                }

                if (i > (((8192 +2048) - 32)*8 - outbits) / n_bits)
                {
                    i = (((8192 +2048) - 32)*8 - outbits) / n_bits;
                }

                if (!stcode && cast(c_long)i > checkpoint - ps.bytes_in)
                {
                    i = cast(int)(checkpoint - ps.bytes_in);
                }

                rlop += i;
                ps.bytes_in += i;
            }

            goto next;

hfound: fcode.e.ent = ps.codetab[hp];

next: if (rpos >= rlop)
            {
                goto endlop;
            }

next2: fcode.e.c = ps.inbuf[rpos++];
            {
                c_long i;
                c_long p;
                fc = fcode.code;
                hp = (((cast(c_long)(fcode.e.c)) << (17 -8)) ^ cast(c_long)(fcode.e.ent));

                if ((i = ps.htab[hp]) == fc) goto hfound;
                if (i == -1) goto _out;

                p = primetab[fcode.e.c];
lookup: hp = (hp+p)&((1<<17)-1);
                if ((i = ps.htab[hp]) == fc) goto hfound;
                if (i == -1) goto _out;
                hp = (hp+p)&((1<<17)-1);
                if ((i = ps.htab[hp]) == fc) goto hfound;
                if (i == -1) goto _out;
                hp = (hp+p)&((1<<17)-1);
                if ((i = ps.htab[hp]) == fc) goto hfound;
                if (i == -1) goto _out;
                goto lookup;
            }
_out:
            { Byte *p = &(ps.outbuf)[(outbits)>>3];
                c_long i = (cast(c_long)(fcode.e.ent))<<((outbits)&0x7);
                p[0] |= cast(Byte)(i);
                p[1] |= cast(Byte)(i>>8);
                p[2] |= cast(Byte)(i>>16);
                (outbits) += (n_bits);
            }

            {
                c_long _fc;
                _fc = fcode.code;
                fcode.e.ent = fcode.e.c;


                if (stcode)
                {
                    ps.codetab[hp] = cast(ushort)free_ent++;
                    ps.htab[hp] = _fc;
                }
            }

            goto next;

endlop: if (fcode.e.ent >= 257 && rpos < rsize)
            {
                goto next2;
            }

            if (rpos > rlop)
            {
                ps.bytes_in += rpos-rlop;
                rlop = rpos;
            }
        }
        while (rlop < rsize);
    }

    if (rsize < 0)
    {
        return NCompressError.NCMP_OTHER_ERROR;
    }

    if (ps.bytes_in > 0)
    {
        {
            Byte *p = &(ps.outbuf)[(outbits)>>3];
            c_long i = (cast(c_long)(fcode.e.ent))<<((outbits)&0x7);
            p[0] |= cast(Byte)(i);
            p[1] |= cast(Byte)(i>>8);
            p[2] |= cast(Byte)(i>>16);
            (outbits) += (n_bits);
        }
    }

    if (ctxt.writer(ps.outbuf.ptr, (outbits+7)>>3, ctxt.rwCtxt) != (outbits+7)>>3)
    {
        return NCompressError.NCMP_WRITE_ERROR;
    }

    ps.bytes_out += (outbits+7)>>3;

    return NCompressError.NCMP_OK;
}

NCompressError
nDecompress(NCompressCtxt* ctxt)
{
    Byte *stackp;
    code_int code;
    int finchar;
    code_int oldcode;
    code_int incode;
    int inbits;
    int posbits;
    int outpos;
    int insize;
    int bitmask;
    code_int free_ent;
    code_int maxcode;
    code_int maxmaxcode;
    int n_bits;
    int rsize;
    PrivState* ps = cast(PrivState*)ctxt.priv;

    ps.bytes_in = 0;
    ps.bytes_out = 0;
    insize = 0;

    while (insize < 3 && (rsize = ctxt.reader(ps.inbuf.ptr + insize, 8192, ctxt.rwCtxt)) > 0)
    {
        insize += rsize;
    }

    if (insize < 3 || ps.inbuf[0] != cast(Byte)'\037' || ps.inbuf[1] != cast(Byte)'\235')
    {
        return NCompressError.NCMP_DATA_ERROR;
    }

    ps.maxbits = ps.inbuf[2] & 0x1f;
    ps.block_mode = ps.inbuf[2] & 0x80;

    maxmaxcode = (1 << (ps.maxbits));

    if (ps.maxbits > 16)
    {
        return NCompressError.NCMP_BITS_ERROR;
    }

    ps.bytes_in = insize;
    maxcode = (1 << (n_bits = 9))-1;
    bitmask = (1<<n_bits)-1;
    oldcode = -1;
    finchar = 0;
    outpos = 0;
    posbits = 3<<3;

    free_ent = ((ps.block_mode) ? 257 : 256);

    clear_tab_prefixof(ps);

    for (code = 255 ; code >= 0 ; --code)
    {
        (cast(Byte*)(ps.htab))[code] = cast(Byte)code;
    }

    do
    {
resetbuf:
        {
            int i;
            int e;
            int o;

            o = posbits >> 3;
            e = (o <= insize) ? insize - o : 0;

            for (i = 0 ; i < e ; ++i)
            {
                ps.inbuf[i] = ps.inbuf[i+o];
            }

            insize = e;
            posbits = 0;
        }

        if (insize < (8192 +64) - 8192)
        {
            if ((rsize = ctxt.reader(ps.inbuf.ptr + insize, 8192, ctxt.rwCtxt)) < 0)
            {
                return NCompressError.NCMP_READ_ERROR;
            }

            insize += rsize;
        }

        inbits = ((rsize > 0) ? (insize - insize%n_bits)<<3 :
                                (insize<<3)-(n_bits-1));

        while (inbits > posbits)
        {
            if (free_ent > maxcode)
            {
                posbits = ((posbits-1) + ((n_bits<<3) -
                                 (posbits-1+(n_bits<<3))%(n_bits<<3)));

                ++n_bits;
                if (n_bits == ps.maxbits)
                    maxcode = maxmaxcode;
                else
                    maxcode = (1 << (n_bits))-1;

                bitmask = (1<<n_bits)-1;
                goto resetbuf;
            }

            {
                Byte *p = &(ps.inbuf)[(posbits)>>3];
                (code) = (((cast(c_long)(p[0]))|(cast(c_long)(p[1])<<8)| (cast(c_long)(p[2])<<16))>>((posbits)&0x7))&(bitmask);
                (posbits) += (n_bits);
            }

            if (oldcode == -1)
            {
                if (code >= 256) {




                    return NCompressError.NCMP_DATA_ERROR;
                }
                ps.outbuf[outpos++] = cast(Byte)(finchar = cast(int)(oldcode = code));
                continue;
            }

            if (code == 256 && ps.block_mode)
            {
                clear_tab_prefixof(ps);
                free_ent = 257 - 1;
                posbits = ((posbits-1) + ((n_bits<<3) -
                            (posbits-1+(n_bits<<3))%(n_bits<<3)));
                maxcode = (1L << (n_bits = 9))-1;
                bitmask = (1<<n_bits)-1;
                goto resetbuf;
            }

            incode = code;
            stackp = (cast(Byte*)&(ps.htab[(1<<17)-1]));

            if (code >= free_ent)
            {
                if (code > free_ent)
                {
                    return NCompressError.NCMP_DATA_ERROR;
                }

                *--stackp = cast(Byte)finchar;
                code = oldcode;
            }

            while (cast(cmp_code_int)code >= cast(cmp_code_int)256)
            {

                *--stackp = (cast(Byte*)(ps.htab))[code];
                code = ps.codetab[code];
            }

            *--stackp = (Byte)(finchar = (cast(Byte*)(ps.htab))[code]);


            {
                // int i;
                sizediff_t i;
                if (outpos + (i = ((cast(Byte*)&(ps.htab[(1<<17)-1])) - stackp)) >= 8192)
                {
                    do
                    {
                        if (i > 8192 - outpos)
                        {
                            i = 8192 -outpos;
                        }

                        if (i > 0)
                        {
                            memcpy(ps.outbuf.ptr + outpos, stackp, i);
                            outpos += i;
                        }

                        if (outpos >= 8192)
                        {
                            if ((ctxt.writer)(ps.outbuf.ptr, outpos, ctxt.rwCtxt) != outpos)
                            {
                                return NCompressError.NCMP_WRITE_ERROR;
                            }

                            outpos = 0;
                        }
                        stackp+= i;
                    }
                    while ((i = ((cast(Byte *)&(ps.htab[(1<<17)-1])) - stackp)) > 0);
                }
                else
                {
                    memcpy(ps.outbuf.ptr + outpos, stackp, i);
                    outpos += i;
                }
            }

            if ((code = free_ent) < maxmaxcode)
            {
                ps.codetab[code] = cast(ushort)oldcode;
                (cast(Byte *)(ps.htab))[code] = cast(Byte)finchar;
                free_ent = code+1;
            }

            oldcode = incode;
        }

        ps.bytes_in += rsize;
    }
    while (rsize > 0);

    if (outpos > 0 && ctxt.writer(ps.outbuf.ptr, outpos, ctxt.rwCtxt) != outpos)
    {
        return NCompressError.NCMP_WRITE_ERROR;
    }

    return NCompressError.NCMP_OK;
}
