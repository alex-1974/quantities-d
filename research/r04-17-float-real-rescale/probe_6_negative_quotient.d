module r04_17_probe_6_negative_quotient;

import r04_17_binary32_kernel : rescaleQuotientBinary32;

enum value =
    rescaleQuotientBinary32(
        1.0f,
        1.0f,
        2,
        3);
