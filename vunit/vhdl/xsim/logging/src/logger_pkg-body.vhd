-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

use work.string_ptr_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.queue_pkg.all;
use work.core_pkg.core_failure;
use std.textio.all;
use work.string_ops.all;
-- use work.print_pkg.print;
use work.ansi_pkg.all;
use work.location_pkg.all;
use work.id_pkg.all;

package body logger_pkg is

  constant global_log_count : integer_vector_ptr_t := new_integer_vector_ptr(1, value => 0);
  constant p_mock_queue_length : integer_vector_ptr_t := new_integer_vector_ptr(1, value => 0);
  constant mock_queue : queue_t := new_queue;

  constant id_idx : natural := 0;
  constant parent_idx : natural := 1;
  constant children_idx : natural := 2;
  constant log_count_idx : natural := 3;
  constant stop_counts_idx : natural := 4;
  constant handlers_idx : natural := 5;
  constant state_idx : natural := 6;
  constant log_level_filters_idx : natural := 7;
  constant logger_length : natural := 8;

  constant log_level_invisible : integer := 0;
  constant log_level_visible : integer := 1;

  constant stop_count_unset : integer := 0;
  constant stop_count_infinite : integer := integer'high;

  constant enabled_state : natural := 0;
  constant disabled_state : natural := 1;
  constant mocked_state : natural := 2;

  impure function to_integer(logger : logger_t) return integer is
  begin
    return to_integer(logger.p_data);
  end;

  impure function get_logger(name : string;
    parent : logger_t := null_logger) return logger_t is
  begin
  return null_logger;
  end;

  constant p_default_logger : logger_t := get_logger("default");
  impure function default_logger return logger_t is
  begin
    return p_default_logger;
  end;

  constant log_level_filter : integer_vector_ptr_t := new_integer_vector_ptr(length => 16, value => log_level_invisible);

  procedure log(logger : logger_t;
                msg : string;
                log_level : log_level_t := info;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "") is
    variable idx : natural := log_level_t'pos(log_level);
  begin
    report(msg);
    -- keep track of count
    log_counts(idx) := log_counts(idx) + 1;
  end procedure;

  procedure debug(logger : logger_t;
    msg : string;
    path_offset : natural := 0;
    line_num : natural := 0;
    file_name : string := "") is
  begin
    log(logger, msg, debug, path_offset + 1, line_num, file_name);
  end procedure;

  procedure pass(logger : logger_t;
  msg : string;
  path_offset : natural := 0;
  line_num : natural := 0;
  file_name : string := "") is
  begin
    log(logger, msg, pass, path_offset + 1, line_num, file_name);
  end procedure;

  procedure trace(logger : logger_t;
    msg : string;
    path_offset : natural := 0;
    line_num : natural := 0;
    file_name : string := "") is
  begin
    log(logger, msg, trace, path_offset + 1, line_num, file_name);
  end procedure;

  procedure info(logger : logger_t;
  msg : string;
  path_offset : natural := 0;
  line_num : natural := 0;
  file_name : string := "") is
  begin
    log(logger, msg, info, path_offset + 1, line_num, file_name);
  end procedure;

  procedure warning(logger : logger_t;
      msg : string;
      path_offset : natural := 0;
      line_num : natural := 0;
      file_name : string := "") is
  begin
    log(logger, msg, warning, path_offset + 1, line_num, file_name);
  end procedure;

  procedure error(logger : logger_t;
    msg : string;
    path_offset : natural := 0;
    line_num : natural := 0;
    file_name : string := "") is
  begin
    log(logger, msg, error, path_offset + 1, line_num, file_name);
  end procedure;

  procedure failure(logger : logger_t;
      msg : string;
      path_offset : natural := 0;
      line_num : natural := 0;
      file_name : string := "") is
  begin
    log(logger, msg, failure, path_offset + 1, line_num, file_name);
  end procedure;

  procedure warning_if(logger : logger_t;
        condition : boolean;
        msg : string;
        path_offset : natural := 0;
        line_num : natural := 0;
        file_name : string := "") is
  begin
    if condition then
      warning(logger, msg, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

  procedure error_if(logger : logger_t;
      condition : boolean;
      msg : string;
      path_offset : natural := 0;
      line_num : natural := 0;
      file_name : string := "") is
  begin
    if condition then
      error(logger, msg, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

  procedure failure_if(logger : logger_t;
        condition : boolean;
        msg : string;
        path_offset : natural := 0;
        line_num : natural := 0;
        file_name : string := "") is
  begin
    if condition then
      failure(logger, msg, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

procedure log(msg : string;
                log_level : log_level_t := info;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "") is
  begin
    log(default_logger, msg, log_level, path_offset + 1, line_num, file_name);
  end;

  procedure debug(msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    debug(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure pass(msg : string;
                 path_offset : natural := 0;
                 line_num : natural := 0;
                 file_name : string := "") is
  begin
    pass(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure trace(msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    trace(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure info(msg : string;
                 path_offset : natural := 0;
                 line_num : natural := 0;
                 file_name : string := "") is
  begin
    info(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure warning(msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    warning(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure error(msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    error(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure failure(msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    failure(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure warning_if(condition : boolean;
                       msg : string;
                       path_offset : natural := 0;
                       line_num : natural := 0;
                       file_name : string := "") is
  begin
    if condition then
      warning(msg, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

  procedure error_if(condition : boolean;
                     msg : string;
                     path_offset : natural := 0;
                     line_num : natural := 0;
                     file_name : string := "") is
  begin
    if condition then
      error(msg, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

  procedure failure_if(condition : boolean;
                       msg : string;
                       path_offset : natural := 0;
                       line_num : natural := 0;
                       file_name : string := "") is
  begin
    if condition then
      failure(msg, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

  impure function is_visible(logger : logger_t;
                             log_level : log_level_t) return boolean is
  begin
    return get(log_level_filter, log_level_t'pos(log_level)) = log_level_visible;
  end;

  procedure set_log_level_filter(logger : logger_t;
                                 log_handler : log_handler_t;
                                 log_levels : log_level_vec_t;
                                 visible : boolean;
                                 include_children : boolean) is
    variable log_level_setting : natural;
  begin
    if visible then
      log_level_setting := log_level_visible;
    else
      log_level_setting := log_level_invisible;
    end if;

    for i in log_levels'range loop
      set(log_level_filter, log_level_t'pos(log_levels(i)), log_level_setting);
    end loop;
  end;

  impure function get_id(logger : logger_t) return id_t is
    begin
      return to_id(get(logger.p_data, id_idx));
    end;

  -- Disable logging for the specified level to this handler from specific
  -- logger and all children.
  procedure hide(logger : logger_t;
                 log_handler : log_handler_t;
                 log_level : log_level_t;
                 include_children : boolean := true) is
  begin
    set_log_level_filter(logger, log_handler, (0 => log_level), visible => false,
                         include_children => include_children);
  end;

  -- Disable logging for the specified level to this handler
  procedure hide(log_handler : log_handler_t;
                 log_level : log_level_t) is
  begin
    hide(null_logger, log_handler, log_level, include_children => true);
  end;
  -- Disable logging for the specified levels to this handler from specific
  -- logger and all children.
  procedure hide(logger : logger_t;
                 log_handler : log_handler_t;
                 log_levels : log_level_vec_t;
                 include_children : boolean := true) is
  begin
    set_log_level_filter(logger, log_handler, log_levels, visible => false,
                         include_children => include_children);
  end;

  -- Disable logging for the specified levels to this handler
  procedure hide(log_handler : log_handler_t;
                 log_levels : log_level_vec_t) is
  begin
    hide(null_logger, log_handler, log_levels);
  end;

  procedure hide_all(logger : logger_t;
                     log_handler : log_handler_t;
                     include_children : boolean := true) is
  begin
    for log_level in log_level_t'low to log_level_t'high loop
      hide(logger, log_handler, log_level, include_children => include_children);
    end loop;
  end;

  procedure hide_all(log_handler : log_handler_t) is
  begin
    hide_all(null_logger, log_handler, include_children => true);
  end;

  procedure show(logger : logger_t;
                 log_handler : log_handler_t;
                 log_level : log_level_t;
                 include_children : boolean := true) is
  begin
    set_log_level_filter(logger, log_handler, (0 => log_level), visible => true,
                         include_children => include_children);
  end;

  procedure show(log_handler : log_handler_t;
                 log_level : log_level_t) is
  begin
    show(null_logger, log_handler, log_level, include_children => true);
  end;

  procedure show(logger : logger_t;
                 log_handler : log_handler_t;
                 log_levels : log_level_vec_t;
                 include_children : boolean := true) is
  begin
    set_log_level_filter(logger, log_handler, log_levels, visible => true,
                         include_children => include_children);
  end;

  procedure show(log_handler : log_handler_t;
                 log_levels : log_level_vec_t) is
  begin
    show(null_logger, log_handler, log_levels, include_children => true);
  end;

  procedure show_all(logger : logger_t;
                     log_handler : log_handler_t;
                     include_children : boolean := true) is
  begin
    for log_level in log_level_t'low to log_level_t'high loop
      show(logger, log_handler, log_level,
           include_children => include_children);
    end loop;
  end;

  procedure show_all(log_handler : log_handler_t) is
  begin
    show_all(null_logger, log_handler, include_children => true);
  end;

  impure function get_full_name(logger : logger_t) return string is
  begin
    return full_name(get_id(logger));
  end;

  impure function get_name(logger : logger_t) return string is
  begin
    return name(get_id(logger));
  end;

  impure function get_parent(logger : logger_t) return logger_t is
    begin
      return (p_data => to_integer_vector_ptr(get(logger.p_data, parent_idx)));
    end;

  procedure set_stop_level(level : alert_log_level_t) is
  begin
  end;

  procedure set_stop_level(logger : logger_t;
                            log_level : alert_log_level_t) is
  begin

  end;

  procedure set_state(logger : logger_t; log_level : log_level_t; state : natural) is
    constant state_vec : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, state_idx));
  begin
    set(state_vec, log_level_t'pos(log_level), state);
  end;

  impure function num_children(logger : logger_t) return natural is
    constant children : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, children_idx));
  begin
    return length(children);
  end;

  impure function get_child(logger : logger_t; idx : natural) return logger_t is
    constant children : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, children_idx));
  begin
    return (p_data => to_integer_vector_ptr(get(children, idx)));
  end;

  procedure disable(logger : logger_t;
                    log_level : log_level_t;
                    include_children : boolean := true) is
  begin
    set_state(logger, log_level, disabled_state);

    if include_children then
      for idx in 0 to num_children(logger)-1 loop
        disable(get_child(logger, idx), log_level, include_children => true);
      end loop;
    end if;
  end;

end package body;
