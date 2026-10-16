# Copyright 2014 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import os
import unittest

from mojom_bindings_generator import MakeImportStackMessage
from mojom_bindings_generator import RelativePath
from mojom_bindings_generator import ScrambleMethodOrdinals


class FakeIface:
  def __init__(self):
    self.mojom_name = None
    self.methods = None


class FakeMethod:
  def __init__(self, explicit_ordinal=None):
    self.explicit_ordinal = explicit_ordinal
    self.ordinal = explicit_ordinal
    self.ordinal_comment = None


class MojoBindingsGeneratorTest(unittest.TestCase):
  """Tests mojo_bindings_generator."""

  def testParentSourceRoot(self):
    path = os.path.join('..', '..', 'src', 'interface.mojom')
    root = os.path.join('..', '..', '..')
    relative = RelativePath(path, root, 'gen')
    self.assertEqual(relative.relative_path(),
                     os.path.relpath(os.path.abspath(path), os.path.abspath(root)))

  def testAbsoluteInputWithRelativeRoot(self):
    path = os.path.abspath(os.path.join('input', 'interface.mojom'))
    self.assertEqual(RelativePath(path, 'input', 'gen').relative_path(),
                     'interface.mojom')

  def testGeneratedInputInsideSourceRoot(self):
    path = os.path.join('gen', 'interface.mojom')
    relative = RelativePath(path, '.', 'gen')
    self.assertEqual(relative.root, 'gen')
    self.assertEqual(relative.relative_path(), 'interface.mojom')

  def testRejectPrefixSibling(self):
    with self.assertRaisesRegex(Exception, 'Invalid input path'):
      RelativePath(os.path.join('input_other', 'interface.mojom'), 'input', 'gen')

  def testRejectTraversalOutsideRoot(self):
    with self.assertRaisesRegex(Exception, 'Invalid input path'):
      RelativePath(os.path.join('input', '..', 'outside', 'interface.mojom'),
                   'input', 'gen')

  @unittest.skipUnless(os.name == 'nt', 'Windows drive and case semantics')
  def testWindowsRootNormalization(self):
    path = os.path.abspath(os.path.join('input', 'interface.mojom'))
    root = os.path.abspath('input').upper()
    self.assertEqual(RelativePath(path, root, 'gen').relative_path(),
                     'interface.mojom')
    other_drive = 'Z:' if os.path.splitdrive(path)[0].upper() != 'Z:' else 'Y:'
    with self.assertRaisesRegex(Exception, 'Invalid input path'):
      RelativePath(path, other_drive + '\\input', other_drive + '\\gen')

  def testMakeImportStackMessage(self):
    """Tests MakeImportStackMessage()."""
    self.assertEqual(MakeImportStackMessage(["x"]), "")
    self.assertEqual(MakeImportStackMessage(["x", "y"]),
                     "\n  y was imported by x")
    self.assertEqual(MakeImportStackMessage(["x", "y", "z"]),
                     "\n  z was imported by y\n  y was imported by x")

  def testScrambleMethodOrdinals(self):
    """Tests ScrambleMethodOrdinals()."""
    interface = FakeIface()
    interface.mojom_name = 'RendererConfiguration'
    interface.methods = [
        FakeMethod(),
        FakeMethod(),
        FakeMethod(),
        FakeMethod(explicit_ordinal=42)
    ]
    ScrambleMethodOrdinals([interface], "foo".encode('utf-8'))
    # These next three values are hard-coded. If the generation algorithm
    # changes from being based on sha256(seed + interface.name + str(i)) then
    # these numbers will obviously need to change too.
    #
    # Note that hashlib.sha256('fooRendererConfiguration1').digest()[:4] is
    # '\xa5\xbc\xf9\xca' and that hex(1257880741) = '0x4af9bca5'. The
    # difference in 0x4a vs 0xca is because we only take 31 bits.
    self.assertEqual(interface.methods[0].ordinal, 1257880741)
    self.assertEqual(interface.methods[1].ordinal, 631133653)
    self.assertEqual(interface.methods[2].ordinal, 549336076)

    # Explicit method ordinals should not be scrambled.
    self.assertEqual(interface.methods[3].ordinal, 42)


if __name__ == "__main__":
  unittest.main()
