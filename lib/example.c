
#include "libtrackerboy.h"

#include <assert.h>
#include <stdio.h>

int main(void) {

    assert(ltbInit() == 0);

    printf("libtrackerboy version: %s\n", ltbVersionString());
    printf("File revision: %d.%d\n", ltbVersionFileMajor(), ltbVersionFileMinor());

    return 0;
}
