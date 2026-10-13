# Bundled EGM2008 geoid data

`egm2008-5.pgm` is the canonical, unchanged GeographicLib 5-minute global EGM2008 grid, derived from public NGA gravity-model data. It is unrelated to user locations or HealthKit data and is explicitly safe to track under `docs/SECURITY.md`.

- Download: https://downloads.sourceforge.net/project/geographiclib/geoids-distrib/egm2008-5.tar.bz2
- Archive member: `geoids/egm2008-5.pgm`
- SHA-256: `96d55e88db186ddae892b00c5f8cc42a37cdac8ddb69b6de00af8c75dffb34a3`
- Size: 18,671,444 bytes; 4320 columns and 2161 rows.
- Git handling: `.gitattributes` marks this exact asset binary, disabling text/line-ending conversion so the pinned bytes remain unchanged across checkouts.
- Publication: GeographicLib grid dated 2009-08-29; offset -108 m, scale 0.003 m per unsigned big-endian 16-bit sample.
- Grid origin: north pole at longitude zero, rows run south, columns run east without duplicating the longitude-zero column.
- Conversion: WGS 84 ellipsoidal height = approximate sea-level height + interpolated EGM2008 geoid height.
- Bilinear interpolation error reported by the grid: maximum 0.478 m, RMS 0.012 m relative to the underlying EGM2008 model, not total source-height uncertainty.

## Source and redistribution

NGA model data is public-domain U.S. government geophysical data. OSGeo's NGA-derived EGM2008 resource documentation also identifies the model data as public domain. Preserve this provenance and the original GeographicLib file header when redistributing the app. No GeographicLib program code is vendored; the app implements the documented PGM interpretation and bilinear arithmetic in Swift.

- NGA: https://earth-info.nga.mil/geograv
- GeographicLib grid format and interpolation: https://geographiclib.sourceforge.io/C++/doc/geoid.html
- NGA model redistribution provenance: https://github.com/OSGeo/PROJ-data/blob/master/us_nga/us_nga_README.txt

## Source-height limitation

Apple's current [altitude documentation](https://developer.apple.com/documentation/corelocation/cllocation/altitude) identifies EGM2008 in most cases and DMA 10x10 in rare cases, with typical differences below 5 m. Persisted/imported workouts do not establish which original geoid was used. The conversion remains an EGM2008-based ellipsoidal estimate, not recovery of the original receiver's measurement. HealthKit does not promise to persist CLLocation.ellipsoidalAltitude; it must not be used to detect whether conversion is needed.

All model lookup is offline. Only public model data is downloaded during development; workout positions are never sent to a service.

## Independent public test vectors

GeoidGridTests uses the first twelve records of GeographicLib's public NGA harmonic-synthesis reference dataset. They are generated global coordinates, not personal workout points. EGM2008 expectations are the fifth column of each record and are independent of the bundled interpolation code.

- Reference archive: https://downloads.sourceforge.net/project/geographiclib/testdata/GeoidHeights.dat.gz
- Reference archive SHA-256: `e0b9804694b3eac78ffd0b3df9cffd30a134d72007276e732ff72f9651bc9995`
- Full reference dataset remains a development-only temporary download; only the twelve numerical reference records are retained in tests.
