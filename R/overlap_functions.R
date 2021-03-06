#' @title WCCMH admission functions
#' @description These functions are for datasets that have integer or date
#' columns that need to be combined by some unique grouping or with the
#' additional constraint of a priority column when the priority column causes
#' an overlap outside of the unique grouping but within the priority column.
#'
#' @param data A data.table object with collapsable records.
#' @param group_cols A group of columns which will collectively make a key on
#' which to group by when reducing/collapsing the data.table object.
#' @param priority_col A single column which will have a priority assignment.
#' @param priority_int A positive integer for priority, 1 being highest
#' priority and each consecutive integer of lower priority than the previous.
#' @param start_col The start date for record. Blanks not allowed.
#' @param end_col The end date for the record. Blanks will be replaced, see
#' @param overlap_int An integer, default value of 1, to find consecutive
#' records.
#' @param analysis_date If end_col has missing values, they will be replaced
#' with this value. Defaults to Sys.Date().
#'
#' @return overlap_combine returns a reduced/collapsed data.table object based
#' on group_cols.
#' priority_overlap returns a data.table with fixed records based on priority
#' team assignment. May contain more rows than original dataset.
#'
#' @note Do not have data columns named strdt, enddt, pk_1, pk_2, ... You have
#' been warned! MAJOR rewrite coming eventually... hopefully backward compatible
#'
#' @examples
#' data(ex_overlap)
#' suppressWarnings(overlap_combine(data = ex_overlap, group_cols = Cc(team, priority),
#'  start_col = Cc(team_start), end_col = Cc(team_end)) %>% print)
#' @import data.table
#' @importFrom TBmisc p_warn grepv d.t Cc
#' @import magrittr
#' @name overlap_functions
NULL


sql_adm <- if (FALSE) {
  require(cmhmisc)
  require(RODBC)
  require(data.table)
  sql <- list(
    channel = odbcConnect("WSHSQL002"),
    query = list()
  )
  # admissions
  sql$query$adm <-
    sprintf(
      "select distinct
      adm.case_no, adm.provider_eff as team_eff, adm.provider_exp as team_exp,
      adm.provider as team, adm.assigned_staff as staff, adm.staff_eff,
      adm.staff_exp, adm.adm_effdt, adm.adm_expdt
      from encompass.dbo.tblE2_Adm_Consumers as adm
      where adm.county = 'Washtenaw' and adm.provider in
      ('WSH - ACT', 'WSH - ATO' , 'WSH - Children''s Services',
      'WSH - Children''s Services - Home Based', 'WSH - DD Adult',
      'WSH - Access/Engagement', 'Washtenaw County Community Mental Health',
      'Washtenaw County Community Mental Health-External',
      'WSH - MI - Adult')
      and adm.providertype = 'Direct Provider'
      and adm.provider_eff <= '%2$s' and
      (adm.provider_exp >= '%1$s' or adm.provider_exp is null)",
      "10/1/2010", "9/30/2017")
  sql$adm <- sqlQuery(query = sql$query$adm,
    channel = sql$channel, stringsAsFactors = FALSE)
  sql$adm <- data.table(sql$adm)
  adm <- copy(sql$adm)
  adm[, Cc(staff_eff, staff_exp, staff) := NULL]
  adm[, team_eff := as.Date(team_eff)]
  adm[, team_exp := as.Date(team_exp)]
  adm <- unique(adm)
  cmhmisc::overlap_combine(
    data = adm, group_cols = Cc(team, adm_effdt, adm_expdt),
    start_col = "team_eff", end_col = "team_exp", overlap_int = 1L,
    analysis_date = Sys.Date()
  )[]
}


# R CMD checker appeasement ---
index <- i.index <- i.start_date <- start_date <- i.end_col <- end_date <-
  ovr_vec <- xid <- yid <- i.priority <- ovr_pairs <- i.end_date <- i.team <-
  remove_record <- p_col <- i.p_col <- grp_id <- .GRP <- grp_n <-
  add_record <- new_index <- p_int <- i.p_int <- NULL
# hh_nurse <- copy(sql$output$hh_nurse)
# data <- hh_nurse
# group_cols <- Cc(hh_nurse)
# start_col = "hhnurse_effdt"
# end_col = "hhnurse_expdt"
# x_dt <- overlap_combine(data = hh_nurse, group_cols = Cc(hh_nurse),
#   start_col = Cc(hhnurse_effdt), end_col = Cc(hhnurse_expdt),
#   overlap_int = 14, analysis_date = Sys.Date())


# data <- unique(adm)
# group_cols <- Cc()
# start_col <- "team_eff"
# end_col <- "team_exp"
# overlap_int <- 1L
# analysis_date <- Sys.Date()


# last corrected 9/26/2017, 9/15/2016
#' @export
#' @rdname overlap_functions
overlap_combine <-
  function(data, group_cols, start_col, end_col, overlap_int = 1L,
           analysis_date = Sys.Date()) {
    d <- copy(data)
    if (nrow(unique(d)) < nrow(d)) {
      stop("the input data contained duplicate rows")
    }

    if (any(names(d) == "end_col")) {
      d[, end_col := NULL]
      stop("You had a column labeled end_col which conflicts with overlap_comb.")
    }
    if (any(names(d) %in% Cc(start_date, end_date))) {
      stop("One or more columns were named 'start_date', 'end_col' or 'end_date'.")
    }
    setnames(d, start_col, "start_date")
    setnames(d, end_col, "end_date")

    group_cols <- grepv(x = names(d), pattern = "start_date|end_date", invert = TRUE)
    d[, end_col := end_date]

    if (d[, start_date] %>% class %>% equals("Date") %>% not) {
      warning("start_col was not supplied as a Date; as.Date was applied but please
              submit end_col as Date class to avoid potential Date conversion
              errors.")
      d[, start_date := as.Date(start_date)]
    }

    if (d[, end_date] %>% class %>% equals("Date") %>% not) {
      warning("end_col was not supplied as a Date; as.Date was applied but please
             submit end_col as Date class to avoid potential Date conversion
             errors.")
      d[, end_col := as.Date(end_col)]
    }
    d[, end_col := end_col + overlap_int]
    # sd_cols <- c(start_col, "end_col")
    d[is.na(end_col), end_col := analysis_date]
    # note: if end_col becomes < start_col due to overlap_int,
    # we assign end_col <- start_col
    if (nrow(d[end_col - start_date < 0]) > 0) {
      d[end_col - start_date < 0, Cc(end_col, end_date)
        := list(start_date, start_date)]
      warning("you had start_col and end_col out of order")
    }
    d[, index := .I]

    # finding overlapping combinations via vectors of indices ---
    c_overlap <-
      d[d[, unique(.SD), .SDcols =
            c(group_cols, "start_date", "end_col", "index")],
        on = group_cols, allow.cartesian = TRUE]
    c_overlap <- c_overlap[i.index != index]
    c_overlap[between(i.start_date, start_date, end_col) |
                between(i.end_col, start_date, end_col),
              ovr_vec := list(list(unique(c(index, i.index)))),
              by = c(group_cols, "start_date")]

    if (!is.null(c_overlap$ovr_vec)) {
      ovr_l <- c_overlap[, ovr_vec]
      ovr_l <- Filter(Negate(function(x) is.null(unlist(x))), ovr_l)
      ovr_l <- unique(ovr_l)
      # find list of reduced vectors which we need to MIN/MAX ---
      ovr_red_l <- list()
      for (i in seq_along(ovr_l)) {
        tmp_inter <- unique(as.vector(unlist(sapply(
          ovr_l,
          FUN = function(x) {
            if (length(intersect(unlist(x), unlist(ovr_l[i]))) > 0) {
              result <- union(unlist(x), unlist(ovr_l[i]))
              return(result)
            } else {
              return(ovr_l[i])
            }
          }
        ))))
        ovr_red_l[[i]] <- sort(tmp_inter)
      }
      ovr_red_l <- unique(ovr_red_l)

      for (i in seq(ovr_red_l)) {
        setkey(d, index)[ovr_red_l[[i]],
                         c("start_date", "end_date", "end_col") :=
                           list(min(start_date), max(end_date), max(end_col))]
      }
    }
    d[, Cc(index) := NULL]
    d %<>% unique
    setnames(d, "start_date", start_col)
    setnames(d, "end_date", end_col)
    d[, end_col := NULL]
    return(d)
    }

WIP <- if (FALSE) {
case <- uN <- fl_pk <- gs_i <- pk <- fdate <- ldate <- NULL
overlap_combine2 <-
  function(data,
           case_col,
           group_cols,
           start_col,
           end_col,
           overlap_int = 1L,
           analysis_date = Sys.Date()) {
    # data = adm
    # case_col = "case_no"
    # group_cols = c("team", "adm_effdt", "adm_expdt")
    # start_col = "team_eff"
    # end_col = "team_exp"
    # overlap_int = 1L
    # analysis_date = Sys.Date()


    focus_flds  <- c(start_col, end_col, case_col, group_cols)
    remand_flds <- setdiff(names(data), focus_flds)
    d <- copy(data)[, .SD, .SDc = c(focus_flds, remand_flds)]
    GS_v <- group_cols
    SD_v <- c(srt_date_col = "strcol", end_date_col = "endcol")
    CS_v <- Cc(case)
    setnames(d, c(SD_v, CS_v, GS_v, remand_flds))
    set(d,
        j = SD_v,
        value = lapply(d[, SD_v, with = FALSE], as.Date, format = '%m/%d/%Y'))
    if (!inherits(analysis_date, what = "Date"))
      analysis_date <- as.Date(analysis_date)
    d[, uN := nrow(.SD), by = c(CS_v, GS_v)]
    # d[uN > 3]
    # setorderv(d, c(CS_v, GS_v, SD_v))
    setkeyv(d, c(SD_v))
    # d[, fl_pk := 1]
    # d[case==1126484]
    # Rcpp::sourceCpp("./src/overlap.cpp")
    # d[case==244779]
    # casenum <- 10499
    # casenum <- 244779
    # casenum <- 1126484
    d[, fl_pk := NA_integer_]
    folp <-
      function(SD1,
               SD2,
               type = "any",
               which = TRUE,
               mult = "all") {
        flopz <<-
          foverlaps(SD1,
                    SD2,
                    type = type,
                    which = which,
                    mult = mult)
        z <- copy(flopz)
        zset <- d.t(xid = sort(unique((z$xid)), key = "xid"))
        z[xid > yid, `:=`(yid = xid, xid = yid)]
        z <- z[!duplicated(z)][order(xid, yid)] # & xid != yid
        if (z[,!any(xid != yid)] & nrow(z) == nrow(zset)) {
          return(z[, .(as.integer(yid))])
        } else if (z[, any(xid != yid)]) {
          rct <- copy(z[xid != yid])
          for (i in rev(seq_row(rct))) {
            # i=4 i=3 i=2 i=1
            rcs <- paste0(rct[i, yid], "=", rct[i, xid])
            z[, Cc(xid, yid) := lapply(.SD, recode, rcs)]
          }
          setkey(z, xid)
          return(z[zset, uni(.SD), roll = TRUE][, .(as.integer(yid))])
        }
        stop("The flop function has no idea how to handle a condition.")
      }
    #       d[uN > 1 & case == casenum]
    #        #& cmh_team == "Child"
    #       d[uN > 1 & case == casenum , folp(.SD, .SD), .SDc = c(SD_v), by = c(CS_v, GS_v)]

    d[uN > 1, fl_pk := folp(.SD, .SD), .SDc = c(SD_v), by = c(CS_v, GS_v)]
    d[is.na(fl_pk), fl_pk := 1L]

    setorderv(d, c(CS_v, "fl_pk", GS_v))
    d[, gs_i := seq(nrow(.SD)), by = c(CS_v, "fl_pk"), .SDc = GS_v]
    spntf_mnchr_v <- d[, unlist(.(
      case = max(nchar(case)),
      ugrp = max(nchar(as.character(gs_i))),
      ufol = max(nchar(fl_pk))
    ))]
    fmt <- paste0("%",
                  spntf_mnchr_v['case'],
                  ".0f-%",
                  spntf_mnchr_v['ugrp'],
                  ".0f-%",
                  spntf_mnchr_v['ufol'],
                  ".0f")
    d[, pk := gsub(" ", "0", sprintf(fmt, case, gs_i, fl_pk))]
    d[, fdate := min(unlist(.SD)), by = pk, .SDc = SD_v['srt_date_col']]
    d[, ldate := max(unlist(.SD)), by = pk, .SDc = SD_v['end_date_col']]
    dn_v <- names(d)
    for (j in grepv('date', dn_v))
      set(d, j = j, value = as.Date(d[[j]], origin = "1970-01-01"))
    output_vec <-
      c(CS_v, GS_v, grepv('date', dn_v), 'pk', remand_flds)
    d <- d[, unique(.SD), .SDc = output_vec]
    return(d)
  }
}

# priority column with overlapping date records -------------------------------
#' @export
#' @rdname overlap_functions
priority_overlap <- function(data,
                             group_cols,
                             priority_col,
                             priority_int,
                             start_col,
                             end_col,
                             overlap_int = 1L,
                             analysis_date = Sys.Date() + 999) {
  # data = copy(data)
  # group_cols = Cc(case_no, cmh_effdt)
  # priority_col = "cmh_team"
  # start_col = "team_effdt"
  # end_col = "team_expdt"
  group_cols <- setdiff(group_cols, priority_col)
  group_cols <- setdiff(group_cols, priority_int)
  # fix 'easier' issues first with simple min/max
  d <- overlap_combine(
    data = data,
    group_cols = c(group_cols, priority_col, priority_int),
    start_col = start_col,
    end_col = end_col,
    overlap_int = overlap_int,
    analysis_date = analysis_date
  )
  setnames(d, c(priority_col, priority_int), Cc(p_col, p_int))
  d[, p_int := as.int(p_int)]
  stopifnot(d[, class(p_int)] == "integer")
  # d[, end_col := NULL] # remove later
  d[, end_col := get(end_col)]
  if (d[, class(end_col)] != "Date") {
    p_warn("end_col was not supplied as a Date; as.Date was applied but please
             submit end_col as Date class to avoid potential Date conversion
             errors.")
    d[, end_col := as.Date(end_col)]
  }
  d[, end_col := end_col + overlap_int]
  d[is.na(end_col), end_col := analysis_date]
  setnames(d, c(start_col, end_col), Cc(start_date, end_date))
  d[!is.na(end_date), end_col := end_date]

  setkeyv(d, c(group_cols, "start_date", "end_col"))
  overlap_pairs_dt <-
    foverlaps(
      d[, .SD, .SDcols = c(group_cols, Cc(start_date, end_col))],
      d[, .SD, .SDcols = c(group_cols, Cc(start_date, end_col))],
      by.x = c(group_cols, "start_date", "end_col"),
      by.y = c(group_cols, "start_date", "end_col"),
      which = TRUE)[xid != yid]
  overlap_pairs_dt[, index := .I]
  overlap_pairs_dt[, ovr_pairs := list(list(c(xid, yid))), by = index]
  ovr_pairs_l <- overlap_pairs_dt[, ovr_pairs]
  ovr_pairs_l <- unique(rapply(ovr_pairs_l, sort, how = "list"))
  # combine/reduce pair list if any indice is overlapping ---
  repeat {
    initial_length <- length(ovr_pairs_l)
    tmp_pairs_l <- list()
    for (i in seq(ovr_pairs_l)) {
      for_inter <-
        unique(as.vector(unlist(sapply(ovr_pairs_l, function(x) {
          if (length(intersect(unlist(x), unlist(ovr_pairs_l[i]))) > 0) {
            result <- union(unlist(x), unlist(ovr_pairs_l[i]))
            return(result)
          } else {
            return(ovr_pairs_l[i])
          }
        })))) # end of fn and sapply
      tmp_pairs_l[[i]] <- sort(for_inter)
    } # end of repeat loop
    ovr_pairs_l <- unique(tmp_pairs_l)
    post_length <- length(ovr_pairs_l)
    if (post_length - initial_length == 0)
      break
  } # end of repeat
  d[, index := .I]

  messy_ovr_dt <- setkey(d, index)[unlist(ovr_pairs_l)]
  clean_dt <- setkey(d, index)[!unlist(ovr_pairs_l)]
  retain_cols <- setdiff(names(d),
                         c("start_date", "end_date", "date_value", "end_col"))
  messy_ovr_dt[is.na(end_date), end_date := analysis_date]
  # self join by overlap (too bad we cant add conditions here) ---
  # messy_ovr_dt[cmh_priority_dt, priority := i.priority, on = "team"]
  setkeyv(messy_ovr_dt, c(group_cols, "start_date", "end_date"))
  messy_ovr_dt <- foverlaps(
    messy_ovr_dt, messy_ovr_dt,
    by.x = c(group_cols, "start_date", "end_date"),
    by.y = c(group_cols, "start_date", "end_date"))
  # remove records that have 'lower' p_col and are completely 'within'
  messy_ovr_dt[, remove_record := ifelse(p_int > i.p_int &
                                           start_date > i.start_date & end_date < i.end_date, TRUE, FALSE)]
  messy_ovr_dt[start_date >= i.start_date & end_date <= i.end_date &
                 p_int > i.p_int, remove_record := TRUE]
  # keep non-duplicate + needed records
  messy_ovr_dt[, grp_id := .GRP, by = c(group_cols, "p_int")]
  messy_ovr_dt[, grp_n := .N, by = c(group_cols, "p_int")]
  messy_ovr_dt[grp_n > 1 & index == i.index, remove_record := TRUE]
  messy_ovr_dt[, Cc(grp_id, grp_n) := NULL]
  messy_ovr_dt <- messy_ovr_dt[remove_record == FALSE | is.na(remove_record)]
  messy_ovr_dt[, add_record := NA_character_]
  # higher priority does not affect lower priority
  messy_ovr_dt[p_int < i.p_int, add_record := "do not change"]
  # lower priority followed by overlapping higher priority
  messy_ovr_dt[p_int < i.p_int & start_date < i.start_date &
                 end_date >= i.start_date, add_record := "do not change"]
  # lower priority 'within' higher priority
  messy_ovr_dt[p_int > i.p_int & start_date < i.start_date &
                 i.end_date < end_date, add_record := "split record both sides"]
  # case 3: higher priority followed by overlapping lower
  messy_ovr_dt[p_int > i.p_int & start_date < i.start_date &
                 end_date <= i.end_date & i.start_date <= end_date,
               add_record := "shorten right side"]
  # case 4b: lower priority followed by overlapping higher priority
  messy_ovr_dt[p_int > i.p_int & start_date > i.start_date &
                 start_date <= i.end_date & i.end_date < end_date,
               add_record := "shorten left side"]
  # case 5: no overlap (shouldnt really show up)
  messy_ovr_dt[end_date < i.start_date, add_record := "no overlap"]
  # messy_ovr_dt[p_col < i.p_col & i.start_date < start_date &
  # end_date <= i.end_date, add_record := "add record left of p_col"]
  # messy_ovr_dt[p_col < i.p_col & start_date < i.end_date &
  # end_date > i.end_date, add_record := "add record left of p_col"]
  messy_ovr_dt[, new_index := .I]
  # cases in the middle of a split need to be discarded
  setkeyv(messy_ovr_dt, c(group_cols, "start_date", "end_date", "add_record"))
  rm_index <- messy_ovr_dt[messy_ovr_dt[add_record == "split record both sides",
                                        unique(.SD), .SDcols = c(group_cols, "start_date", "end_date")]][
                                          add_record == "do not change", new_index]
  messy_ovr_dt <- setkey(messy_ovr_dt, new_index)[!rm_index]
  # cases in the right side need to have the rule consistently applied
  setkeyv(messy_ovr_dt, c(group_cols, "start_date", "end_date", "add_record"))
  change_index <- messy_ovr_dt[messy_ovr_dt[add_record == "shorten right side",
                                            unique(.SD), .SDcols = c(group_cols, "start_date", "end_date")]][
                                              is.na(add_record), new_index]
  setkey(messy_ovr_dt, new_index)[change_index, add_record := "shorten right side"]
  rm(change_index)
  # cases in the left side need to have the rule consistently applied
  setkeyv(messy_ovr_dt, c(group_cols, "start_date", "end_date", "add_record"))
  change_index <- messy_ovr_dt[messy_ovr_dt[add_record == "shorten left side",
                                            unique(.SD), .SDcols = c(group_cols, "start_date", "end_date")]][
                                              is.na(add_record), new_index]
  setkey(messy_ovr_dt, new_index)[change_index, add_record := "shorten left side"]
  rm(change_index, rm_index)
  setkey(messy_ovr_dt, NULL)
  split_recs <- messy_ovr_dt[add_record == "split record both sides"]
  split_recs[, index := -index]
  messy_ovr_dt <- messy_ovr_dt[add_record %nin% "split record both sides"]
  # dealing with each split separately is the safe/right way to do this
  split_right <- copy(split_recs)[, `:=`(add_record = "split right")]
  split_right[, end_date := i.start_date - 1]

  if (nrow(split_right) > 0) {
    split_right[, end_date := min(end_date), by = index]
  }
  split_left <- copy(split_recs)[, `:=`(add_record = "split left")]
  if (nrow(split_left) > 0) {
    split_left[, start_date := i.end_date + 1]
    split_left[, start_date := max(start_date), by = index]
  }
  split_comb <- rbindlist(list(split_right, split_left), use.names = TRUE)
  split_comb[, c(grep(x = names(split_comb), pattern = "[.]", value = TRUE),
                 Cc(new_index, remove_record, add_record, index)) := NULL]
  # applying date fixes
  messy_ovr_dt[add_record == "shorten left side",
               start_date := i.end_date + 1]
  messy_ovr_dt[add_record == "shorten right side",
               end_date := i.start_date - 1]
  # records were separated via foverlaps; rejoining now ---
  messy_ovr_dt[,
               Cc(start_date, end_date) :=
                 list(max(start_date),
                      min(end_date)),
               by = c(group_cols, "p_int", "index")]

  messy_ovr_dt[, setdiff(names(messy_ovr_dt), names(split_comb)) := NULL]
  messy_ovr_dt <- unique(messy_ovr_dt)
  split_comb <- unique(split_comb)
  clean_dt[, setdiff(names(clean_dt), names(split_comb)) := NULL]
  fixed_dt <- rbindlist(list(messy_ovr_dt, split_comb, clean_dt), use.names = TRUE)
  fixed_dt[, end_col := NULL]
  setnames(fixed_dt, Cc(start_date, end_date, p_col, p_int),
           c(start_col, end_col, priority_col, priority_int))
  return(fixed_dt)
}
