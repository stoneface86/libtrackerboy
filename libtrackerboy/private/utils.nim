##[

.. include:: warning.rst

Miscellaneous utilities.

]##

type
  EqRef*[T] = object
    ## EqRef: Deep equality ref
    ## 
    ## Ref wrapper type that changes the equality operator by testing for
    ## deep equality.
    ##
    src*: ref T
      ## The source reference of the wrapper
      ##

func deepEquals*[T](a, b: ref T;): bool =
  ## Deep equality test for two refs. Returns true if either:
  ## - they are both nil
  ## - they are not both nil and their referenced data is equivalent
  ##
  runnableExamples:
    var a, b: ref int
    assert a.deepEquals(b)      # both are nil
    a = new(int)
    b = new(int)
    a[] = 2
    b[] = 3
    assert not a.deepEquals(b)  # both are not nil, but the referenced data are not the same
    b[] = a[]
    assert a.deepEquals(b)      # both are not nil and the referenced data are the same
    b = nil
    assert not a.deepEquals(b)  # one of the refs is nil
  if a == b:
    # a and b are both nil, or are the same ref, so a == b
    true
  else:
    if a.isNil or b.isNil:
      # a or b is nil (but not both), so a != b
      false
    else:
      # a and b are not nil but different refs, check if their data is equivalent.
      a[] == b[]

template toEqRef*[T](val: ref T): EqRef[T] =
  ## Converts a ref to an EqRef
  ##
  EqRef[T](src: val)

template `==`*[T](lhs, rhs: EqRef[T];): bool =
  ## Equality test using deepEquals
  ##
  runnableExamples:
    var a, b: EqRef[int]
    assert a == b
  lhs.src.deepEquals(rhs.src)

template defaultInit*(): untyped = discard
  ## Alias for `discard`, to indicate that default initialization is intended.
  ##
