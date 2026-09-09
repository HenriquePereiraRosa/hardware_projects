#pragma once
#include <stdint.h>
#include "safety_state_machine.h"

struct RgbLevels { uint8_t red; uint8_t green; uint8_t blue; };

// Pure mapping: independent of Arduino, Wi-Fi and the optical decision logic.
inline RgbLevels statusRgb(SafetyState state, uint32_t now,
                           uint8_t brightness, uint8_t amberGreen,
                           uint32_t faultHalfPeriod) {
  if (state == SafetyState::CLEAR) return {0, brightness, 0};
  if (state == SafetyState::BLOCKED) return {brightness, 0, 0};
  // Unknown enum values also fall back to fault indication. Blink distinguishes
  // fault from valid steady green even if the red die fails open. This is not
  // electrical lamp-health monitoring and cannot diagnose stuck-on drivers.
  const bool on = faultHalfPeriod == 0 || (now / faultHalfPeriod) % 2 == 0;
  if (!on) return {0, 0, 0};
  const uint8_t green = static_cast<uint8_t>(
      (static_cast<uint16_t>(brightness) * amberGreen + 127) / 255);
  return {brightness, green, 0};
}
