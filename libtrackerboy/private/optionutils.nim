##[

.. include:: warning.rst

Utilities for working with std's `Option[T]`

]##

import std/[options, with]

template withSome*[T](opt: var Option[T]; body: untyped): untyped =
  ## 
  if opt.isSome():
    with opt.get():
      body

template onSome*[T](o: Option[T]; body: untyped): untyped =
  if o.isSome():
    template it(): lent T = o.get()
    body
