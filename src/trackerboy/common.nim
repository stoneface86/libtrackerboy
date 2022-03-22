##
## Module contains common types used throughout the library.
## 

type
    InvalidOperationDefect* = object of Defect
        ## Defect class for any operation that cannot be performed.
