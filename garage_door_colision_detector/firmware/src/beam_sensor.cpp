#include "beam_sensor.h"

#ifdef ARDUINO
#include <Arduino.h>

BeamSensor::BeamSensor(uint8_t pin, bool clearLevel, uint32_t blockedDebounceMs)
    : pin_(pin), clearLevel_(clearLevel), blockedDebounceMs_(blockedDebounceMs) {}

void BeamSensor::begin() {
  pinMode(pin_, INPUT);  // Hardware provides a 10k pull-up, including GPIO34/35.
  clear_ = false;
  candidateClear_ = false;
  candidateSinceMs_ = millis();
}

void BeamSensor::sample(uint32_t nowMs) {
  const bool rawClear = (digitalRead(pin_) != 0) == clearLevel_;
  if (rawClear != candidateClear_) {
    candidateClear_ = rawClear;
    candidateSinceMs_ = nowMs;
  }

  if (!candidateClear_) {
    // Unsafe direction is accepted after only the short electrical-noise filter.
    if (nowMs - candidateSinceMs_ >= blockedDebounceMs_) clear_ = false;
  } else {
    // System-level state machine applies the longer 500 ms clear confirmation.
    clear_ = true;
  }
}
#else
BeamSensor::BeamSensor(uint8_t pin, bool clearLevel, uint32_t blockedDebounceMs)
    : pin_(pin), clearLevel_(clearLevel), blockedDebounceMs_(blockedDebounceMs) {}
void BeamSensor::begin() {}
void BeamSensor::sample(uint32_t) {}
#endif

