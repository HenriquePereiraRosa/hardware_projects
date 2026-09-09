#include <Arduino.h>

#include "beam_sensor.h"
#include "configuration.h"
#include "safety_state_machine.h"
#include "status_led.h"

BeamSensor beams[4] = {
    {config::kBeamPins[0], config::kClearElectricalLevel, config::kBlockedDebounceMs},
    {config::kBeamPins[1], config::kClearElectricalLevel, config::kBlockedDebounceMs},
    {config::kBeamPins[2], config::kClearElectricalLevel, config::kBlockedDebounceMs},
    {config::kBeamPins[3], config::kClearElectricalLevel, config::kBlockedDebounceMs},
};

SafetyStateMachine machine(config::kBootTimeMs, config::kSelfTestTimeMs,
                           config::kClearConfirmMs);
SafetyState previousState = SafetyState::FAULT;
uint32_t nextReportMs = 0;

void setIndicators(SafetyState state, uint32_t now) {
  const auto rgb = statusRgb(state, now, config::kStatusBrightness,
                            config::kAmberGreenLevel, config::kFaultHalfPeriodMs);
  static bool initialized = false;
  static RgbLevels lastRgb{0, 0, 0};
  if (initialized && rgb.red == lastRgb.red && rgb.green == lastRgb.green &&
      rgb.blue == lastRgb.blue) return;
  // Clear the previous colour first. Do not pass through white/green when
  // switching between two unsafe colours. GPIOs drive gates, never LED loads.
  analogWrite(config::kGreenLedPin, 0);
  analogWrite(config::kRedLedPin, 0);
  analogWrite(config::kBlueLedPin, 0);
  analogWrite(config::kRedLedPin, rgb.red);
  analogWrite(config::kBlueLedPin, rgb.blue);
  analogWrite(config::kGreenLedPin, rgb.green);
  lastRgb = rgb;
  initialized = true;
}

void setup() {
  Serial.begin(115200);
  digitalWrite(config::kGreenLedPin, LOW);
  digitalWrite(config::kRedLedPin, LOW);
  digitalWrite(config::kBlueLedPin, LOW);
  pinMode(config::kGreenLedPin, OUTPUT);
  pinMode(config::kRedLedPin, OUTPUT);
  pinMode(config::kBlueLedPin, OUTPUT);
  pinMode(config::kAlignButtonPin, INPUT_PULLUP);
  for (uint8_t i = 0; i < config::kBeamCount; ++i) beams[i].begin();
  machine.begin(millis());
  setIndicators(machine.state(), millis());
  Serial.println("Garage Beam Safety: local safety logic active; Wi-Fi is not required.");
}

void loop() {
  const uint32_t now = millis();
  bool allClear = true;
  bool anyBlocked = false;
  for (uint8_t i = 0; i < config::kBeamCount; ++i) {
    beams[i].sample(now);
    allClear &= beams[i].isClear();
    anyBlocked |= beams[i].isBlocked();
  }

  // D0 has no active power-proof test. Electrical opens therefore report BLOCKED,
  // while diagnosticFault remains reserved for the D1 proof-test implementation.
  const SafetyInputs inputs{allClear, anyBlocked, false};
  const SafetyState state = machine.update(now, inputs);

  if (state != previousState) {
    Serial.printf("SYSTEM: %s\n", SafetyStateMachine::name(state));
    previousState = state;
  }
  setIndicators(state, now);

  if (now >= nextReportMs) {
    nextReportMs = now + 1000;
    for (uint8_t i = 0; i < config::kBeamCount; ++i) {
      Serial.printf("BEAM%u: %s\n", i + 1, beams[i].isClear() ? "CLEAR" : "BLOCKED/OPEN");
    }
    Serial.printf("SYSTEM: %s\n", SafetyStateMachine::name(state));
  }
  delay(1);
}
