-- This package provides a dictionary types and operations
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

use work.string_ops.all;
use work.logger_pkg.all;
use std.textio.all;

package dictionary is
  subtype frozen_dictionary_t is string;
  constant empty : frozen_dictionary_t := "";
  -- Deprecated
  constant empty_c : frozen_dictionary_t := empty;

  function len (
    constant d : frozen_dictionary_t)
    return natural;

  impure function get (
    constant d   : frozen_dictionary_t;
    constant key : string)
    return string;

  impure function has_key (
    constant d   : frozen_dictionary_t;
    constant key : string)
    return boolean;

  impure function get (
    d             : frozen_dictionary_t;
    key           : string;
    default_value : string)
    return string;

  constant dictionary_logger : logger_t := get_logger("vunit_lib:dictionary");

end package dictionary;

package body dictionary is
  function len (
    constant d : frozen_dictionary_t)
    return natural is
  begin
    return count(replace(d, "::", "__escaped_colon__"), ":");
  end;

  type dictionary_status_t is (valid_value, key_error, corrupt_dictionary);

  impure function key_matches (
    constant kv_pair : string;
    constant key : string
  ) return dictionary_status_t is
    constant pair : string_vector := split(replace(kv_pair, "::", "__escaped_colon__"), ":");
    constant k : string := strip(replace(replace(rstrip(pair(0),""&NUL), "__escaped_comma__", ','), "__escaped_colon__", ':'));
  begin
    if pair'length /= 2 then
      return corrupt_dictionary;
    elsif k = key then
      return valid_value;
    else
      return key_error;
    end if;
  end function;

  impure function get_value (
    constant kv_pair : string
  ) return string is
    constant pair : string_vector := split(replace(kv_pair, "::", "__escaped_colon__"), ":");
    constant v : string := strip(replace(replace(rstrip(pair(1),""&NUL), "__escaped_comma__", ','), "__escaped_colon__", ':'));
  begin
    return v;
  end function;

  procedure get (
    constant key_value_pairs     : in  string_vector;
    constant key   : in  string;
    variable value : inout line;
    variable status : out dictionary_status_t) is

    variable key_status : dictionary_status_t;
  begin

    for i in key_value_pairs'range loop
      key_status := key_matches(rstrip(key_value_pairs(i),""&NUL), strip(key));
      if key_status = valid_value then
        status := valid_value;
        write(value, get_value(rstrip(key_value_pairs(i),""&NUL)));
        return;
      elsif key_status = corrupt_dictionary then
        status := corrupt_dictionary;
        failure(dictionary_logger, "Corrupt frozen dictionary item """ & rstrip(key_value_pairs(i),""&NUL) & """ in dictionary.");
        write(value, string'("will return when log is mocked out during unit test."));
        return;
      end if;
    end loop;

    status := key_error;
    return;
  end procedure get;

  procedure get (
    constant d     : in  frozen_dictionary_t;
    constant key   : in  string;
    variable value : inout line;
    variable status : out dictionary_status_t) is

    constant da : string := replace(d, ",,", "__escaped_comma__");
  begin
    if value /= null then
      deallocate(value);
    end if;

    if len(da) = 0 then
      failure(dictionary_logger, "Dictionary length is 0.");
      status := key_error;
      return;
    end if;

    get(split(da, ","), key, value, status);
    return;
  end procedure get;

  impure function get (
    constant d   : frozen_dictionary_t;
    constant key : string)
    return string is
    variable value : line;
    variable status : dictionary_status_t;
  begin
    get(d, key, value, status);

    case status is
      when valid_value =>
        return value.all;
      when corrupt_dictionary =>
        failure(dictionary_logger, "corrupt_dictionary! """ & key & """ wasn't found in """ & d & """.");
        return "corrupt_dictionary.";
      when key_error =>
        failure(dictionary_logger, "Key error! """ & key & """ wasn't found in """ & d & """.");
        return "key_error.";
      end case;

  end;

  impure function has_key (
    constant d   : frozen_dictionary_t;
    constant key : string)
    return boolean is
    variable value : line;
    variable status : dictionary_status_t;
  begin
    get(d, key, value, status);
    return status = valid_value;
  end;

  impure function get (
    d             : frozen_dictionary_t;
    key           : string;
    default_value : string)
    return string is
  begin
    if (has_key(d, key) = True) then
      return get(d, key);
    else
      return default_value;
    end if;
  end function get;


end package body dictionary;
