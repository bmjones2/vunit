-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

use work.log_levels_pkg.all;
use work.log_handler_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.id_pkg.all;

package logger_pkg is

  constant n_log_levels : natural := log_level_t'pos(log_level_t'high) + 1;

  type log_count_vec_t is array (natural range 0 to n_log_levels-1) of natural;
  shared variable log_counts : log_count_vec_t := (others => 0);

  type logger_t is record
    p_data : integer_vector_ptr_t;
  end record;

  constant null_logger : logger_t := (p_data => null_ptr);

  impure function is_visible(logger : logger_t;
                             log_level : log_level_t) return boolean;

  -- Get a logger with name. A new one is created if it doesn't
  -- already exist. Can also optionally be relative to a parent logger.
  -- If a new logger is created then a new identity with the name/parent
  -- is also created.
  impure function get_logger(name : string;
  parent : logger_t := null_logger) return logger_t;

  -------------------------------------
  -- Log procedures for each log level
  -------------------------------------
  procedure trace(logger : logger_t;
  msg : string;
  path_offset : natural := 0;
  line_num : natural := 0;
  file_name : string := "");

procedure debug(logger : logger_t;
  msg : string;
  path_offset : natural := 0;
  line_num : natural := 0;
  file_name : string := "");

procedure pass(logger : logger_t;
 msg : string;
 path_offset : natural := 0;
 line_num : natural := 0;
 file_name : string := "");

procedure info(logger : logger_t;
 msg : string;
 path_offset : natural := 0;
 line_num : natural := 0;
 file_name : string := "");

procedure warning(logger : logger_t;
    msg : string;
    path_offset : natural := 0;
    line_num : natural := 0;
    file_name : string := "");

procedure error(logger : logger_t;
  msg : string;
  path_offset : natural := 0;
  line_num : natural := 0;
  file_name : string := "");

procedure failure(logger : logger_t;
    msg : string;
    path_offset : natural := 0;
    line_num : natural := 0;
    file_name : string := "");

procedure warning_if(logger : logger_t;
       condition : boolean;
       msg : string;
       path_offset : natural := 0;
       line_num : natural := 0;
       file_name : string := "");

procedure error_if(logger : logger_t;
     condition : boolean;
     msg : string;
     path_offset : natural := 0;
     line_num : natural := 0;
     file_name : string := "");

procedure failure_if(logger : logger_t;
       condition : boolean;
       msg : string;
       path_offset : natural := 0;
       line_num : natural := 0;
       file_name : string := "");

  ------------------------------------------------
  -- Log procedure short hands for default logger
  ------------------------------------------------

  -- The default logger, all log calls without logger argument go to this logger.
  impure function default_logger return logger_t;

  procedure trace(msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure debug(msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure pass(msg : string;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "");

  procedure info(msg : string;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "");

  procedure warning(msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "");

  procedure error(msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure failure(msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "");

  procedure warning_if(condition : boolean;
                      msg : string;
                      path_offset : natural := 0;
                      line_num : natural := 0;
                      file_name : string := "");

  procedure error_if(condition : boolean;
                    msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "");

  procedure failure_if(condition : boolean;
                      msg : string;
                      path_offset : natural := 0;
                      line_num : natural := 0;
                      file_name : string := "");

  -- Log procedure with level as argument
  procedure log(logger : logger_t;
                msg : string;
                log_level : log_level_t := info;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "");

  procedure log(msg : string;
                log_level : log_level_t := info;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "");

  -- Get the name of this logger get_name(get_logger("parent:child")) = "child"
  impure function get_name(logger : logger_t) return string;

  -- Get the full name of this logger get_name(get_logger("parent:child")) = "parent:child"
  impure function get_full_name(logger : logger_t) return string;

  -- Get identity for this logger.
  impure function get_id(logger : logger_t) return id_t;

  -- Get the parent of this logger
  impure function get_parent(logger : logger_t) return logger_t;

  -- Get the number of children of this logger
  impure function num_children(logger : logger_t) return natural;

  -- Get the idx'th child of this logger
  impure function get_child(logger : logger_t; idx : natural) return logger_t;

  -- Shorthand for configuring the stop counts for (warning, error, failure) in
  -- a logger subtree. Set stop count to infinite for all levels < log_level and
  -- 1 for all (warning, error, failure) >= log_level.

  -- NOTE: Removes all other stop count settings from logger subtree.
  procedure set_stop_level(logger : logger_t;
                           log_level : alert_log_level_t);

  -- Shorthand for configuring the stop counts in entire logger tree.
  -- Same behavior as set_stop_level for specific logger subtree above
  procedure set_stop_level(level : alert_log_level_t);

  -- Disable a log_level from specific logger including all children.
  -- Disable is used when a log message is unwanted and it should be ignored.

  -- NOTE: A disabled log message is still counted to get a disabled log count
  --       statistics.
  --       errors and failures can be disabled but the final_log_check must
  --       explicitly allow it as well as an extra safety mechanism.
  procedure disable(logger : logger_t;
                    log_level : log_level_t;
                    include_children : boolean := true);

  -- Hide log messages of specified level to this handler.
  procedure hide(log_handler : log_handler_t;
                 log_level : log_level_t);

  -- Hide log messages from the logger of the specified level to this handler
  procedure hide(logger : logger_t;
                 log_handler : log_handler_t;
                 log_level : log_level_t;
                 include_children : boolean := true);

  -- Hide log messages of the specified levels to this handler.
  procedure hide(log_handler : log_handler_t;
                 log_levels : log_level_vec_t);

  -- Hide log messages from the logger of the specified levels to this handler
  procedure hide(logger : logger_t;
                 log_handler : log_handler_t;
                 log_levels : log_level_vec_t;
                 include_children : boolean := true);

  -- Show log messages of the specified log_level to this handler
  procedure show(log_handler : log_handler_t;
                 log_level : log_level_t);

  -- Show log messages from the logger of the specified log_level to this handler
  procedure show(logger : logger_t;
                 log_handler : log_handler_t;
                 log_level : log_level_t;
                 include_children : boolean := true);

  -- Show log messages of the specified log_levels to this handler
  procedure show(log_handler : log_handler_t;
                 log_levels : log_level_vec_t);

  -- Show log messages from the logger of the specified log_levels to this handler
  procedure show(logger : logger_t;
                 log_handler : log_handler_t;
                 log_levels : log_level_vec_t;
                 include_children : boolean := true);

  -- Show all log levels to the log handler
  procedure show_all(log_handler : log_handler_t);

  -- Show all log levels to the handler from specific logger
  procedure show_all(logger : logger_t;
                     log_handler : log_handler_t;
                     include_children : boolean := true);

end package;
