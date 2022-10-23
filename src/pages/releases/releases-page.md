---
pagination:
  data: releases
  size: 1
  alias: release
layout: layouts/release.njk
permalink: "releases/{{ release.version }}/"
---
{{ release.changes }}