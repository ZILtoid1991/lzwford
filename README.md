# lzwford
libncompress binding for D by László Szerémi (laszloszeremi@outlook.com, https://twitter.com/ziltoid1991, https://www.patreon.com/ShapeshiftingLizard, https://ko-fi.com/D1D45NEN).

The LZW algorithm is used in many file formats that were established in the past, like GIF and TIFF.

# The libncompress library

The libncompress library can be found here: https://github.com/als123/libncompress

For Windows, I've used an LLVM7.0 based clang, and created the .lib file using llvm-lib. Commening out the unistd.h line doesn't seem to affect the library, this might be a quick fix for that file. I put the libncompress.lib file into my project folder.