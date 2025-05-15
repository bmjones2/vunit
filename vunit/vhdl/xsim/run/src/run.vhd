-- Run package provides test runner functionality to VHDL 2002+ testbenches
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

use work.logger_pkg.all;
use work.log_levels_pkg.all;
use work.log_handler_pkg.all;
use work.ansi_pkg.enable_colors;
use work.string_ops.all;
use work.dictionary.all;
use work.path.all;
use work.core_pkg;
use std.textio.all;
-- use work.event_common_pkg.all;
-- use work.event_private_pkg.all;
use work.checker_pkg.all;
use work.check_pkg.all;

package body run_pkg is

  impure function contains_test (
    constant test_cases : string;
    constant name : string)
    return boolean is
      constant s : string_vector := split(test_cases, ",");
      variable ret : boolean := false;
  begin
    for i in s'range loop
      if rstrip(s(i),""&NUL) = name then
        return true;
      end if;
    end loop;
    return false;
  end contains_test;

  impure function enabled (
    constant name : string)
    return boolean is
      constant s : string_vector := split(enabled_test_cases.all, ",");
      variable ret : boolean := false;
  begin

    if contains_test(complete_test_cases.all, name) then
      return false;
    end if;

    if contains_test(enabled_test_cases.all, name) then
      write(complete_test_cases, name & ",");
      return true;
    end if;

    return false;
  end enabled;

  impure function run (
    constant name : string)
    return boolean is
  begin
    if enabled(name) then
      core_pkg.test_start(name);

      enabled_test_cases_count := enabled_test_cases_count - 1;
     if enabled_test_cases_count = 0 then
        test_suite := false;
      end if;
      return true;
    else
      return false;
    end if;
  end;

  procedure test_runner_setup (
    signal runner : inout runner_sync_t;
    constant runner_cfg : in string := runner_cfg_default) is
    variable current_test_length : integer := 0;
    variable pepe : line;
  begin
      core_pkg.setup(output_path(runner_cfg) & "vunit_results");
      write(enabled_test_cases, get(runner_cfg, "enabled_test_cases"));
      enabled_test_cases_count := count(enabled_test_cases.all, ',') + 1;
      write(complete_test_cases, string'(","));
  end test_runner_setup;

  procedure test_runner_cleanup (
    signal runner: inout runner_sync_t;
    external_failure : boolean := false;
    allow_disabled_errors : boolean := false;
    allow_disabled_failures : boolean := false;
    fail_on_warning : boolean := false) is
    variable stat : checker_stat_t;
    variable errors : natural := 0;
    variable failures : natural := 0;
  begin
    runner(runner_exit_status_idx) <= runner_exit_without_errors;

    get_checker_stat(default_checker, stat);

    errors := log_counts(log_level_t'pos(error));
    failures := log_counts(log_level_t'pos(failure));
    -- report "Errors: " & to_string(errors);
    -- report "Failures: " & to_string(failures);

    if stat.n_failed = 0 and errors = 0 and failures = 0 then
      core_pkg.test_suite_done;
      core_pkg.stop(0);
    else
      core_pkg.stop(1);
    end if;
  end procedure test_runner_cleanup;

  procedure test_runner_watchdog (
    signal runner : inout runner_sync_t;
    constant timeout : in time;
    constant do_runner_cleanup : boolean := true;
    constant line_num : in natural := 0;
    constant file_name : in string := "") is
    variable current_timeout : time := timeout;
  begin

    loop
      wait until (runner(runner_exit_status_idx) = runner_exit_without_errors) for current_timeout;
        exit;
    end loop;

    if not (runner(runner_exit_status_idx) = runner_exit_without_errors) then
      error(runner_trace_logger,
            "Test runner timeout after " & time'image(current_timeout) & ".",
            path_offset => 1, line_num => line_num, file_name => file_name);
      if do_runner_cleanup then
        test_runner_cleanup(runner);
      end if;
    end if;
  end procedure test_runner_watchdog;

  impure function output_path (
    constant runner_cfg : string)
    return string is
  begin
    return get(runner_cfg, "output path");
  end;

end package body run_pkg;
