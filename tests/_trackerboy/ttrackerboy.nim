discard """
  action: "compile"
"""

import ../../src/trackerboy

static:
    assert $appVersion != ""
    assert $libVersion != ""
