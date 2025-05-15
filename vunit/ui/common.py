# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

"""
UI common functions
"""

from pathlib import Path
from glob import glob
from os import environ
from logging import getLogger
from typing import Optional, List
from ..sim_if import is_string_not_iterable
from ..vhdl_standard import VHDL, VHDLStandard

LOGGER = getLogger(__name__)

TEST_OUTPUT_PATH = "test_output"


def select_vhdl_standard(vhdl_standard: Optional[str] = None) -> VHDLStandard:
    """
    Select VHDL standard either from class initialization or according to environment variable VUNIT_VHDL_STANDARD
    """
    if vhdl_standard is not None:
        return VHDL.standard(vhdl_standard)

    try:
        return VHDL.standard(environ.get("VUNIT_VHDL_STANDARD", "2008"))
    except ValueError:
        LOGGER.error("Invalid standard set by VUNIT_VHDL_STANDARD environment variable")
        raise


def lower_generics(generics):
    """
    Convert all generics names to lower case to match internal representation.
    @TODO Maybe warn in case of conflict. VHDL forbids this though so the user will notice anyway.
    """
    return dict((name.lower(), value) for name, value in generics.items())


def check_not_empty(lst, allow_empty, error_msg):
    """
    Raise ValueError if the list is empty unless allow_empty is True
    Returns the list
    """
    if (not allow_empty) and (not lst):
        raise ValueError(error_msg + ". Use allow_empty=True to avoid exception.")
    return lst


def get_checked_file_names_from_globs(pattern, allow_empty):
    """
    Get file names from globs and check that exist
    """
    if is_string_not_iterable(pattern):
        patterns = [pattern]
    elif isinstance(pattern, Path):
        patterns = [str(pattern)]
    else:
        patterns = pattern

    file_names: List[str] = []
    for pattern_instance in patterns:
        new_file_names = glob(str(pattern_instance), recursive=True)
        check_not_empty(
            new_file_names,
            allow_empty,
            f"Pattern {pattern_instance!r} did not match any file",
        )
        file_names += new_file_names

    return file_names

WIN_INSTALL_LOCATIONS = [Path(path) for path in ("C:/", "G:/", "/g/", "~", "C:/git-sdk-64/mingw64")]
LINUX_INSTALL_LOCATIONS = [
    Path(path) for path in ("/", "~/", "/tools/", "~/modelsim", "~/programs/modelSim", "/opt/")
]

SIMULATORS = {
    "msim_free": {
        "vunit_name": "modelsim",
        "win_path_pattern": "intelFPGA/*/modelsim_ase/win32aloem",
        "linux_path_pattern": None,
        "output_path": "modelsim_free",
    },
    "msim": {
        "vunit_name": "modelsim",
        "win_path_pattern": "modelsim_dlx*_*/win*",
        "linux_path_pattern": "modelsim_dlx/linux*",
        "output_path": "modelsim",
    },
    "riviera": {
        "vunit_name": "rivierapro",
        "win_path_pattern": "Aldec/Riviera-PRO-*-x*/bin",
        "linux_path_pattern": None,
        "output_path": "rivierapro",
    },
    "qsim": {
        "vunit_name": "modelsim",
        "win_path_pattern": "questa*/win*",
        "linux_path_pattern": "questa*/linux*",
        "output_path": "questasim",
    },
    "ghdl": {
        "vunit_name": "ghdl",
        "win_path_pattern": "git-sdk-64/mingw64/bin",
        "linux_path_pattern": "ghdl/bin",
    },
    "xsim": {
        "vunit_name" : "xsim",
        "win_path_pattern": "Xilinx/Vivado/2024.2/bin",
        "linux_path_pattern": "Xilinx/Vivado/*/bin",
        "output_path": "xsim",
    }
}
