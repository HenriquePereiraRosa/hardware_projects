#pragma once

#include <stdint.h>

class BeamSensor {
 public:
  BeamSensor(uint8_t pin, bool clearLevel, uint32_t blockedDebounceMs);
  void begin();
  void sample(uint32_t nowMs);
  bool isClear() const { return clear_; }
  bool isBlocked() const { return !clear_; }
  uint8_t pin() const { return pin_; }

 private:
  uint8_t pin_;
  bool clearLevel_;
  uint32_t blockedDebounceMs_;
  bool clear_ = false;  // Safe default until proven clear.
  bool candidateClear_ = false;
  uint32_t candidateSinceMs_ = 0;
};

