## Why

SkyDrop 1 is the primary external sensor for the first BrandyFly release, but
its transport, message format, update frequency, and platform limits must be
verified before production integration. Building against assumptions could
create silent sensor corruption, unacceptable latency, or an impossible iOS
promise.

## What Changes

- Establish a permitted source of truth for the SkyDrop 1 transport and protocol.
- Add an Android Bluetooth Classic/SPP proof of concept behind the existing
  native-plugin boundary.
- Capture sanitised raw samples and define a deterministic replay fixture.
- Measure connection, sample-delivery, loss, and reconnect behaviour using
  monotonic timestamps.
- Record the confirmed iOS support boundary and any manufacturer-authorised
  alternative.

Non-goals:

- Ship production SkyDrop 1 support or automatic sensor fallback.
- Implement SkyDrop 2.
- Implement sensor fusion, audio-vario output, or flight recording.
- Reverse engineer protected interfaces or redistribute unauthorised material.

## Capabilities

### New Capabilities

- `skydrop1-transport-validation`: Defines the evidence and acceptance gates
  required before SkyDrop 1 can become a supported BrandyFly sensor source.

### Modified Capabilities

None.

## Impact

The change affects the Android side of `brandyfly_native`, synthetic or
sanitised replay fixtures, test tooling, and hardware-support documentation. It
does not alter flight-ready application behaviour. Raw captures must not contain
private flight locations unless explicitly sanitised, and unsupported iOS
behaviour must remain visible rather than hidden behind a success fallback.
