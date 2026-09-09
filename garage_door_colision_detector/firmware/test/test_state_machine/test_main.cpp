#include <unity.h>
#include <initializer_list>

#include "safety_state_machine.h"
#include "status_led.h"

void test_never_clear_immediately_after_boot() {
  SafetyStateMachine m(1000, 1500, 500);
  m.begin(0);
  const SafetyInputs clear{true, false, false};
  TEST_ASSERT_EQUAL_INT((int)SafetyState::BOOTING, (int)m.update(999, clear));
  TEST_ASSERT_EQUAL_INT((int)SafetyState::SELF_TEST, (int)m.update(1000, clear));
  TEST_ASSERT_EQUAL_INT((int)SafetyState::SELF_TEST, (int)m.update(2499, clear));
  TEST_ASSERT_NOT_EQUAL((int)SafetyState::CLEAR, (int)m.update(2500, clear));
  TEST_ASSERT_EQUAL_INT((int)SafetyState::CLEAR, (int)m.update(3000, clear));
}

void test_blocked_has_priority() {
  SafetyStateMachine m(0, 0, 10);
  m.begin(0);
  const SafetyInputs clear{true, false, false};
  const SafetyInputs blocked{false, true, false};
  m.update(0, clear);
  m.update(10, clear);
  TEST_ASSERT_EQUAL_INT((int)SafetyState::CLEAR, (int)m.state());
  TEST_ASSERT_EQUAL_INT((int)SafetyState::BLOCKED, (int)m.update(11, blocked));
}

void test_fault_has_highest_priority() {
  SafetyStateMachine m(0, 0, 0);
  m.begin(0);
  const SafetyInputs fault{true, false, true};
  TEST_ASSERT_EQUAL_INT((int)SafetyState::FAULT, (int)m.update(0, fault));
}

void test_rgb_mapping_and_fault_flash() {
  auto rgb = statusRgb(SafetyState::CLEAR, 0, 255, 80, 250);
  TEST_ASSERT_EQUAL_UINT8(0, rgb.red);
  TEST_ASSERT_EQUAL_UINT8(255, rgb.green);
  TEST_ASSERT_EQUAL_UINT8(0, rgb.blue);
  rgb = statusRgb(SafetyState::BLOCKED, 0, 255, 80, 250);
  TEST_ASSERT_EQUAL_UINT8(255, rgb.red);
  TEST_ASSERT_EQUAL_UINT8(0, rgb.green);
  for (auto state : {SafetyState::BOOTING, SafetyState::SELF_TEST, SafetyState::FAULT}) {
    rgb = statusRgb(state, 0, 255, 80, 250);
    TEST_ASSERT_EQUAL_UINT8(255, rgb.red);
    TEST_ASSERT_EQUAL_UINT8(80, rgb.green);
    rgb = statusRgb(state, 250, 255, 80, 250);
    TEST_ASSERT_EQUAL_UINT8(0, rgb.red);
    TEST_ASSERT_EQUAL_UINT8(0, rgb.green);
  }
  rgb = statusRgb(static_cast<SafetyState>(255), 0, 255, 80, 250);
  TEST_ASSERT_EQUAL_UINT8(255, rgb.red);
  rgb = statusRgb(SafetyState::FAULT, 0, 128, 80, 250);
  TEST_ASSERT_EQUAL_UINT8(40, rgb.green);
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_never_clear_immediately_after_boot);
  RUN_TEST(test_blocked_has_priority);
  RUN_TEST(test_fault_has_highest_priority);
  RUN_TEST(test_rgb_mapping_and_fault_flash);
  return UNITY_END();
}
