
// header file for the exported libtrackerboy C interface (libtrackerboyc.nim)

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define LTB_API(ret, func) ret func

LTB_API(int, ltbInit)(void);

LTB_API(int, ltbVersionMajor)(void);
LTB_API(int, ltbVersionMinor)(void);
LTB_API(int, ltbVersionPatch)(void);
LTB_API(const char*, ltbVersionString)(void);
LTB_API(int, ltbVersionFileMajor)(void);
LTB_API(int, ltbVersionFileMinor)(void);

#ifdef __cplusplus
}
#endif
