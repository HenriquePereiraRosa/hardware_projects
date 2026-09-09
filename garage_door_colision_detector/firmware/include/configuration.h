#pragma once

#include <stdint.h>

namespace config {

constexpr uint8_t kBeamCount = 3;  // D3 hardware uses three beams at 100 mm centres.
constexpr uint8_t kBeamPins[4] = {32, 33, 34, 35};
constexpr bool kClearElectricalLevel = false;  // NPN Light-ON through optocoupler.

constexpr uint32_t kBootTimeMs = 1000;
constexpr uint32_t kSelfTestTimeMs = 1500;
constexpr uint32_t kBlockedDebounceMs = 5;
constexpr uint32_t kClearConfirmMs = 500;

constexpr uint8_t kGreenLedPin = 25;
constexpr uint8_t kRedLedPin = 26;
constexpr uint8_t kBlueLedPin = 27;
// Requires the new three-MOSFET common-anode RGB output, not the legacy J5.
constexpr uint8_t kStatusBrightness = 255;  // 16..255, installation-adjustable.
constexpr uint8_t kAmberGreenLevel = 80;  // Tune red/green balance at the diffuser.
constexpr uint32_t kFaultHalfPeriodMs = 250;
static_assert(kStatusBrightness >= 16, "Do not configure an invisible safety lamp");
static_assert(kAmberGreenLevel > 0, "Amber requires both red and green");
static_assert(kFaultHalfPeriodMs > 0, "Fault flash interval must be nonzero");
constexpr uint8_t kAlignButtonPin = 13;

constexpr bool kWifiEnabled = false;

}  // namespace config
