#' getDataCatalog API
#'
#' Get information about the statistical dataset files and databases via e-Stat API.
#'
#' @param appId Application ID
#' @param use_label Whether to take the human-redable label value or the code value when flattening a field containing both.
#'        (default: \code{TRUE})
#' @param ... Other parameters.
#' @seealso
#' \url{http://www.e-stat.go.jp/api/e-stat-manual/#api_2_6}
#' \url{http://www.e-stat.go.jp/api/e-stat-manual/#api_3_7}
#'
#' @section Other parameters:
#' For every detailed information, please visit the URL in See Also.
#' \itemize{
#'  \item \code{surveyYears}:
#'    Year and month when the survey was conducted. The format is either \code{YYYY}, \code{YYYYMM}, or \code{YYYYMM-YYYYMM}
#'  \item \code{openYears}:
#'    Year and month when the survey result was opened. The format is the same as \code{surveyYears}
#'  \item \code{statsField}:
#'    Field of statistics. The format is either two digits (large classification) or
#'    four digits (small classification). For the detail of the classification, see
#'    \url{http://www.soumu.go.jp/toukei_toukatsu/index/seido/sangyo/26index.htm}
#'  \item \code{statsCode}:
#'     Code assigned for each statistical agency and statistics. The format can be
#'     five digits (agency), and eight digits (statistics). For the detail, see
#'     \url{http://www.stat.go.jp/info/guide/public/code/code.htm}.
#'  \item \code{searchWord}:
#'     Keyword for searching. You can use \code{OR} and \code{AND}. (e.g.: \code{apple AND orrange}).
#'  \item \code{dataType}:
#'     Type of data. \code{XLS}: Excel file, \code{CSV}: CSV file, \code{PDF}: PDF file, \code{DB}: Database.
#'  \item \code{catalogId}:
#'     Catalog ID.
#'  \item \code{resourceId}:
#'     Catalog resource ID.
#'  \item \code{startPosition}:
#'    integer. The the first record to get.
#'  \item \code{limit}:
#'    integer. Max number of records to get.
#'  \item \code{updatedDate}:
#'    Last updated date. The format is either \code{YYYY}, \code{YYYYMM}, \code{YYYYMMDD}, \code{YYYYMMDD-YYYYMMDD}
#' }
#' @examples
#' \dontrun{
#' estat_getDataCatalog(
#'   appId = "XXXX",
#'   searchWord = "CD",
#'   dataType = "CSV",
#'   limit = 3
#' )
#' }
#' @export
estat_getDataCatalog <- function(appId, use_label = TRUE, ...) {
  j <- estat_api("rest/2.0/app/json/getDataCatalog", appId = appId, ...)

  j$GET_DATA_CATALOG$DATA_CATALOG_LIST_INF$DATA_CATALOG_INF %>%
    purrr::map(denormalize_data_catalog_inf, use_label = use_label) %>%
    dplyr::bind_rows()
}

denormalize_data_catalog_inf <- function(inf, use_label = TRUE) {
  # Columns which needs special treatments:
  #   - STAT_NAME and ORGANIZATION have different nested level
  #   - other columns will conflict between DATASET and RESOURCE
  special_columns <- c("DESCRIPTION", "LAST_MODIFIED_DATE", "RELEASE_DATE")

  DATASET <- inf$DATASET
  RESOURCE <- inf$RESOURCES$RESOURCE

  dataset_inf <- purrr::discard(DATASET,
                                names(DATASET) %in% special_columns) %>%
    as_flattened_character(use_label = use_label) %>%
    purrr::update_list(
      `DATASET_@id`        = inf$`@id`,
      DATASET_DESCRIPTION  = DATASET$DESCRIPTION,
      DATASET_LAST_MODIFIED_DATE = DATASET$LAST_MODIFIED_DATE,
      DATASET_RELEASE_DATE = DATASET$RELEASE_DATE
    )

  # inf$DATASET$TITLE$NAME conflicts with inf$RESOURCES$RESOURCE[[x]]$TITLE$NAME
  names(dataset_inf) <- replace(names(dataset_inf), names(dataset_inf) == "NAME", "DATASET_NAME")

  # RESOURCE may be a list or a list of lists
  resources_inf <- if(is.character(RESOURCE[[1]])) {
    RESOURCE %>%
      as_flattened_character(use_label = use_label) %>%
      dplyr::as_data_frame()
  } else {
    RESOURCE %>%
      purrr::map(as_flattened_character, use_label = use_label) %>%
      dplyr::bind_rows()
  }

  purrr::invoke(dplyr::mutate, .data = resources_inf, dataset_inf)
}
