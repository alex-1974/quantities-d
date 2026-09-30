module r04_17_probe_6_negative_product;

import r04_17_binary32_kernel : rescaleProductBinary32;

enum value =
    rescaleProductBinary32(
        1.0f,
        1.0f,
        2,
        3);
