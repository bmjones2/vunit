# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface for Vivado XSim simulator
"""

from __future__ import print_function
import logging
import os
from os.path import join
from pathlib import Path
import shutil
import threading
from shutil import copyfile
from ..ostools import Process, file_exists
from . import SimulatorInterface, StringOption, BooleanOption, ListOfStringOption
from ..exceptions import CompileError
from configparser import RawConfigParser
from ..vhdl_standard import VHDL
import sys

LOGGER = logging.getLogger(__name__)


class XSimInterface(SimulatorInterface):
    """
    Interface for Vivado xsim simulator
    """

    name = "xsim"
    executable = os.environ.get("XSIM", "xsim")

    package_users_depend_on_bodies = True
    supports_gui_flag = True

    sim_options = [
        StringOption("xsim.timescale"),
        BooleanOption("xsim.enable_glbl"),
        ListOfStringOption("xsim.xelab_flags"),
        ListOfStringOption("xsim.xsim_flags"),
    ]

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        group = parser.add_argument_group("xsim", description="Xsim specific flags")
        group.add_argument(
            "--xsim-vcd-path",
            default="",
            help="VCD waveform output path.",
        )
        group.add_argument("--xsim-vcd-enable", action="store_true", help="Enable VCD waveform generation.")
        group.add_argument(
            "--xsim-xelab-limit", action="store_true", help="Limit the xelab current processes to 1 thread."
        )

    @classmethod
    def from_args(cls, args, output_path, **kwargs):
        """
        Create instance from args namespace
        """
        prefix = cls.find_prefix()

        return cls(
            prefix=prefix,
            output_path=output_path,
            gui=args.gui,
            vcd_path=args.xsim_vcd_path,
            vcd_enable=args.xsim_vcd_enable,
            xelab_limit=args.xsim_xelab_limit,
        )

    @classmethod
    def supports_vhdl_package_generics(cls):
        """
        Returns True when this simulator supports VHDL package generics
        """
        return True

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find first valid xsim toolchain prefix
        """
        return cls.find_toolchain(["xsim"])

    def _format_command_for_os(cls, cmd):
        """
        xsim for windows requires some arguments to be in quotes, which
        have been added in libraries_command. However, the check_output
        function will escape these when calling xsim (as it should),
        meaning that xsim doesn't understand its input arguments.
        The workaround is to create one string here and use that one for windows.
        """
        if (sys.platform == "win32" or os.name == "os2"):
            cmd = " ".join(cmd)
        return cmd

    def check_tool(self, tool_name):
        """
        Checks to see if a tool exists, with extensions both gor Windows and Linux
        """
        if os.path.exists(os.path.join(self._prefix, tool_name + ".bat")):
            return tool_name + ".bat"
        if os.path.exists(os.path.join(self._prefix, tool_name)):
            return tool_name
        raise Exception(f"Cannot find {tool_name}")

    def __init__(self, prefix, output_path, gui=False, vcd_path="", vcd_enable=False, xelab_limit=False):
        super().__init__(output_path, gui)
        self._prefix = prefix
        self._libraries = {}
        self._xvlog = self.check_tool("xvlog")
        self._xvhdl = self.check_tool("xvhdl")
        self._xelab = self.check_tool("xelab")
        self._vivado = self.check_tool("vivado")
        self._xsim = self.check_tool("xsim")
        self._vcd_path = vcd_path
        self._vcd_enable = vcd_enable
        self._xelab_limit = xelab_limit
        self._lock = threading.Lock()
        self._sim_cfg_file_name = str((Path(output_path) / "xsim.ini").resolve())
        self._create_xsim_ini()

    def _create_xsim_ini(self):
        """
        Create the xsim.ini file
        """
        parent = str(Path(self._sim_cfg_file_name).parent)
        if not file_exists(parent):
            os.makedirs(parent)

        original_xsim_ini = os.environ.get("VUNIT_XSIM_INI", str(Path(self._prefix).parent / "data" / "xsim" / "xsim.ini"))
        with Path(original_xsim_ini).open("rb") as fread:
            with Path(self._sim_cfg_file_name).open("wb") as fwrite:
                fwrite.write(fread.read())

    def add_simulator_specific(self, project):
        """
        Add libraries from modelsim.ini file and add coverage flags
        """
        mapped_libraries = self._get_mapped_libraries()
        for library_name in mapped_libraries:
            if not project.has_library(library_name):
                project.add_builtin_library(library_name)

    def setup_library_mapping(self, project):
        """
        Setup library mapping
        """
        mapped_libraries = self._get_mapped_libraries()

        for library in project.get_libraries():
            self._libraries[library.name] = library.directory
            self.create_library(library.name, library.directory, mapped_libraries)

    def compile_source_file_command(self, source_file):
        """
        Returns the command to compile a single source_file
        """
        if source_file.file_type == "vhdl":
            return self.compile_vhdl_file_command(source_file)
        if source_file.file_type == "verilog":
            cmd = [join(self._prefix, self._xvlog), source_file.name]
            return self.compile_verilog_file_command(source_file, cmd)
        if source_file.file_type == "systemverilog":
            cmd = [join(self._prefix, self._xvlog), "--sv", source_file.name]
            return self.compile_verilog_file_command(source_file, cmd)

        LOGGER.error("Unknown file type: %s", source_file.file_type)
        raise CompileError

    def libraries_command(self):
        """
        Adds libraries on the command line
        """
        cmd = []
        for library_name, library_path in self._libraries.items():
            if library_path:
                # new_path = Path(library_path) / ".." / ".." / ".." / "preprocessed" / Path(library_path).name
                # new_path = new_path.resolve()
                cmd += ["-L", f"{library_name}={library_path}"]
            else:
                cmd += ["-L", library_name]
        return cmd

    @staticmethod
    def work_library_argument(source_file):
        return ["-work", source_file.library.name]

    @staticmethod
    def _std_str(vhdl_standard):
        """
        Convert standard to format of Modelsim command line flag
        """
        return "--2008"

    def compile_vhdl_file_command(self, source_file):
        """
        Returns the command to compile a vhdl file
        """
        cmd = [join(self._prefix, self._xvhdl)]
        cmd += [self._std_str(source_file.get_vhdl_standard())]
        cmd += self.work_library_argument(source_file)
        cmd += ["--initfile", self._sim_cfg_file_name]
        cmd += ["--incr", "--relax"]
        cmd += ["--nolog"]
        cmd += [source_file.name]
        return self._format_command_for_os(cmd)

    def compile_verilog_file_command(self, source_file, cmd):
        """
        Returns the command to compile a verilog file
        """
        cmd += self.work_library_argument(source_file)
        cmd += ["--initfile", self._sim_cfg_file_name]
        cmd += ["--incr", "--relax"]
        cmd += ["--nolog"]
        for include_dir in source_file.include_dirs:
            cmd += ["--include", f"{include_dir}"]
        for define_name, define_val in source_file.defines.items():
            cmd += ["--define", f"{define_name}={define_val}"]
        return self._format_command_for_os(cmd)

    def create_library(self, library_name, path, mapped_libraries=None):
        """
        Create and map a library_name to path
        """
        mapped_libraries = mapped_libraries if mapped_libraries is not None else {}

        apath = str(Path(path).parent.resolve())

        if not file_exists(apath):
            os.makedirs(apath)

        if not file_exists(path):
            os.makedirs(path)

        if library_name in mapped_libraries and mapped_libraries[library_name] == path:
            return

        cfg = parse_xsimini(self._sim_cfg_file_name)
        cfg.set("Library", library_name, path)
        write_xsimini(cfg, self._sim_cfg_file_name)

    def _get_mapped_libraries(self):
        """
        Get mapped libraries from xsim.ini file
        """
        cfg = parse_xsimini(self._sim_cfg_file_name)
        libraries = dict(cfg.items("Library"))
        if "others" in libraries:
            del libraries["others"]
        return libraries

    @staticmethod
    def _xelab_extra_args(config):
        """
        Determine xelab_extra_args
        """
        xelab_extra_args = []
        xelab_extra_args = config.sim_options.get("xsim.xelab_flags", xelab_extra_args)

        return xelab_extra_args

    @staticmethod
    def _xsim_extra_args(config):
        """
        Determine xsim_extra_args
        """
        xsim_extra_args = []
        xsim_extra_args = config.sim_options.get("xsim.xsim_flags", xsim_extra_args)

        return xsim_extra_args

    def simulate(self, output_path, test_suite_name, config, elaborate_only):
        """
        Simulate with entity as top level using generics
        """
        runpy_dir = os.path.abspath(str(Path(output_path)) + "../../../../")

        if self._vcd_path == "":
            vcd_path = os.path.abspath(str(Path(output_path))) + "/wave.vcd"
        else:
            if os.path.isabs(self._vcd_path):
                vcd_path = self._vcd_path
            else:
                vcd_path = os.path.abspath(str(Path(runpy_dir))) + "/" + self._vcd_path

        cmd = [join(self._prefix, self._xelab)]
        cmd += ["-debug", "all"] # 'all' allows debugging other packages
        # cmd += self.libraries_command()

        cmd += ["--notimingchecks"]
        cmd += ["--nospecify"]
        cmd += ["--nolog"]
        cmd += ["--relax"]
        cmd += ["--incr"]
        cmd += ["--sdfnowarn"]
        cmd += ["--stats"]
        cmd += ["--O2"]

        snapshot = "vunit_test"
        cmd += ["--snapshot", snapshot]
        cmd += ["--initfile", self._sim_cfg_file_name]

        enable_glbl = config.sim_options.get(self.name + ".enable_glbl", None)

        cmd += [f"{config.library_name}.{config.entity_name}"]

        if enable_glbl == True:
            cmd += [f"xil_defaultlib.glbl"]

        timescale = config.sim_options.get(self.name + ".timescale", None)
        if timescale:
            cmd += ["-timescale", timescale]

        # TODO linux might require different quotes for generic_top
        for generic_name, generic_value in config.generics.items():
            cmd += ["--generic_top", f'"{generic_name!s}={encode_generic_value(generic_value)!s}"']

        if not os.path.exists(output_path):
            os.makedirs(output_path)

        cmd += self._xelab_extra_args(config)
        cmd = self._format_command_for_os(cmd)

        status = True
        try:
            if self._xelab_limit is True:
                with self._lock:
                    proc = Process(cmd, cwd=output_path)
                    proc.consume_output()
            else:
                proc = Process(cmd, cwd=output_path)
                proc.consume_output()

        except Process.NonZeroExitCode:
            status = False

        try:
            # Execute XSIM
            if not elaborate_only:
                # FIXME linux path needs on Windows?
                tcl_file = os.path.join(output_path, "xsim_startup.tcl").replace(os.sep, '/')

                # XSIM binary
                vivado_cmd = [join(self._prefix, self._xsim)]
                # Gui support
                if self._gui:
                    # Mode GUI
                    vivado_cmd += ["--gui"]

                # Include tcl
                vivado_cmd += ["--tclbatch", tcl_file]
                # debugging things
                # vivado_cmd += ["-tp", "-tl"]
                # set xsim.dir location
                # vivado_cmd += ["-xsimdir", output_path]
                # Snapshot
                vivado_cmd += [snapshot]

                vivado_cmd += self._xsim_extra_args(config)

                with open(tcl_file, "w+") as xsim_startup_file:
                    if os.path.exists(vcd_path):
                        os.remove(vcd_path)

                    if self._gui == True:
                        xsim_startup_file.write("create_wave_config; add_wave /; set_property needs_save false [current_wave_config]\n")
                        if self._vcd_enable:
                            xsim_startup_file.write(f"open_vcd {vcd_path}\n")
                            xsim_startup_file.write("log_vcd *\n")
                    else:
                        if self._vcd_enable:
                            xsim_startup_file.write(f"open_vcd {vcd_path}\n")
                            xsim_startup_file.write("log_vcd [get_objects -recursive]\n")
                        xsim_startup_file.write("run all\n")
                        # Workaround to force exit code on errors for Windows
                        xsim_startup_file.write("set sim_error [get_value -radix unsigned /core_pkg/exit_code]\n")
                        xsim_startup_file.write("exit $sim_error\n")


                print(" ".join(vivado_cmd))
                vivado_cmd = self._format_command_for_os(vivado_cmd)

                proc = Process(vivado_cmd, cwd=output_path)
                proc.consume_output()

        except Process.NonZeroExitCode:
            status = False
        return status

def encode_generic_value(value):
    """
    Ensure values with space in them are quoted
    """
    s_value = str(value)
    if " " in s_value:
        return f'{s_value!s}'
    if "," in s_value:
        return f'"{s_value!s}"'
    return s_value

def parse_xsimini(file_name):
    """
    Parse a xsim.ini file
    :returns: A RawConfigParser object
    """
    with Path(file_name).open("r", encoding="utf-8") as fptr:
        ini_string = "[Library]\n" + fptr.read()
    cfg = RawConfigParser()
    cfg.read_string(ini_string)
    return cfg


def write_xsimini(cfg, file_name):
    """
    Writes a xsim.ini file
    """
    with Path(file_name).open("w", encoding="utf-8") as optr:
        libraries = dict(cfg.items("Library"))
        for k,v in libraries.items():
            optr.write(f"{k} = {v}\n")