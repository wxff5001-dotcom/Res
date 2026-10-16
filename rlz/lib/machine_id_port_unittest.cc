// Copyright 2026 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// PORT: replaces upstream machine_id_unittest.cc, which pulls
// rlz/test/rlz_test_helpers.h and with it the RLZ value store. These cover the
// properties this tree actually depends on.

#include "rlz/lib/machine_id.h"

#include <string>

#include "testing/gtest/include/gtest/gtest.h"

namespace rlz_lib {
namespace {

TEST(MachineIdTest, ReturnsAnId) {
  std::string id;
  ASSERT_TRUE(GetMachineId(&id));
  EXPECT_FALSE(id.empty());
}

// SHA1 of the SID (20 bytes) plus the volume id (4 bytes) plus a CRC8 check
// byte, hex encoded: 25 bytes -> 50 characters.
TEST(MachineIdTest, HasTheDocumentedShape) {
  std::string id;
  ASSERT_TRUE(GetMachineId(&id));

  EXPECT_EQ(50u, id.size());
  for (char c : id) {
    EXPECT_TRUE((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F'))
        << "unexpected character '" << c << "' in " << id;
  }
}

// The whole point of using the machine SID rather than a drive serial: the
// value has to be the same every time it is asked for on one machine.
TEST(MachineIdTest, IsStableAcrossCalls) {
  std::string first;
  std::string second;
  ASSERT_TRUE(GetMachineId(&first));
  ASSERT_TRUE(GetMachineId(&second));
  EXPECT_EQ(first, second);
}

// GetMachineIdImpl is deterministic given its inputs, so the same raw inputs
// must map to the same id and different inputs to different ids.
TEST(MachineIdTest, DerivationIsDeterministic) {
  std::string a;
  std::string b;
  ASSERT_TRUE(testing::GetMachineIdImpl(u"S-1-5-21-1-2-3", 0x11223344, &a));
  ASSERT_TRUE(testing::GetMachineIdImpl(u"S-1-5-21-1-2-3", 0x11223344, &b));
  EXPECT_EQ(a, b);

  std::string different_sid;
  ASSERT_TRUE(
      testing::GetMachineIdImpl(u"S-1-5-21-9-9-9", 0x11223344, &different_sid));
  EXPECT_NE(a, different_sid);

  std::string different_volume;
  ASSERT_TRUE(testing::GetMachineIdImpl(u"S-1-5-21-1-2-3", 0x55667788,
                                        &different_volume));
  EXPECT_NE(a, different_volume);
}

}  // namespace
}  // namespace rlz_lib
