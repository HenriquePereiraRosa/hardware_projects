#pragma once

#include <stdint.h>

enum class SafetyState : uint8_t { BOOTING, SELF_TEST, CLEAR, BLOCKED, FAULT };

struct SafetyInputs {
  bool allClear;
  bool anyBlocked;
  bool diagnosticFault;
};

class SafetyStateMachine {
 public:
  SafetyStateMachine(uint32_t bootMs, uint32_t selfTestMs, uint32_t clearConfirmMs);
  void begin(uint32_t nowMs);
  SafetyState update(uint32_t nowMs, const SafetyInputs& inputs);
  SafetyState state() const { return state_; }
  static const char* name(SafetyState state);

 private:
  SafetyState state_ = SafetyState::BOOTING;
  uint32_t stateSinceMs_ = 0;
  uint32_t allClearSinceMs_ = 0;
  bool clearTimerActive_ = false;
  uint32_t bootMs_;
  uint32_t selfTestMs_;
  uint32_t clearConfirmMs_;
  void transition(SafetyState next, uint32_t nowMs);
};

