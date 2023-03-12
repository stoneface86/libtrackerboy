##[
.. include:: warning.rst
]##

import ../version

type
  ModulePrivate* = object
    version*: Version
    revisionMajor*: int
    revisionMinor*: int
