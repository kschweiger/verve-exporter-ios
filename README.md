<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/kschweiger/verve-exporter-ios/blob/4b582111d241a488c9bd13ad201f15cfd2d7cd1d/docs/assets/icons/AppIcon.appiconset/verve-dark.png" />
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/kschweiger/verve-exporter-ios/blob/4b582111d241a488c9bd13ad201f15cfd2d7cd1d/docs/assets/icons/AppIcon.appiconset/verve-light.png" />
    <img alt="verve exporter logo" src="https://github.com/kschweiger/verve-exporter-ios/blob/4b582111d241a488c9bd13ad201f15cfd2d7cd1d/docs/assets/icons/AppIcon.appiconset/verve-light.png" width="96" />

  </picture>
</p>

<h1 align="center">Verve Exporter</h1>

<p align="center">
  <img src="https://github.com/kschweiger/verve-exporter-ios/blob/4b582111d241a488c9bd13ad201f15cfd2d7cd1d/docs/assets/screenshots/base.png" width="300" alt="Verve Exporter default view">
  <img src="https://github.com/kschweiger/verve-exporter-ios/blob/4b582111d241a488c9bd13ad201f15cfd2d7cd1d/docs/assets/screenshots/filtered.png" width="300" alt="Verve Exporter filtered view">
</p>

Verve exporter is a lightweight open-source utility for iOS that exports activies tracked on you phone or watch as json files.

The json file follows geojson standards but adapts a opinonated schema.

Exports are GeoJSON `FeatureCollection`s with workout details in root `properties` and route or time-series data in `features`. The exporter supports GPS tracks with timestamps and matched heart rates, stationary workouts with heart-rate samples, and swimming metadata for available laps and sets. Other metrics are included when available.

## Example exports

These shortened examples show the shape of different exports. Values and coordinates are illustrative; arrays and unrelated properties are abbreviated with `...`.

### Stationary strength training

A workout without route or coordinates has a `null` geometry. Heart-rate samples can still be included as a time series:

```json
{
  "type": "FeatureCollection",
  "properties": {
    "verveVersion": "1.0",
    "generator": "VerveExporteriOS",
    "name": "Strength Training",
    "activityType": "Strength Training",
    "activitySubType": "Weight Training",
    "startTime": "2026-05-12T17:00:00+02:00",
    "durationSeconds": 2700,
    "stats": { "heartRate": { "avg": 112, "max": 148 } }
  },
  "features": [
    {
      "type": "Feature",
      "geometry": null,
      "properties": {
        "coordTimes": ["2026-05-12T17:00:20+02:00", "..."],
        "heartRates": [98, "..."]
      }
    }
  ]
}
```

### Walk or hike with coordinates

GPS activities include a `LineString`; each coordinate is `[longitude, latitude, elevation]` and aligns with a timestamp:

```json
{
  "type": "FeatureCollection",
  "properties": {
    "verveVersion": "1.0",
    "generator": "VerveExporteriOS",
    "name": "Hike",
    "activityType": "Foot Sports",
    "activitySubType": "Hike",
    "startTime": "2026-05-12T10:00:00+02:00",
    "durationSeconds": 5400,
    "totalDistanceMeters": 6200,
    "stats": { "heartRate": { "avg": 126, "max": 161 } }
  },
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [[11.58, 48.14, 520], [11.59, 48.15, 536], "..."]
      },
      "properties": {
        "coordTimes": ["2026-05-12T10:00:00+02:00", "2026-05-12T10:00:12+02:00", "..."],
        "heartRates": [104, 108, "..."]
      }
    }
  ]
}
```

### Swimming

Pool workouts have no route geometry. Available lap and set details are carried in `properties.metadata`:

```json
{
  "type": "FeatureCollection",
  "properties": {
    "verveVersion": "1.0",
    "generator": "VerveExporteriOS",
    "name": "Swimming",
    "activityType": "Swimming",
    "activitySubType": "Outdoor Pool",
    "startTime": "2026-05-12T16:00:00+02:00",
    "durationSeconds": 1800,
    "totalDistanceMeters": 1000,
    "stats": { "heartRate": { "avg": 132, "max": 158 } },
    "metadata": {
      "target": "SwimmingMetaData",
      "version": "1.0",
      "data": {
        "poolLengthMeters": 25,
        "lapCount": 4,
        "strokeStyles": ["freestyle"],
        "laps": [
          {
            "index": 0,
            "durationSeconds": 32,
            "distanceMeters": 25,
            "strokeStyle": "freestyle",
            "strokeCount": 18,
            "swolf": 50
          },
          "..."
        ],
        "sets": [
          {
            "index": 0,
            "lapStartIndex": 0,
            "lapEndIndex": 3,
            "lapCount": 4,
            "distanceMeters": 100
          },
          "..."
        ]
      }
    }
  },
  "features": [
    {
      "type": "Feature",
      "geometry": null,
      "properties": {
        "coordTimes": ["2026-05-12T16:00:05+02:00", "..."],
        "heartRates": [118, "..."]
      }
    }
  ]
}
```
