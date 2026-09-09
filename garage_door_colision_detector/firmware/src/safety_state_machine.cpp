#include "safety_state_machine.h"

SafetyStateMachine::SafetyStateMachine(uint32_t bootMs, uint32_t selfTestMs,
                                       uint32_t clearConfirmMs)
    : bootMs_(bootMs), selfTestMs_(selfTestMs), clearConfirmMs_(clearConfirmMs) {}

void SafetyStateMachine::begin(uint32_t nowMs) {
  state_ = SafetyState::BOOTING;
  stateSinceMs_ = nowMs;
  allClearSinceMs_ = nowMs;
  clearTimerActive_ = false;
}

void SafetyStateMachine::transition(SafetyState next, uint32_t nowMs) {
  if (state_ == next) return;
  state_ = next;
  stateSinceMs_ = nowMs;
  clearTimerActive_ = false;
}

SafetyState SafetyStateMachine::update(uint32_t nowMs, const SafetyInputs& inputs) {
  if (inputs.diagnosticFault) {
    transition(SafetyState::FAULT, nowMs);
    return state_;
  }

  if (state_ == SafetyState::BOOTING) {
    if (nowMs - stateSinceMs_ >= bootMs_) transition(SafetyState::SELF_TEST, nowMs);
    return state_;
  }

  if (state_ == SafetyState::SELF_TEST && nowMs - stateSinceMs_ < selfTestMs_) {
    return state_;
  }

  // Blocking has priority and does not wait for the clear-confirmation timer.
  if (inputs.anyBlocked || !inputs.allClear) {
    transition(SafetyState::BLOCKED, nowMs);
    return state_;
  }

  if (!clearTimerActive_) {
    clearTimerActive_ = true;
    allClearSinceMs_ = nowMs;
  }
  if (nowMs - allClearSinceMs_ >= clearConfirmMs_) {
    transition(SafetyState::CLEAR, nowMs);
  } else if (state_ != SafetyState::SELF_TEST) {
    state_ = SafetyState::BLOCKED;
  }
  return state_;
}

const char* SafetyStateMachine::name(SafetyState state) {
  switch (state) {
    case SafetyState::BOOTING: return "BOOTING";
    case SafetyState::SELF_TEST: return "SELF_TEST";
    case SafetyState::CLEAR: return "CLEAR";
    case SafetyState::BLOCKED: return "BLOCKED";
    case SafetyState::FAULT: return "FAULT";
  }
  return "FAULT";
}

