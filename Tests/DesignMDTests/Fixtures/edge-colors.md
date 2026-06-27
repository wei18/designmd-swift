---
name: Colors
colors:
  primary: "rgb(255 0 0)"
  a: "hsl(120 100% 50%)"
  b: "color-mix(in srgb, red 30%, blue)"
  c: cornflowerblue
  alias: "{colors.primary}"
  loop1: "{colors.loop2}"
  loop2: "{colors.loop1}"
components:
  card:
    backgroundColor: "{colors.a}"
    textColor: "{colors.b}"
---

## Colors
Stuff.
