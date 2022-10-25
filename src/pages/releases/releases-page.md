---
pagination:
  data: releasesByTag
  size: 1
  alias: release
  resolve: values
layout: layouts/release.njk
permalink: "releases/{{ release.version }}/"
---
{{ release.changes }}