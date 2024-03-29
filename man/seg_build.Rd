% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/segment_build.R
\name{seg_build}
\alias{seg_build}
\title{Build the Segment in Adobe Analytics}
\usage{
seg_build(
  name = NULL,
  description = NULL,
  containers = NULL,
  rules = NULL,
  sequences = NULL,
  context = "hits",
  conjunction = "and",
  sequence = "in_order",
  sequence_context = "hits",
  exclude = FALSE,
  create_seg = FALSE,
  tagNames = NULL,
  internal = FALSE,
  debug = FALSE,
  rsid = Sys.getenv("AW_REPORTSUITE_ID"),
  company_id = Sys.getenv("AW_COMPANY_ID")
)
}
\arguments{
\item{name}{This is the name of the new segment (required)}

\item{description}{This is the description of the segment (required)}

\item{containers}{List of the container(s) that make up the segment. Containers
are list objects created using the \code{\link[=seg_con]{seg_con()}} function.}

\item{rules}{List of the rule(s) to create a segment. Rules are list objects
created using the \code{\link[=seg_rule]{seg_rule()}} function.}

\item{sequences}{List of the rule(s) and sequence container(s) that are combined
to make a segment. Sequence containers are list objects created using the \code{\link[=seg_seq]{seg_seq()}} function.}

\item{context}{Defines the level that the segment logic should operate on.
Valid values are visitors, visits, and hits. See Details}

\item{conjunction}{This will tell how the different containers and rules should
be compared. Use either 'and' or 'or'.}

\item{sequence}{Used to define if the segment should be 'in_order' (default),
'after', or 'before' the sequence of events}

\item{sequence_context}{Used to define the sequential items context which should
be below the container context. ex. if container context is visitors then the
sequence_context should be visits or hits}

\item{exclude}{Excludes the main container which will include all rules.
Only used when the rule arguments are used.}

\item{create_seg}{Used to determine if the segment should be created in the
report suite or if the definition should be returned to be used in a freeform
table API call. Default is FALSE}

\item{tagNames}{Apply tag names to the newly created calculated metric. Single
string or a vector.}

\item{internal}{Determines if this segment is to be available in the UI.
Default is FALSE, meaning the segment will not be available in the UI, nor will
the ID be available in the \code{aw_get_segments} function call.}

\item{debug}{This enables the api call information to show in the console for
help with debugging issues. default is FALSE}

\item{rsid}{Adobe report suite ID (RSID).  If an environment variable called
\code{AW_REPORTSUITE_ID} exists in \code{.Renviron} or elsewhere and no \code{rsid} argument
is provided, then the \code{AW_REPORTSUITE_ID} value will be used. Use \code{\link[=aw_get_reportsuites]{aw_get_reportsuites()}}
to get a list of available \code{rsid} values.}

\item{company_id}{Company ID. If an environment variable called \code{AW_COMPANY_ID}
exists in \code{.Renviron} or elsewhere and no \code{company_id} argument is provided,
then the \code{AW_COMPANY_ID} value will be used. Use \code{\link[=get_me]{get_me()}} to get a list of
available \code{company_id} values.}
}
\value{
If the "create_seg" argument is set to FALSE a JSON string definition
will be returned. If the "create_seg" argument is set to TRUE and the segment
is valid it will return a data frame of the newly created segment id along
with some other basic meta data. If it returns an error then the error
response will be returned to help understand what needs to be corrected.
}
\description{
This function combines rules, containers and/or sequences into a single JSON
string and can then make the post call to create the segment in Adobe Analytics
or return the json string for use in other api calls or for validation.
}
\details{
\strong{Context}

The rules in a segment have a context that specify the level of operation.
The context can be "visitors", "visits" or "hits."
As an example, let's build a segment rule where revenue is greater than 0
(meaning a purchase took place) and change the context to see how things change.
If the context is set to "visitors", the segment includes all hits from visitors
that have a purchase of some kind during a visit. This is useful in analyzing
customer behavior in visits leading up to a purchase and possibly behavior after a purchase.
If the context is set to "visits", the segment includes all hits from visits where
a purchase occurred. This is useful for seeing the behavior of a visitor in
immediate page views leading up to the purchase.
If the context is set to "hits", the segment only includes hits where a purchase
occurred, and no other hits. This is useful in seeing which products were most
popular.
In the above example, the context for the container listed is hits. This means
that the container only evaluates data at the hit level, (in contrast to visit
or visitor level). The rows in the container are also at the hit level.
}
