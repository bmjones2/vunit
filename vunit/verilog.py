# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

"""
The main public Python interface of VUnit-Verilog.
"""

from warnings import warn
from vunit.ui import VUnit as VUnitVHDL


class VUnit(VUnitVHDL):
    """
    VUnit Verilog interface
    """

    # This is a temporary workaround to avoid breaking the scripts of current verilog users
    def add_vhdl_builtins(self):  # pylint: disable=arguments-differ
        """
        Add vunit Verilog builtin libraries
        """
        self._builtins.add_verilog_builtins()
        builtins_deprecation_note = (
            "class 'verilog' is deprecated and it will be removed in future releases; "
            "preserve the functionality using the default vunit class, along with "
            "'compile_builtins=False' and 'VU.add_verilog_builtins'"
        )
        warn(builtins_deprecation_note, Warning)
