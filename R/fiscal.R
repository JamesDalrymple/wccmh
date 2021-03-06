#' @title fiscal functions
#' @description fiscal year, fiscal quarter, month functions for dealing with
#' 'Date' classes.
#'
#' @usage my_fy(x, format = NULL, fy_start = "Oct")
#' @usage my_qtr(x, format = NULL, fy_start = "Oct"
#' @param x 'Date' vector or a character vector that can be coerced to 'Date'
#' class.
#' @param format The format of the date, passed to date_convert.
#' @param fy_start The month the fiscal year starts. May be abbreviated to
#' three letters or be the full name of the month. The three-letter
#' abbreviation must match the package zoo's abbreviations.
#'
#' @examples
#' my_fy("10/1/2014")
#' my_qtr("9/30/2015")
#' @return A character vector.
#'
#' @note Consider making a new fiscal_year class and/or fiscal_quarter class.
#' Also consider making some methods (this needs further consideration).
#'
#' @importFrom zoo as.yearqtr as.yearmon
#' @name fiscal
NULL

#' @rdname fiscal
#' @export
# function for creating a fiscal year from month (date class) ----
my_fy <- function(x, format = NULL, fy_start = "Oct") {
  qtr_add <-
    as.num(as.yearqtr(as.yearmon(paste("Jan", 2011)))) -
    as.num(as.yearqtr(as.yearmon(paste(fy_start, 2010))))

  if (class(x) != "Date" ) {
    x <- date_convert(x, format = format)
  }
  quarter <- as.yearqtr(x) + qtr_add
  year <- as.character(substr(quarter, 1, 4))
  return(year)
}

#' @rdname fiscal
#' @export
my_qtr <- function(x, format = NULL, fy_start = "Oct") {
  if (class(x) != "Date") {
    x <- date_convert(x, format = format)
  }
  qtr_add <-
    as.num(as.yearqtr(as.yearmon(paste("Jan", 2011)))) -
    as.num(as.yearqtr(as.yearmon(paste(fy_start, 2010))))
  quarter <- as.yearqtr(x) + qtr_add
  quarter <- as.character(quarter)
  return(quarter)
}
