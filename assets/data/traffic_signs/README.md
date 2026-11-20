# Offline traffic sign data

This directory intentionally contains **no synthetic traffic-sign database**.

The Flutter application only enables live signs when this directory contains
the verified file `traffic_signs.sqlite`. The expected bundled binary is
the user's validated, 151,228-row SQLite/RTree database from the provided
GeoJSON inputs. SHA-256:

`a8dc5b6f3b09546604a395d3236a9a9b12872cc81162e86db9f2a878e5319ec7`

Sources:
- traffic_signs.geojson: 20f59d11fc0f98df3f7c830165ce14684915fa98b2054d017cc09fcab017d5ff
- speed_limit_signs.geojson: 77142d75a7f03cd3ada06804743e55ed49c5ab3ceb0e8dca0afe95616f481dc7

How to package: copy the owner's validated database into this directory
at the path `assets/data/traffic_signs/traffic_signs.sqlite`, then build
with Flutter. It must not be generated from fake sample points. A build that
contains only README.md displays an explicit "dataset not packaged" message.

The database is a separate read-only map-reference layer and MUST NOT
feed automatic legal speed limits or taxi-fare calculations.
