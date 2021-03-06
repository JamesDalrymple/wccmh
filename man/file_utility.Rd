% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/file_utility.R
\name{file_utility}
\alias{file_utility}
\alias{csv_to_rds}
\alias{load_data}
\title{WCCMH file utility functions}
\usage{
csv_to_rds(csv_file, keep_cols, rename_cols, rm.original)

load_data(work_dir, file_pattern, keep_cols = NULL, rename_cols = NULL,
  rm.original = FALSE)
}
\arguments{
\item{csv_file}{the name of the file with the full file location.}

\item{keep_cols}{the column names you want to retain.}

\item{rename_cols}{column names to rename, defaults to NULL where no
changes take effect.}

\item{rm.original}{logical TRUE/FALSE whether to delete original csv file.}

\item{work_dir}{the working direction containing either csv and/or rds
files.}

\item{file_pattern}{what file should be selected. Please make the file
pattern select a unique file.}
}
\value{
A vector of recoded fund names.
}
\description{
csv_to_rds reads
}
\note{
if you can get away from csv file storage, this is recommended. If you
can get even further away from file storage on a hard drive and use a
database, that is ideal.
}
\seealso{
file.path
}
