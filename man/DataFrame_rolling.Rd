% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dataframe__frame.R
\name{DataFrame_rolling}
\alias{DataFrame_rolling}
\title{Create rolling groups based on a date/time or integer column}
\usage{
DataFrame_rolling(
  index_column,
  period,
  offset = NULL,
  closed = "right",
  by = NULL,
  check_sorted = TRUE
)
}
\arguments{
\item{index_column}{Column used to group based on the time window. Often of
type Date/Datetime. This column must be sorted in ascending order (or, if \code{by}
is specified, then it must be sorted in ascending order within each group). In
case of a rolling group by on indices, dtype needs to be either Int32 or Int64.
Note that Int32 gets temporarily cast to Int64, so if performance matters use
an Int64 column.}

\item{period}{Length of the window, must be non-negative.}

\item{offset}{Offset of the window. Default is \code{-period}.}

\item{closed}{Define which sides of the temporal interval are closed
(inclusive). This can be either \code{"left"}, \code{"right"}, \code{"both"} or \code{"none"}.}

\item{by}{Also group by this column/these columns.}

\item{check_sorted}{Check whether data is actually sorted. Checking it is
expensive so if you are sure the data within the \code{index_column} is sorted, you
can set this to \code{FALSE} but note that if the data actually is unsorted, it
will lead to incorrect output.}
}
\value{
A \link[=GroupBy_class]{GroupBy} object
}
\description{
If you have a time series \verb{<t_0, t_1, ..., t_n>}, then by default the windows
created will be:
\itemize{
\item (t_0 - period, t_0]
\item (t_1 - period, t_1]
\item …
\item (t_n - period, t_n]
}

whereas if you pass a non-default offset, then the windows will be:
\itemize{
\item (t_0 + offset, t_0 + offset + period]
\item (t_1 + offset, t_1 + offset + period]
\item …
\item (t_n + offset, t_n + offset + period]
}
}
\details{
The period and offset arguments are created either from a timedelta, or by
using the following string language:
\itemize{
\item 1ns (1 nanosecond)
\item 1us (1 microsecond)
\item 1ms (1 millisecond)
\item 1s (1 second)
\item 1m (1 minute)
\item 1h (1 hour)
\item 1d (1 calendar day)
\item 1w (1 calendar week)
\item 1mo (1 calendar month)
\item 1q (1 calendar quarter)
\item 1y (1 calendar year)
\item 1i (1 index count)
}

Or combine them: "3d12h4m25s" # 3 days, 12 hours, 4 minutes, and 25 seconds

By "calendar day", we mean the corresponding time on the next day (which may
not be 24 hours, due to daylight savings). Similarly for "calendar week",
"calendar month", "calendar quarter", and "calendar year".

In case of a rolling operation on an integer column, the windows are defined
by:
\itemize{
\item "1i" # length 1
\item "10i" # length 10
}
}
\examples{
df = pl$DataFrame(
  dt = c("2020-01-01", "2020-01-01", "2020-01-01", "2020-01-02", "2020-01-03", "2020-01-08"),
  a = c(3, 7, 5, 9, 2, 1)
)$with_columns(
  pl$col("dt")$str$strptime(pl$Date, format = NULL)$set_sorted()
)

df$rolling(index_column = "dt", period = "2d")$agg(
  pl$col("a"),
  pl$sum("a")$alias("sum_a"),
  pl$min("a")$alias("min_a"),
  pl$max("a")$alias("max_a")
)
}
