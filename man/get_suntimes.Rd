% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/activity_code.r
\name{get_suntimes}
\alias{get_suntimes}
\title{Calculates solar event times}
\usage{
get_suntimes(
  date,
  lat,
  lon,
  offset,
  ...,
  tryFormats = c("\%Y-\%m-\%d \%H:\%M:\%OS", "\%Y/\%m/\%d \%H:\%M:\%OS",
    "\%Y:\%m:\%d \%H:\%M:\%OS", "\%Y-\%m-\%d \%H:\%M", "\%Y/\%m/\%d \%H:\%M",
    "\%Y:\%m:\%d \%H:\%M", "\%Y-\%m-\%d", "\%Y/\%m/\%d", "\%Y:\%m:\%d")
)
}
\arguments{
\item{date}{character, POSIX or Date format date/time value(s)}

\item{lat, lon}{latitude and longitude in decimal degrees}

\item{offset}{the time offset in hours relative to UTC (GMT) for results}

\item{...}{arguments passed to as.POSIXlt}

\item{tryFormats}{formats to try when converting date from character, passed to as.POSIXlt}
}
\value{
A dataframe with columns sunrise and sunset (given in the timezone defined by offset) and daylength, all expressed in hours.
}
\description{
Calculates approximate times of sunrise and sunset and day lengths
for given dates at given locations.
}
\details{
Function adapted from https://www.r-bloggers.com/2014/09/seeing-the-daylight-with-r/
}
\examples{
data(BCItime)
dat <- subset(BCItime, species=="ocelot")$date
get_suntimes(dat, 9.156335, -79.847682, -5)
}
\references{
Teets, D.A. 2003. Predicting sunrise and sunset times. The College Mathematics Journal 34(4):317-321.
}
