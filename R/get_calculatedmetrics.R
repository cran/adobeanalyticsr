#' Get a list of calculated metrics.
#'
#' Retrieve a list of available calculated metrics. The results will always include these default items:
#' `id`, `name`, `description`, `rsid`, `owner`, `polarity`, `precision`, `type`. Other attributes can
#' be optionally requested through the `expansion` field.
#'
#' @details
#' This function is useful/needed to identify the specific ID of a calculated metric for use in other
#' functions like `aw_freeform_report`.
#'
#' The `expansion` argument accepts the following values, which will then include additional columns
#' in the results:
#'
#' * **ownerFullName**: adds `owner.name` and `owner.login` columns to the results (`owner.id` is
#' already included by default).
#'
#' * **modified**: adds a `modified` column to the output with the date (ISO 8601 format) each
#' calculated metric was last modified.
#'
#' * **definition**: adds _multiple_ columns (the number will vary based on the number and complexity
#' of calculated metrics returns) that provide the actual formula for each of the calculated metrics.
#' This is returned from the API as a JSON object and converted into columns by the function, which
#' means it is pretty messy, so, really, it's not recommended that you use this value.
#'
#' * **compatability**: should add a column with the products that the metric is compatible with, but this
#' behavior has not actually been shown to be true, so this may actually do nothing if included.
#'
#' * **reportSuiteName**: adds a `reportSuiteName` and a `siteTitle` column with the friendly report
#' suite name for the RSID.
#'
#' * **tags**: adds a column with an embedded data frame with all of the existing tags that are
#' associated with the calculated metric. This can be a bit messy to work with, but the information
#' is, at least, there.
#'
#' Multiple values for `expansion` can be included in the argument as a vector. For instance,
#' `expansion = c("tags", "modified")` will add both a `tags` column and a `modified` column to the output.
#'
#' @seealso \code{\link{aw_get_metrics}}
#'
#' @param company_id Company ID. If an environment variable called `AW_COMPANY_ID` exists in `.Renviron` or
#' elsewhere and no `company_id` argument is provided, then the `AW_COMPANY_ID` value will be used.
#' Use \code{\link{get_me}} to get a list of available `company_id` values.
#' @param rsids Filter the list to only include calculated metrics tied to a specified RSID or
#' list of RSIDs. Specify multiple RSIDs as a vector (i.e., "`rsids = c("rsid_1", rsid_2",...rsid_n")`").
#' Use \code{\link{aw_get_reportsuites}} to get a list of available `rsid` values.
#' @param ownerId Filter the list to only include calculated metrics owned by the specified loginId.
#' @param filterByIds Filter the list to only include calculated metrics in the specified list as
#' specified by a single string or as a vector of strings.
#' @param toBeUsedInRsid The report suite where the calculated metric is intended to be used. This
#' report suite is used to determine things like compatibility and permissions. If it is not specified,
#' then the permissions will be calculated based on the union of all metrics authorized in all groups
#' the user belongs to. If **compatibility** is specified for `expansion`, and `toBeUsedInRsid` is not,
#' then the compatibility returned is based off of the compatibility from the last time the calculated
#' metric was saved.
#' @param locale The locale that system-named metrics should be returned in. Non-localized values will
#' be returned for title, name, description, etc. if a localized value is not available.
#' @param name Filter the list to only include calculated metrics that contain the specified **name**.
#' This is case-insensitive and is a simple, single string match.
#' @param tagNames Filter the list to only include calculated metrics that contain one of the tags as specified by
#' a single string or vector of strings.
#' @param favorite Set to `TRUE` to only include calculated metrics that are favorites in the results. A
#' value of `FALSE` will return all calculated metrics, including those that are favorites.
#' @param approved Set to `TRUE` to only include calculated metrics that are approved in the results. A
#' value of `FALSE` will return all calculated metrics, including those that are approved and those that are not.
#' @param limit The number of results to return per page. The default is 1,000.
#' @param page The "page" of results to display. This works in conjunction with the `limit` argument and is
#' zero-based. For instance, if `limit = 10` and `page = 1`, the results returned would be 11 through 20.
#' @param sortDirection The sort direction for the results: `ASC` (default) for ascending or `DESC` for
#' descending. (This is case insensitive, so `asc` and `desc` work as well.)
#' @param sortProperty The property to sort the results by. Currently available values are `id` (default), `name`,
#' and `modified_date`. Note that setting `expansion = modified` returns results with a column added called
#' `modified`, which is the last date the calculated metric was modified. When using this value for `sortProperty`,
#' though, the name of the argument is `modified_date`, because why would we expect locked-in consistency
#' from Adobe?
#' @param expansion Additional calculated metric metadata fields to include in the results:
#' `reportSuiteName`, `ownerFullName`, `modified`, `tags`, `definition`, `compatability`, `categories`.
#' See **Details** for more information about the quirks of this argument.
#' @param includeType Include additional calculated metrics not owned by user. Available values are `all` (default),
#' `shared`, and `templates`. The `all` option takes precedence over "shared"
#' @param debug Include the output and input of the api call in the console for debugging. Default is FALSE
#'
#' @return A data frame of calculated metrics and their metadata.
#'
#' @export
#'
aw_get_calculatedmetrics <- function(company_id = Sys.getenv("AW_COMPANY_ID"),
                                     rsids = NULL,
                                     ownerId = NULL,
                                     filterByIds = NULL,
                                     toBeUsedInRsid = NULL,
                                     locale = "en_US",
                                     name = NULL,
                                     tagNames = NULL,
                                     favorite = NULL,
                                     approved = NULL,
                                     limit = 1000,
                                     page = 0,
                                     sortDirection = 'DESC',
                                     sortProperty = NULL,
                                     expansion = NULL,
                                     includeType = 'all',
                                     debug = FALSE)
{
  # Reference: https://github.com/AdobeDocs/analytics-2.0-apis/blob/master/calculatedmetrics.md
  assertthat::assert_that(length(name) < 2, msg = "'name' is a search string and may not have length > 1\nUse 'filterByIds' to request specific segments")

  # if ownerId value is supplied change includeType to NULL so that the filter will be recognized by the API
 if(!is.null(ownerId)) {
   includeType = NULL
 }

  query_param <- list(
    rsids = rsids,
    ownerId = ownerId,
    filterByIds = filterByIds,
    toBeUsedInRsid = toBeUsedInRsid,
    locale = locale,
    name = name,
    tagNames = tagNames,
    favorite = favorite,
    approved = approved,
    limit = limit,
    page = page,
    sortDirection = sortDirection,
    sortProperty = sortProperty,
    expansion = expansion,
    includeType = includeType
  )

  urlstructure <- paste('calculatedmetrics', format_URL_parameters(query_param), sep = "?")

  res <- aw_call_api(req_path = urlstructure[1], debug = debug, company_id = company_id)

  jsonlite::fromJSON(res)$content
}

