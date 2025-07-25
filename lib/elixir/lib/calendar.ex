# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

defmodule Calendar do
  @moduledoc """
  This module defines the responsibilities for working with
  calendars, dates, times and datetimes in Elixir.

  It defines types and the minimal implementation
  for a calendar behaviour in Elixir. The goal of the calendar
  features in Elixir is to provide a base for interoperability
  rather than a full-featured datetime API.

  For the actual date, time and datetime structs, see `Date`,
  `Time`, `NaiveDateTime`, and `DateTime`.

  Types for year, month, day, and more are *overspecified*.
  For example, the `t:month/0` type is specified as an integer
  instead of `1..12`. This is because different calendars may
  have a different number of days per month.
  """

  @type year :: integer
  @type month :: pos_integer
  @type day :: pos_integer
  @type week :: pos_integer
  @type day_of_week :: non_neg_integer
  @type era :: non_neg_integer

  @typedoc """
  A tuple representing the `day` and the `era`.
  """
  @type day_of_era :: {day :: non_neg_integer(), era}

  @type hour :: non_neg_integer
  @type minute :: non_neg_integer
  @type second :: non_neg_integer

  @typedoc """
  The internal time format is used when converting between calendars.

  It represents time as a fraction of a day (starting from midnight).
  `parts_in_day` specifies how much of the day is already passed,
  while `parts_per_day` signifies how many parts are there in a day.
  """
  @type day_fraction :: {parts_in_day :: non_neg_integer, parts_per_day :: pos_integer}

  @typedoc """
  The internal date format that is used when converting between calendars.

  This is the number of days including the fractional part that has passed of
  the last day since `0000-01-01+00:00T00:00.000000` in ISO 8601 notation (also
  known as *midnight 1 January BC 1* of the proleptic Gregorian calendar).
  """
  @type iso_days :: {days :: integer, day_fraction}

  @typedoc """
  Microseconds with stored precision.

  `value` always represents the total value in microseconds.

  The `precision` represents the number of digits that must be used when
  representing the microseconds to external format. If the precision is `0`,
  it means microseconds must be skipped. If the precision is `6`, it means
  that `value` represents exactly the number of microseconds to be used.

  ## Examples

    * `{0, 0}` means no microseconds.
    * `{1, 6}` means 1µs.
    * `{1000, 6}` means 1000µs (which is 1ms but measured at the microsecond precision).
    * `{1000, 3}` means 1ms (which is measured at the millisecond precision).

  """
  @type microsecond :: {value :: non_neg_integer, precision :: non_neg_integer}

  @typedoc "A calendar implementation."
  @type calendar :: module

  @typedoc "The time zone ID according to the IANA tz database (for example, `Europe/Zurich`)."
  @type time_zone :: String.t()

  @typedoc "The time zone abbreviation (for example, `CET` or `CEST` or `BST`)."
  @type zone_abbr :: String.t()

  @typedoc """
  The time zone UTC offset in ISO seconds for standard time.

  See also `t:std_offset/0`.
  """
  @type utc_offset :: integer

  @typedoc """
  The time zone standard offset in ISO seconds (typically not zero in summer times).

  It must be added to `t:utc_offset/0` to get the total offset from UTC used for "wall time".
  """
  @type std_offset :: integer

  @typedoc "Any map or struct that contains the date fields."
  @type date :: %{optional(any) => any, calendar: calendar, year: year, month: month, day: day}

  @typedoc "Any map or struct that contains the time fields."
  @type time :: %{
          optional(any) => any,
          hour: hour,
          minute: minute,
          second: second,
          microsecond: microsecond
        }

  @typedoc "Any map or struct that contains the naive datetime fields."
  @type naive_datetime :: %{
          optional(any) => any,
          calendar: calendar,
          year: year,
          month: month,
          day: day,
          hour: hour,
          minute: minute,
          second: second,
          microsecond: microsecond
        }

  @typedoc "Any map or struct that contains the datetime fields."
  @type datetime :: %{
          optional(any) => any,
          calendar: calendar,
          year: year,
          month: month,
          day: day,
          hour: hour,
          minute: minute,
          second: second,
          microsecond: microsecond,
          time_zone: time_zone,
          zone_abbr: zone_abbr,
          utc_offset: utc_offset,
          std_offset: std_offset
        }

  @typedoc """
  Specifies the time zone database for calendar operations.

  Many functions in the `DateTime` module require a time zone database.
  By default, this module uses the default time zone database returned by
  `Calendar.get_time_zone_database/0`, which defaults to
  `Calendar.UTCOnlyTimeZoneDatabase`. This database only handles `Etc/UTC`
  datetimes and returns `{:error, :utc_only_time_zone_database}`
  for any other time zone.

  Other time zone databases (including ones provided by packages)
  can be configured as default either via configuration:

      config :elixir, :time_zone_database, CustomTimeZoneDatabase

  or by calling `Calendar.put_time_zone_database/1`.

  See `Calendar.TimeZoneDatabase` for more information on custom
  time zone databases.
  """
  @type time_zone_database :: module()

  @typedoc """
  Options for formatting dates and times with `strftime/3`.
  """
  @type strftime_opts :: [
          preferred_datetime: String.t(),
          preferred_date: String.t(),
          preferred_time: String.t(),
          am_pm_names: (:am | :pm -> String.t()) | (:am | :pm, map() -> String.t()),
          month_names: (pos_integer() -> String.t()) | (pos_integer(), map() -> String.t()),
          abbreviated_month_names:
            (pos_integer() -> String.t()) | (pos_integer(), map() -> String.t()),
          day_of_week_names: (pos_integer() -> String.t()) | (pos_integer(), map() -> String.t()),
          abbreviated_day_of_week_names:
            (pos_integer() -> String.t()) | (pos_integer(), map() -> String.t())
        ]

  @doc """
  Returns how many days there are in the given month of the given year.
  """
  @callback days_in_month(year, month) :: day

  @doc """
  Returns how many months there are in the given year.
  """
  @callback months_in_year(year) :: month

  @doc """
  Returns `true` if the given year is a leap year.

  A leap year is a year of a longer length than normal. The exact meaning
  is up to the calendar. A calendar must return `false` if it does not support
  the concept of leap years.
  """
  @callback leap_year?(year) :: boolean

  @doc """
  Calculates the day of the week from the given `year`, `month`, and `day`.

  `starting_on` represents the starting day of the week. All
  calendars must support at least the `:default` value. They may
  also support other values representing their days of the week.

  The value of `day_of_week` is an ordinal number meaning that a
  value of `1` is defined to mean "first day of the week". It is
  specifically not defined to mean `1` is `Monday`.

  It is a requirement that `first_day_of_week` is less than `last_day_of_week`
  and that `day_of_week` must be within that range. Therefore it can be said
  that `day_of_week in first_day_of_week..last_day_of_week//1` must be
  `true` for all values of `day_of_week`.
  """
  @callback day_of_week(year, month, day, starting_on :: :default | atom) ::
              {day_of_week(), first_day_of_week :: non_neg_integer(),
               last_day_of_week :: non_neg_integer()}

  @doc """
  Calculates the day of the year from the given `year`, `month`, and `day`.
  """
  @callback day_of_year(year, month, day) :: non_neg_integer()

  @doc """
  Calculates the quarter of the year from the given `year`, `month`, and `day`.
  """
  @callback quarter_of_year(year, month, day) :: non_neg_integer()

  @doc """
  Calculates the year and era from the given `year`.
  """
  @callback year_of_era(year, month, day) :: {year, era}

  @doc """
  Calculates the day and era from the given `year`, `month`, and `day`.
  """
  @callback day_of_era(year, month, day) :: day_of_era()

  @doc """
  Converts the date into a string according to the calendar.
  """
  @callback date_to_string(year, month, day) :: String.t()

  @doc """
  Converts the naive datetime (without time zone) into a string according to the calendar.
  """
  @callback naive_datetime_to_string(year, month, day, hour, minute, second, microsecond) ::
              String.t()

  @doc """
  Converts the datetime (with time zone) into a string according to the calendar.
  """
  @callback datetime_to_string(
              year,
              month,
              day,
              hour,
              minute,
              second,
              microsecond,
              time_zone,
              zone_abbr,
              utc_offset,
              std_offset
            ) :: String.t()

  @doc """
  Converts the time into a string according to the calendar.
  """
  @callback time_to_string(hour, minute, second, microsecond) :: String.t()

  @doc """
  Converts the datetime (without time zone) into the `t:iso_days/0` format.
  """
  @callback naive_datetime_to_iso_days(year, month, day, hour, minute, second, microsecond) ::
              iso_days

  @doc """
  Converts `t:iso_days/0` to the calendar's datetime format.
  """
  @callback naive_datetime_from_iso_days(iso_days) ::
              {year, month, day, hour, minute, second, microsecond}

  @doc """
  Converts the given time to the `t:day_fraction/0` format.
  """
  @callback time_to_day_fraction(hour, minute, second, microsecond) :: day_fraction

  @doc """
  Converts `t:day_fraction/0` to the calendar's time format.
  """
  @callback time_from_day_fraction(day_fraction) :: {hour, minute, second, microsecond}

  @doc """
  Define the rollover moment for the calendar.

  This is the moment, in your calendar, when the current day ends
  and the next day starts.

  The result of this function is used to check if two calendars roll over at
  the same time of day. If they do not, we can only convert datetimes and times
  between them. If they do, this means that we can also convert dates as well
  as naive datetimes between them.

  This day fraction should be in its most simplified form possible, to make comparisons fast.

  ## Examples

    * If in your calendar a new day starts at midnight, return `{0, 1}`.
    * If in your calendar a new day starts at sunrise, return `{1, 4}`.
    * If in your calendar a new day starts at noon, return `{1, 2}`.
    * If in your calendar a new day starts at sunset, return `{3, 4}`.

  """
  @callback day_rollover_relative_to_midnight_utc() :: day_fraction

  @doc """
  Should return `true` if the given date describes a proper date in the calendar.
  """
  @callback valid_date?(year, month, day) :: boolean

  @doc """
  Should return `true` if the given time describes a proper time in the calendar.
  """
  @callback valid_time?(hour, minute, second, microsecond) :: boolean

  @doc """
  Parses the string representation for a time returned by `c:time_to_string/4`
  into a time tuple.
  """
  @doc since: "1.10.0"
  @callback parse_time(String.t()) ::
              {:ok, {hour, minute, second, microsecond}}
              | {:error, atom}

  @doc """
  Parses the string representation for a date returned by `c:date_to_string/3`
  into a date tuple.
  """
  @doc since: "1.10.0"
  @callback parse_date(String.t()) ::
              {:ok, {year, month, day}}
              | {:error, atom}

  @doc """
  Parses the string representation for a naive datetime returned by
  `c:naive_datetime_to_string/7` into a naive datetime tuple.

  The given string may contain a timezone offset but it is ignored.
  """
  @doc since: "1.10.0"
  @callback parse_naive_datetime(String.t()) ::
              {:ok, {year, month, day, hour, minute, second, microsecond}}
              | {:error, atom}

  @doc """
  Parses the string representation for a datetime returned by
  `c:datetime_to_string/11` into a datetime tuple.

  The returned datetime must be in UTC. The original `utc_offset`
  it was written in must be returned in the result.
  """
  @doc since: "1.10.0"
  @callback parse_utc_datetime(String.t()) ::
              {:ok, {year, month, day, hour, minute, second, microsecond}, utc_offset}
              | {:error, atom}

  @doc """
  Converts the given `t:iso_days/0` to the first moment of the day.
  """
  @doc since: "1.15.0"
  @callback iso_days_to_beginning_of_day(iso_days) :: iso_days

  @doc """
  Converts the given `t:iso_days/0` to the last moment of the day.
  """
  @doc since: "1.15.0"
  @callback iso_days_to_end_of_day(iso_days) :: iso_days

  @doc """
  Shifts date by given duration according to its calendar.
  """
  @doc since: "1.17.0"
  @callback shift_date(year, month, day, Duration.t()) :: {year, month, day}

  @doc """
  Shifts naive datetime by given duration according to its calendar.
  """
  @doc since: "1.17.0"
  @callback shift_naive_datetime(
              year,
              month,
              day,
              hour,
              minute,
              second,
              microsecond,
              Duration.t()
            ) :: {year, month, day, hour, minute, second, microsecond}

  @doc """
  Shifts time by given duration according to its calendar.
  """
  @doc since: "1.17.0"
  @callback shift_time(hour, minute, second, microsecond, Duration.t()) ::
              {hour, minute, second, microsecond}

  # General Helpers

  @doc """
  Returns `true` if two calendars have the same moment of starting a new day,
  `false` otherwise.

  If two calendars are not compatible, we can only convert datetimes and times
  between them. If they are compatible, this means that we can also convert
  dates as well as naive datetimes between them.
  """
  @doc since: "1.5.0"
  @spec compatible_calendars?(Calendar.calendar(), Calendar.calendar()) :: boolean
  def compatible_calendars?(calendar, calendar), do: true

  def compatible_calendars?(calendar1, calendar2) do
    calendar1.day_rollover_relative_to_midnight_utc() ==
      calendar2.day_rollover_relative_to_midnight_utc()
  end

  @doc """
  Returns a microsecond tuple truncated to a given precision (`:microsecond`,
  `:millisecond`, or `:second`).
  """
  @doc since: "1.6.0"
  @spec truncate(Calendar.microsecond(), :microsecond | :millisecond | :second) ::
          Calendar.microsecond()
  def truncate(microsecond_tuple, :microsecond), do: microsecond_tuple

  def truncate({microsecond, precision}, :millisecond) do
    output_precision = min(precision, 3)
    {div(microsecond, 1000) * 1000, output_precision}
  end

  def truncate(_, :second), do: {0, 0}

  @doc """
  Sets the current time zone database.
  """
  @doc since: "1.8.0"
  @spec put_time_zone_database(time_zone_database()) :: :ok
  def put_time_zone_database(database) when is_atom(database) do
    Application.put_env(:elixir, :time_zone_database, database)
  end

  @doc """
  Gets the current time zone database.
  """
  @doc since: "1.8.0"
  @spec get_time_zone_database() :: time_zone_database()
  def get_time_zone_database() do
    Application.fetch_env!(:elixir, :time_zone_database)
  end

  @doc """
  Formats the given date, time, or datetime into a string.

  The datetime can be any of the `Calendar` types (`Time`, `Date`,
  `NaiveDateTime`, and `DateTime`) or any map, as long as they
  contain all of the relevant fields necessary for formatting.
  For example, if you use `%Y` to format the year, the datetime
  must have the `:year` field. Therefore, if you pass a `Time`,
  or a map without the `:year` field to a format that expects `%Y`,
  an error will be raised.

  Examples of common usage:

      iex> Calendar.strftime(~U[2019-08-26 13:52:06.0Z], "%y-%m-%d %I:%M:%S %p")
      "19-08-26 01:52:06 PM"

      iex> Calendar.strftime(~U[2019-08-26 13:52:06.0Z], "%a, %B %d %Y")
      "Mon, August 26 2019"

  ## User Options

    * `:preferred_datetime` - a string for the preferred format to show datetimes,
      it can't contain the `%c` format and defaults to `"%Y-%m-%d %H:%M:%S"`
      if the option is not received

    * `:preferred_date` - a string for the preferred format to show dates,
      it can't contain the `%x` format and defaults to `"%Y-%m-%d"`
      if the option is not received

    * `:preferred_time` - a string for the preferred format to show times,
      it can't contain the `%X` format and defaults to `"%H:%M:%S"`
      if the option is not received

    * `:am_pm_names` - a function that receives either `:am` or `:pm`
      (and also the datetime if the function is arity/2) and returns
      the name of the period of the day, if the option is not received it defaults
      to a function that returns `"am"` and `"pm"`, respectively

    *  `:month_names` - a function that receives a number (and also the
      datetime if the function is arity/2) and returns the name of
      the corresponding month, if the option is not received it defaults to a
      function that returns the month names in English

    * `:abbreviated_month_names` - a function that receives a number (and also
      the datetime if the function is arity/2) and returns the
      abbreviated name of the corresponding month, if the option is not received it
      defaults to a function that returns the abbreviated month names in English

    * `:day_of_week_names` - a function that receives a number and (and also the
      datetime if the function is arity/2) returns the name of
      the corresponding day of week, if the option is not received it defaults to a
      function that returns the day of week names in English

    * `:abbreviated_day_of_week_names` - a function that receives a number (and also
      the datetime if the function is arity/2) and returns the abbreviated name of
      the corresponding day of week, if the option is not received it defaults to a
      function that returns the abbreviated day of week names in English

  ## Formatting syntax

  The formatting syntax for the `string_format` argument is a sequence of characters in
  the following format:

      %<padding><width><format>

  where:

    * `%`: indicates the start of a formatted section
    * `<padding>`: set the padding (see below)
    * `<width>`: a number indicating the minimum size of the formatted section
    * `<format>`: the format itself (see below)

  ### Accepted padding options

    * `-`: no padding, removes all padding from the format
    * `_`: pad with spaces
    * `0`: pad with zeroes

  ### Accepted string formats

  The accepted formats for `string_format` are:

  Format | Description                                                             | Examples (in ISO)
  :----- | :-----------------------------------------------------------------------| :------------------------
  a      | Abbreviated name of day                                                 | Mon
  A      | Full name of day                                                        | Monday
  b      | Abbreviated month name                                                  | Jan
  B      | Full month name                                                         | January
  c      | Preferred date+time representation                                      | 2018-10-17 12:34:56
  d      | Day of the month                                                        | 01, 31
  f      | Microseconds (uses its precision for width and padding)                 | 000000, 999999, 0123
  H      | Hour using a 24-hour clock                                              | 00, 23
  I      | Hour using a 12-hour clock                                              | 01, 12
  j      | Day of the year                                                         | 001, 366
  m      | Month                                                                   | 01, 12
  M      | Minute                                                                  | 00, 59
  p      | "AM" or "PM" (noon is "PM", midnight as "AM")                           | AM, PM
  P      | "am" or "pm" (noon is "pm", midnight as "am")                           | am, pm
  q      | Quarter                                                                 | 1, 2, 3, 4
  s      | Number of seconds since the Epoch, 1970-01-01 00:00:00+0000 (UTC)       | 1565888877
  S      | Second                                                                  | 00, 59, 60
  u      | Day of the week                                                         | 1 (Monday), 7 (Sunday)
  x      | Preferred date (without time) representation                            | 2018-10-17
  X      | Preferred time (without date) representation                            | 12:34:56
  y      | Year as 2-digits                                                        | 01, 01, 86, 18
  Y      | Year                                                                    | -0001, 0001, 1986
  z      | +hhmm/-hhmm time zone offset from UTC (empty string if naive)           | +0300, -0530
  Z      | Time zone abbreviation (empty string if naive)                          | CET, BRST
  %      | Literal "%" character                                                   | %

  Any other character will be interpreted as an invalid format and raise an error.

  ### `%f` Microseconds

  `%f` does not support width and padding modifiers.  It will be formatted by truncating
  the microseconds to the precision of the `microseconds` field of the struct, with a
  minimum precision of 1.

  ## Examples

  Without user options:

      iex> Calendar.strftime(~U[2019-08-26 13:52:06.0Z], "%y-%m-%d %I:%M:%S %p")
      "19-08-26 01:52:06 PM"

      iex> Calendar.strftime(~U[2019-08-26 13:52:06.0Z], "%a, %B %d %Y")
      "Mon, August 26 2019"

      iex> Calendar.strftime(~U[2020-04-02 13:52:06.0Z], "%B %-d, %Y")
      "April 2, 2020"

      iex> Calendar.strftime(~U[2019-08-26 13:52:06.0Z], "%c")
      "2019-08-26 13:52:06"

  With user options:

      iex> Calendar.strftime(~U[2019-08-26 13:52:06.0Z], "%c", preferred_datetime: "%H:%M:%S %d-%m-%y")
      "13:52:06 26-08-19"

      iex> Calendar.strftime(
      ...>  ~U[2019-08-26 13:52:06.0Z],
      ...>  "%A",
      ...>  day_of_week_names: fn day_of_week ->
      ...>    {"segunda-feira", "terça-feira", "quarta-feira", "quinta-feira",
      ...>    "sexta-feira", "sábado", "domingo"}
      ...>    |> elem(day_of_week - 1)
      ...>  end
      ...>)
      "segunda-feira"

      iex> Calendar.strftime(
      ...>  ~U[2019-08-26 13:52:06.0Z],
      ...>  "%B",
      ...>  month_names: fn month ->
      ...>    {"січень", "лютий", "березень", "квітень", "травень", "червень",
      ...>    "липень", "серпень", "вересень", "жовтень", "листопад", "грудень"}
      ...>    |> elem(month - 1)
      ...>  end
      ...>)
      "серпень"

   Microsecond formatting:

      iex> Calendar.strftime(~U[2019-08-26 13:52:06Z], "%y-%m-%d %H:%M:%S.%f")
      "19-08-26 13:52:06.0"

      iex> Calendar.strftime(~U[2019-08-26 13:52:06.048Z], "%y-%m-%d %H:%M:%S.%f")
      "19-08-26 13:52:06.048"

      iex> Calendar.strftime(~U[2019-08-26 13:52:06.048531Z], "%y-%m-%d %H:%M:%S.%f")
      "19-08-26 13:52:06.048531"

  """
  @doc since: "1.11.0"
  @spec strftime(map(), String.t(), strftime_opts()) :: String.t()
  def strftime(date_or_time_or_datetime, string_format, user_options \\ [])
      when is_map(date_or_time_or_datetime) and is_binary(string_format) do
    parse(
      string_format,
      date_or_time_or_datetime,
      options(user_options),
      []
    )
    |> IO.iodata_to_binary()
  end

  defp parse("", _datetime, _format_options, acc),
    do: Enum.reverse(acc)

  defp parse("%" <> rest, datetime, format_options, acc),
    do: parse_modifiers(rest, nil, nil, {datetime, format_options, acc})

  defp parse(<<char, rest::binary>>, datetime, format_options, acc),
    do: parse(rest, datetime, format_options, [char | acc])

  defp parse_modifiers("-" <> rest, width, nil, parser_data) do
    parse_modifiers(rest, width, "", parser_data)
  end

  defp parse_modifiers("0" <> rest, nil, nil, parser_data) do
    parse_modifiers(rest, nil, ?0, parser_data)
  end

  defp parse_modifiers("_" <> rest, width, nil, parser_data) do
    parse_modifiers(rest, width, ?\s, parser_data)
  end

  defp parse_modifiers(<<digit, rest::binary>>, width, pad, parser_data) when digit in ?0..?9 do
    new_width = (width || 0) * 10 + (digit - ?0)

    parse_modifiers(rest, new_width, pad, parser_data)
  end

  # set default padding if none was specified
  defp parse_modifiers(<<format, _::binary>> = rest, width, nil, parser_data) do
    parse_modifiers(rest, width, default_pad(format), parser_data)
  end

  # set default width if none was specified
  defp parse_modifiers(<<format, _::binary>> = rest, nil, pad, parser_data) do
    parse_modifiers(rest, default_width(format), pad, parser_data)
  end

  defp parse_modifiers(rest, width, pad, {datetime, format_options, acc}) do
    format_modifiers(rest, width, pad, datetime, format_options, acc)
  end

  defp am_pm(hour, format_options, datetime) when hour > 11 do
    apply_format(:pm, format_options.am_pm_names, datetime)
  end

  defp am_pm(hour, format_options, datetime) when hour <= 11 do
    apply_format(:am, format_options.am_pm_names, datetime)
  end

  defp default_pad(format) when format in ~c"aAbBpPZ", do: ?\s
  defp default_pad(_format), do: ?0

  defp default_width(format) when format in ~c"dHImMSy", do: 2
  defp default_width(?j), do: 3
  defp default_width(format) when format in ~c"Yz", do: 4
  defp default_width(_format), do: 0

  # Literally just %
  defp format_modifiers("%" <> rest, width, pad, datetime, format_options, acc) do
    parse(rest, datetime, format_options, [pad_leading("%", width, pad) | acc])
  end

  # Abbreviated name of day
  defp format_modifiers("a" <> rest, width, pad, datetime, format_options, acc) do
    result =
      datetime
      |> Date.day_of_week()
      |> apply_format(format_options.abbreviated_day_of_week_names, datetime)
      |> pad_leading(width, pad)

    parse(rest, datetime, format_options, [result | acc])
  end

  # Full name of day
  defp format_modifiers("A" <> rest, width, pad, datetime, format_options, acc) do
    result =
      datetime
      |> Date.day_of_week()
      |> apply_format(format_options.day_of_week_names, datetime)
      |> pad_leading(width, pad)

    parse(rest, datetime, format_options, [result | acc])
  end

  # Abbreviated month name
  defp format_modifiers("b" <> rest, width, pad, datetime, format_options, acc) do
    result =
      datetime.month
      |> apply_format(format_options.abbreviated_month_names, datetime)
      |> pad_leading(width, pad)

    parse(rest, datetime, format_options, [result | acc])
  end

  # Full month name
  defp format_modifiers("B" <> rest, width, pad, datetime, format_options, acc) do
    result =
      datetime.month
      |> apply_format(format_options.month_names, datetime)
      |> pad_leading(width, pad)

    parse(rest, datetime, format_options, [result | acc])
  end

  # Preferred date+time representation
  defp format_modifiers(
         "c" <> _rest,
         _width,
         _pad,
         _datetime,
         %{preferred_datetime_invoked: true},
         _acc
       ) do
    raise ArgumentError,
          "tried to format preferred_datetime within another preferred_datetime format"
  end

  defp format_modifiers("c" <> rest, width, pad, datetime, format_options, acc) do
    result =
      format_options.preferred_datetime
      |> parse(datetime, %{format_options | preferred_datetime_invoked: true}, [])
      |> pad_preferred(width, pad)

    parse(rest, datetime, format_options, [result | acc])
  end

  # Day of the month
  defp format_modifiers("d" <> rest, width, pad, datetime, format_options, acc) do
    result = datetime.day |> Integer.to_string() |> pad_leading(width, pad)
    parse(rest, datetime, format_options, [result | acc])
  end

  # Microseconds
  defp format_modifiers("f" <> rest, _width, _pad, datetime, format_options, acc) do
    {microsecond, precision} = datetime.microsecond

    result =
      microsecond
      |> Integer.to_string()
      |> String.pad_leading(6, "0")
      |> binary_part(0, max(precision, 1))

    parse(rest, datetime, format_options, [result | acc])
  end

  # Hour using a 24-hour clock
  defp format_modifiers("H" <> rest, width, pad, datetime, format_options, acc) do
    result = datetime.hour |> Integer.to_string() |> pad_leading(width, pad)
    parse(rest, datetime, format_options, [result | acc])
  end

  # Hour using a 12-hour clock
  defp format_modifiers("I" <> rest, width, pad, datetime, format_options, acc) do
    result = (rem(datetime.hour + 23, 12) + 1) |> Integer.to_string() |> pad_leading(width, pad)
    parse(rest, datetime, format_options, [result | acc])
  end

  # Day of the year
  defp format_modifiers("j" <> rest, width, pad, datetime, format_options, acc) do
    result = datetime |> Date.day_of_year() |> Integer.to_string() |> pad_leading(width, pad)
    parse(rest, datetime, format_options, [result | acc])
  end

  # Month
  defp format_modifiers("m" <> rest, width, pad, datetime, format_options, acc) do
    result = datetime.month |> Integer.to_string() |> pad_leading(width, pad)
    parse(rest, datetime, format_options, [result | acc])
  end

  # Minute
  defp format_modifiers("M" <> rest, width, pad, datetime, format_options, acc) do
    result = datetime.minute |> Integer.to_string() |> pad_leading(width, pad)
    parse(rest, datetime, format_options, [result | acc])
  end

  # "AM" or "PM" (noon is "PM", midnight as "AM")
  defp format_modifiers("p" <> rest, width, pad, datetime, format_options, acc) do
    result =
      datetime.hour
      |> am_pm(format_options, datetime)
      |> String.upcase()
      |> pad_leading(width, pad)

    parse(rest, datetime, format_options, [result | acc])
  end

  # "am" or "pm" (noon is "pm", midnight as "am")
  defp format_modifiers("P" <> rest, width, pad, datetime, format_options, acc) do
    result =
      datetime.hour
      |> am_pm(format_options, datetime)
      |> String.downcase()
      |> pad_leading(width, pad)

    parse(rest, datetime, format_options, [result | acc])
  end

  # Quarter
  defp format_modifiers("q" <> rest, width, pad, datetime, format_options, acc) do
    result = datetime |> Date.quarter_of_year() |> Integer.to_string() |> pad_leading(width, pad)
    parse(rest, datetime, format_options, [result | acc])
  end

  # Second
  defp format_modifiers("S" <> rest, width, pad, datetime, format_options, acc) do
    result = datetime.second |> Integer.to_string() |> pad_leading(width, pad)
    parse(rest, datetime, format_options, [result | acc])
  end

  # Day of the week
  defp format_modifiers("u" <> rest, width, pad, datetime, format_options, acc) do
    result = datetime |> Date.day_of_week() |> Integer.to_string() |> pad_leading(width, pad)
    parse(rest, datetime, format_options, [result | acc])
  end

  # Preferred date (without time) representation
  defp format_modifiers(
         "x" <> _rest,
         _width,
         _pad,
         _datetime,
         %{preferred_date_invoked: true},
         _acc
       ) do
    raise ArgumentError,
          "tried to format preferred_date within another preferred_date format"
  end

  defp format_modifiers("x" <> rest, width, pad, datetime, format_options, acc) do
    result =
      format_options.preferred_date
      |> parse(datetime, %{format_options | preferred_date_invoked: true}, [])
      |> pad_preferred(width, pad)

    parse(rest, datetime, format_options, [result | acc])
  end

  # Preferred time (without date) representation
  defp format_modifiers(
         "X" <> _rest,
         _width,
         _pad,
         _datetime,
         %{preferred_time_invoked: true},
         _acc
       ) do
    raise ArgumentError,
          "tried to format preferred_time within another preferred_time format"
  end

  defp format_modifiers("X" <> rest, width, pad, datetime, format_options, acc) do
    result =
      format_options.preferred_time
      |> parse(datetime, %{format_options | preferred_time_invoked: true}, [])
      |> pad_preferred(width, pad)

    parse(rest, datetime, format_options, [result | acc])
  end

  # Year as 2-digits
  defp format_modifiers("y" <> rest, width, pad, datetime, format_options, acc) do
    result = datetime.year |> rem(100) |> Integer.to_string() |> pad_leading(width, pad)
    parse(rest, datetime, format_options, [result | acc])
  end

  # Year
  defp format_modifiers("Y" <> rest, width, pad, datetime, format_options, acc) do
    {sign, year} =
      if datetime.year < 0 do
        {?-, -datetime.year}
      else
        {[], datetime.year}
      end

    result = [sign | year |> Integer.to_string() |> pad_leading(width, pad)]
    parse(rest, datetime, format_options, [result | acc])
  end

  # Epoch time for DateTime with time zones
  defp format_modifiers(
         "s" <> rest,
         _width,
         _pad,
         datetime = %{utc_offset: _utc_offset, std_offset: _std_offset},
         format_options,
         acc
       ) do
    result =
      datetime
      |> DateTime.shift_zone!("Etc/UTC")
      |> NaiveDateTime.diff(~N[1970-01-01 00:00:00])
      |> Integer.to_string()

    parse(rest, datetime, format_options, [result | acc])
  end

  # Epoch time
  defp format_modifiers("s" <> rest, _width, _pad, datetime, format_options, acc) do
    result =
      datetime
      |> NaiveDateTime.diff(~N[1970-01-01 00:00:00])
      |> Integer.to_string()

    parse(rest, datetime, format_options, [result | acc])
  end

  # +hhmm/-hhmm time zone offset from UTC (empty string if naive)
  defp format_modifiers(
         "z" <> rest,
         width,
         pad,
         datetime = %{utc_offset: utc_offset, std_offset: std_offset},
         format_options,
         acc
       ) do
    absolute_offset = abs(utc_offset + std_offset)

    offset_number =
      Integer.to_string(div(absolute_offset, 3600) * 100 + rem(div(absolute_offset, 60), 60))

    sign = if utc_offset + std_offset >= 0, do: "+", else: "-"
    result = "#{sign}#{pad_leading(offset_number, width, pad)}"
    parse(rest, datetime, format_options, [result | acc])
  end

  defp format_modifiers("z" <> rest, _width, _pad, datetime, format_options, acc) do
    parse(rest, datetime, format_options, ["" | acc])
  end

  # Time zone abbreviation (empty string if naive)
  defp format_modifiers("Z" <> rest, width, pad, datetime, format_options, acc) do
    result = datetime |> Map.get(:zone_abbr, "") |> pad_leading(width, pad)
    parse(rest, datetime, format_options, [result | acc])
  end

  defp format_modifiers(rest, _width, _pad, _datetime, _format_options, _acc) do
    {next, _rest} = String.next_grapheme(rest) || {"", ""}
    raise ArgumentError, "invalid strftime format: %#{next}"
  end

  defp pad_preferred(result, width, pad) when length(result) < width do
    pad_preferred([pad | result], width, pad)
  end

  defp pad_preferred(result, _width, _pad), do: result

  defp pad_leading(string, count, padding) do
    to_pad = count - byte_size(string)
    if to_pad > 0, do: do_pad_leading(to_pad, padding, string), else: string
  end

  defp do_pad_leading(0, _, acc), do: acc

  defp do_pad_leading(count, padding, acc),
    do: do_pad_leading(count - 1, padding, [padding | acc])

  defp apply_format(term, formatter, _datetime) when is_function(formatter, 1) do
    formatter.(term)
  end

  defp apply_format(term, formatter, datetime) when is_function(formatter, 2) do
    formatter.(term, datetime)
  end

  defp apply_format(_term, formatter, _datetime) do
    raise ArgumentError, "formatter functions must be of arity 1 or 2, got: #{inspect(formatter)}"
  end

  defp options(user_options) do
    default_options = %{
      preferred_date: "%Y-%m-%d",
      preferred_time: "%H:%M:%S",
      preferred_datetime: "%Y-%m-%d %H:%M:%S",
      am_pm_names: fn
        :am -> "am"
        :pm -> "pm"
      end,
      month_names: fn month ->
        {"January", "February", "March", "April", "May", "June", "July", "August", "September",
         "October", "November", "December"}
        |> elem(month - 1)
      end,
      day_of_week_names: fn day_of_week ->
        {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
        |> elem(day_of_week - 1)
      end,
      abbreviated_month_names: fn month ->
        {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
        |> elem(month - 1)
      end,
      abbreviated_day_of_week_names: fn day_of_week ->
        {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"} |> elem(day_of_week - 1)
      end,
      preferred_datetime_invoked: false,
      preferred_date_invoked: false,
      preferred_time_invoked: false
    }

    Enum.reduce(user_options, default_options, fn {key, value}, acc ->
      if Map.has_key?(acc, key) do
        %{acc | key => value}
      else
        raise ArgumentError, "unknown option #{inspect(key)} given to Calendar.strftime/3"
      end
    end)
  end
end
