
when (NimPatch and 1) == 0:
  # test parallelization for stable nim releases only
  --threads:on
  switch("d", "nimtestParallel")
switch("path", "../")