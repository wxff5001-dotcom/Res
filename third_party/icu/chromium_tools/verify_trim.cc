// Copyright 2026 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// PORT: not upstream. Verifies a candidate icudtl.dat (copy one next to this
// binary before running) by exercising Calendar, DateFormat and NumberFormat
// for a few kept and dropped locales, printing exactly which stage fails.
//
// This is what proved that icupkg-based post-hoc trimming does not work for
// this data file -- see README.md in this directory. Kept for whoever tries
// the alternative (a real genrb/pkgdata rebuild) next: point this at the
// result before trusting it.
//
// Chromium's normal ICU init (base/i18n/icu_util.cc) finds icudtl.dat beside
// the executable automatically, so this just needs to run from the directory
// holding the candidate file -- no explicit data-directory wiring.

#include <cstdio>

#include "base/i18n/icu_util.h"
#include "unicode/calendar.h"
#include "unicode/datefmt.h"
#include "unicode/locid.h"
#include "unicode/numfmt.h"
#include "unicode/unistr.h"

namespace {

void TryLocale(const icu::Locale& locale) {
  UErrorCode status = U_ZERO_ERROR;

  std::unique_ptr<icu::Calendar> calendar(
      icu::Calendar::createInstance(locale, status));
  if (U_FAILURE(status)) {
    printf("[%s] Calendar::createInstance failed: %s\n", locale.getName(),
           u_errorName(status));
    return;
  }
  calendar->set(2026, icu::Calendar::AUGUST, 16);

  status = U_ZERO_ERROR;
  std::unique_ptr<icu::DateFormat> date_format(
      icu::DateFormat::createDateInstance(icu::DateFormat::kFull, locale));
  icu::UnicodeString formatted;
  if (!date_format) {
    printf("[%s] DateFormat::createDateInstance returned null\n",
           locale.getName());
  } else {
    UErrorCode time_status = U_ZERO_ERROR;
    UDate time = calendar->getTime(time_status);
    if (U_FAILURE(time_status)) {
      printf("[%s] Calendar::getTime failed: %s\n", locale.getName(),
             u_errorName(time_status));
    }
    date_format->format(time, formatted);
  }

  status = U_ZERO_ERROR;
  std::unique_ptr<icu::NumberFormat> number_format(
      icu::NumberFormat::createInstance(locale, status));
  icu::UnicodeString number;
  if (U_FAILURE(status)) {
    printf("[%s] NumberFormat::createInstance failed: %s\n", locale.getName(),
           u_errorName(status));
  } else if (number_format) {
    number_format->format(1234567.89, number);
  }

  std::string date_utf8, number_utf8;
  formatted.toUTF8String(date_utf8);
  number.toUTF8String(number_utf8);
  printf("[%-8s] date=\"%s\"  number=\"%s\"  (isBogus=%d)\n",
         locale.getName(), date_utf8.c_str(), number_utf8.c_str(),
         formatted.isBogus());
}

}  // namespace

int main() {
  // Chromium does not rely on ICU's own data-directory search; base wires the
  // data file up explicitly. Without this call every locale service silently
  // falls back to built-in defaults rather than failing loudly, which is
  // exactly the kind of false pass that would have hidden a real problem
  // here.
  if (!base::i18n::InitializeICU()) {
    printf("base::i18n::InitializeICU() failed -- icudtl.dat not found "
           "beside the executable\n");
    return 1;
  }

  printf("Kept locales:\n");
  TryLocale(icu::Locale::getUS());
  TryLocale(icu::Locale::getUK());
  TryLocale(icu::Locale::getSimplifiedChinese());
  TryLocale(icu::Locale("zh_Hant_TW"));

  printf("\nDropped locale (expect graceful fallback, not a crash):\n");
  TryLocale(icu::Locale::getFrance());
  TryLocale(icu::Locale::getJapanese());

  return 0;
}
