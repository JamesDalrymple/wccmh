#' @title WCCMH admission functions
#' @description standardize admission data
#'
#' @param overlap_dt A data.table object.
#' @param group_cols A group of columns which will collectively make a key on
#' which to group by when reducing/collapsing the data.table object.
#' @param priority_col A single column which will have a priority assignment.
#' @param priority_value An integer column, where lower priorities override
#' higher priorities. May be numeric if coerceable to integer.
#' @param start_col The start date for record. Blanks not allowed.
#' @param end_col The end date for the record. Blanks will be replaced, see
#' parameter replace_blanks
#' @param overlap_int An integer, default value of 1, to find consecutive
#' records.
#' @param replace_blanks If end_col has missing values, they will be replaced
#' with this value. Defaults to Sys.Date().
#'
#' @return overlap_combine returns a reduced/collapsed data.table object based
#' on group_cols.
#' priority_overlap returns a data.table with fixed records based on priority
#' team assignment. May contain more rows than original dataset.
#'
#' @note overlap_combine is relatively fast/optimized, although there is a for
#' loop that could possibly be avoided via Reduce, not sure. adm_overlap is not
#' code-optimized yet.
#'
#' @examples
#' \dontrun{
#' # overlap_dt <- fread("C:/Users/dalrymplej/Documents/GitHub/wccmh/data/overlap_dt.csv")
#' # overlap_dt[, start_date := as.Date(start_date, format = 'm/%d/%Y' )]
#' # overlap_dt[, end_date := as.Date(end_date, format = "%m/%d/%Y")]
#' # overlap_dt[, priority := as.int(priority)]
#' # save(overlap_dt,
#' #  file = "C:/Users/dalrymplej/Documents/GitHub/wccmh/data/overlap_dt.rda")
#' # load("C:/Users/dalrymplej/Documents/GitHub/wccmh/data/overlap_dt.rda")
#' # data(overlap_dt)
#'
#' # how to fix if priorities are not to be accounted for...
#' test1 <- overlap_combine(overlap_dt = overlap_dt, group_cols = c("case_no",
#' "team"), start_col = "start_date", end_col = "end_date",
#'  overlap_int = 1L, replace_blanks = Sys.Date() + 1e3)
#'
#'  # how to fix if priorities are to be accounted for...
#' test2 <- priority_overlap(overlap_dt = copy(overlap_dt),
#'                  group_cols = "person_ID",
#'                  priority_col = "team",
#'                  priority_value = "priority",
#'                  start_col = "start_date",
#'                  end_col = "end_date",
#'                  overlap_int = 1L,
#'                  replace_blanks = Sys.Date())
#'
#'
#'  }
#' @importFrom data.table data.table := rbindlist copy setnames setorderv dcast shift melt between setkeyv foverlaps .N .GRP like
#' @importFrom Hmisc Cs
#' @importFrom EquaPac p_warn
#' @name overlap_functions
NULL

# R CMD checker appeasement ---
.SD <- .SDcols <- team <- date_value <- priority <- index <- i.index <-
  i.start_date <- i.end_col <- start_date <- end_date <- ovr_vec <- xid <-
  yid <- i.priority <- ovr_pairs <- i.end_date <- i.team <- remove_record <-
  p_integer <- i.p_integer <- grp_id <- .GRP <- grp_n <- add_record <-
  new_index <- p_col <- NULL

# general overlap date fixing -------------------------------------------------
#' @export
#' @rdname overlap_functions
overlap_combine <-
  function(overlap_dt, group_cols, start_col, end_col, overlap_int = 1L,
           replace_blanks = Sys.Date()) {
    # overlap_dt = modify$cmh_core[case_no == 10450]
    # options(warn=2)
    # overlap_dt = copy(modify$cmh_core[case_no == 11660])
    # overlap_dt = copy(modify$cmh_core[case_no == 10563])
    # overlap_dt = copy(modify$cmh_core[case_no == 11091])
    # overlap_dt = copy(modify$cmh_core[case_no == 220766])
    setorderv(overlap_dt, c(group_cols, start_col))
    if (any(names(overlap_dt) == "end_col")) {
      overlap_dt[, end_col := NULL]
      p_warn("You had a column labeled end_col which conflicts with
             overlap_comb. It was deleted and re-created based on the end_col
             parameter.")
    }
    overlap_dt[, end_col := get(end_col) + overlap_int]
    sd_cols <- c(start_col, "end_col")
    overlap_dt[is.na(end_col), end_col := replace_blanks]
    # note: if end_col becomes < start_col due to overlap_int,
    # we assign end_col <- start_col
    overlap_dt[end_col - get(start_col) < 0, end_col := start_col]
    overlap_dt[, index := .I]
    setnames(overlap_dt, start_col, "start_date")
    setnames(overlap_dt, end_col, "end_date")
    # finding overlapping combinations via vectors of indices ---
    c_overlap <-
      overlap_dt[overlap_dt[, unique(.SD), .SDcols =
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
        setkey(overlap_dt, index)[ovr_red_l[[i]],
                                  c("start_date", "end_date", "end_col") :=
                                    list(min(start_date), max(end_date), max(end_col))]
      }
    }
    overlap_dt[, index := NULL]
    overlap_dt <- unique(overlap_dt)
    return(overlap_dt)
  }


    # figure out which intervals are overlapping with different team priorities
    # overlap_dt2 <- copy(overlap_dt)
    # overlap_dt <- copy(overlap_dt2)

# priority column with overlapping date records -------------------------------
#' @export
#' @rdname overlap_functions
priority_overlap <- function(overlap_dt,
                             group_cols,
                             priority_col,
                             priority_value,
                             start_col,
                             end_col,
                             overlap_int = 1L,
                             replace_blanks = Sys.Date()+999) {
  # overlap_dt = copy(overlap_dt)
  # group_cols = Cs(case_no, cmh_effdt)
  # priority_col = "cmh_team"
  # priority_value = "priority"
  # start_col = "team_effdt"
  # end_col = "team_expdt"

  # fix 'easier' issues first with simple min/max
  overlap_dt <- overlap_combine(
    overlap_dt = overlap_dt,
    group_cols = c(group_cols, priority_col),
    start_col = start_col,
    end_col = end_col,
    overlap_int = overlap_int,
    replace_blanks = replace_blanks
  )
  group_cols <- setdiff(group_cols, priority_col)
  setnames(overlap_dt, priority_col, "p_col")
  setnames(overlap_dt, priority_value, "p_integer")
  overlap_dt[, p_integer := as.int(p_integer)]
  stopifnot(overlap_dt[, class(p_integer)] == "integer")
  overlap_dt[!is.na(end_date), end_col := end_date]
  setkeyv(overlap_dt, c(group_cols, "start_date", "end_col"))
  overlap_pairs_dt <-
    foverlaps(
      overlap_dt[, .SD, .SDcols = c(group_cols, Cs(start_date, end_col))],
      overlap_dt[, .SD, .SDcols = c(group_cols, Cs(start_date, end_col))],
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
  } # end of while

  overlap_dt[, index := .I]
  messy_ovr_dt <- setkey(overlap_dt, index)[unlist(ovr_pairs_l)]
  clean_dt <- setkey(overlap_dt, index)[!unlist(ovr_pairs_l)]
  retain_cols <- setdiff(names(overlap_dt),
    c("start_date", "end_date", "date_value", "end_col"))
  messy_ovr_dt[is.na(end_date), end_date := replace_blanks]
  # self join by overlap (too bad we cant add conditions here) ---
  # messy_ovr_dt[cmh_priority_dt, priority := i.priority, on = "team"]
  setkeyv(messy_ovr_dt, c(group_cols, "start_date", "end_date"))
  messy_ovr_dt <- foverlaps(
    messy_ovr_dt, messy_ovr_dt,
    by.x = c(group_cols, "start_date", "end_date"),
    by.y = c(group_cols, "start_date", "end_date"))
  # remove records that have 'lower' p_integer and are completely 'within'
  messy_ovr_dt[, remove_record := ifelse(p_integer > i.p_integer &
   start_date > i.start_date & end_date < i.end_date, TRUE, FALSE)]
  messy_ovr_dt[start_date >= i.start_date & end_date <= i.end_date &
    p_integer > i.p_integer, remove_record := TRUE]
  # keep non-duplicate + needed records
  messy_ovr_dt[, grp_id := .GRP, by = c(group_cols, "p_col")]
  messy_ovr_dt[, grp_n := .N, by = c(group_cols, "p_col")]
  messy_ovr_dt[grp_n > 1 & index == i.index, remove_record := TRUE]
  messy_ovr_dt[, Cs(grp_id, grp_n) := NULL]
  messy_ovr_dt <- messy_ovr_dt[remove_record == FALSE | is.na(remove_record)]

  messy_ovr_dt[, add_record := NA_character_]
  # higher priority does not affect lower priority
  messy_ovr_dt[p_integer < i.p_integer, add_record := "do not change"]
  # lower priority followed by overlapping higher priority
  messy_ovr_dt[p_integer < i.p_integer & start_date < i.start_date &
                 end_date >= i.start_date, add_record := "do not change"]
  # lower priority 'within' higher priority
  messy_ovr_dt[p_integer > i.p_integer & start_date < i.start_date &
               i.end_date < end_date, add_record := "split record both sides"]
  # case 3: higher priority followed by overlapping lower
  messy_ovr_dt[p_integer > i.p_integer & start_date < i.start_date &
    end_date <= i.end_date & i.start_date <= end_date,
    add_record := "shorten right side"]
  # case 4b: lower priority followed by overlapping higher priority
  messy_ovr_dt[p_integer > i.p_integer & start_date > i.start_date &
    start_date <= i.end_date & i.end_date < end_date,
    add_record := "shorten left side"]
  # case 5: no overlap (shouldnt really show up)
  messy_ovr_dt[end_date < i.start_date, add_record := "no overlap"]
  # messy_ovr_dt[p_integer < i.p_integer & i.start_date < start_date &
    # end_date <= i.end_date, add_record := "add record left of p_col"]
  # messy_ovr_dt[p_integer < i.p_integer & start_date < i.end_date &
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
  messy_ovr_dt <- rbindlist(list(messy_ovr_dt,
                 copy(split_recs[, add_record := "shorten left side"]),
                 copy(split_recs[, add_record := "shorten right side"])
  ))
  messy_ovr_dt[add_record == "shorten left side",
    start_date := i.end_date + 1]
  messy_ovr_dt[add_record == "shorten right side",
               end_date := i.start_date - 1]
  # records were separated via foverlaps; rejoining now ---

  messy_ovr_dt[index > 0, # avoiding combing split records
               Cs(start_date, end_date) :=
               list(max(start_date),
                    min(end_date)),
               by = c(group_cols, "p_col", "index")]
  # AS IS, FLAWED! James 3/31/2016 6:03 PM ---
  # messy_ovr_dt[like(add_record, "shorten left side"),
  #             start_date := max(start_date), by = c(group_cols, "p_col")]
  #messy_ovr_dt[like(add_record, "shorten right side"),
  #             end_date := min(end_date), by = c(group_cols, "p_col")]
  messy2 <- messy_ovr_dt[, unique(.SD),
    .SDcols = c(group_cols, Cs(p_col, start_date,
    end_date, p_integer, end_col, index, add_record))]
  setorderv(messy2, c(group_cols, "start_date", "end_date"))
  messy2[, add_record := NULL]
  fixed_dt <- rbindlist(list(clean_dt, messy2), use.names = TRUE)
  fixed_dt[, Cs(end_col, index) := NULL]
  setnames(fixed_dt, "p_col", priority_col)
  setnames(fixed_dt, "p_integer", priority_value)
  setkeyv(fixed_dt, c(group_cols, "start_date", "end_date"))
  setnames(fixed_dt, "start_date", start_col)
  setnames(fixed_dt, "end_date", end_col)
  setkey(fixed_dt, NULL)
  fixed_dt <- unique(fixed_dt)
  return(fixed_dt)
}
