
#include "libtrackerboy.h"

#include <assert.h>
#include <stdio.h>

int main(void) {

    fputs("ltbInit()...", stdout);
    assert(ltbInit() == 0);
    puts("OK");

    puts("=== libtrackerboy/version ===");
    printf("libtrackerboy version: %s\n", ltbVersionString());
    printf("File revision: %d.%d\n", ltbVersionFileMajor(), ltbVersionFileMinor());

    puts("=== libtrackerboy/notes ===");
    int const note = 24; // C-4
    uint16_t const tone = ltbNotesLookupTone(note);
    uint8_t const noise = ltbNotesLookupNoise(note);
    printf("Note index 24 (C-4), Tone: $%03X, Noise: $%02X\n", tone, noise);

    ltbNotesLookupNoise(-1);

    return 0;
}
