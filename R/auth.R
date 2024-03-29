# General auth -------------------------------------------------

#' Generate an Access Token for the Adobe Analytics v2.0 API
#'
#' **Note:** `aw_auth()` is the primary function used for authorization. `auth_oauth()`
#' and `auth_jwt()` should typically not be called directly.
#'
#' @param type Either 'jwt' or 'oauth'. This can be set explicitly, but a best practice is
#' to run `aw_auth_with()` to set the authorization type as an environment variable before
#' running `aw_auth()`
#' @param ... Additional arguments passed to auth functions.
#' @param client_id The client ID, defined by a global variable or manually defined
#' @param client_secret The client secret, defined by a global variable or manually defined
#' @param file A JSON file containing service account credentials required for JWT
#' authentication. This file can be downloaded directly from the Adobe Console,
#' and should minimally have the fields `API_KEY`, `CLIENT_SECRET`, `ORG_ID`,
#' and `TECHNICAL_ACCOUNT_ID`.
#' @param private_key Filename of the private key for JWT authentication.
#' @param jwt_token _(Optional)_ A custom, encoded, signed JWT claim. If used,
#'   `client_id` and `client_secret` are still required.
#' @param use_oob if `FALSE`, use a local webserver for the OAuth dance.
#'   Otherwise, provide a URL to the user and prompt for a validation code.
#'   Defaults to the value of the `httr_oob_default` default, or TRUE if
#'   `httpuv` is not installed.
#'
#' @seealso [aw_auth_with()]
#'
#' @return The path of the cached token. This is returned invisibly.
#' @family auth
#' @aliases aw_auth auth_jwt auth_oauth
#' @export
aw_auth <- function(type = aw_auth_with(), ...) {

  if (is.null(type)) {
    stop("Authentication type missing, please set an auth type with `aw_auth_with`")
  }
  type <- match.arg(type, c("jwt", "oauth"))

  switch(type,
         jwt = auth_jwt(...),
         oauth = auth_oauth(...)
  )
}

#' Set authorization options
#'
#' @description
#' **Get** or **set** various authorization options. If called without an argument, then
#' these functions return the current setting for the requested option (which can be
#' `NULL` if the option has not been set). To clear the setting, pass `NULL` as an
#' argument.
#'
#' `aw_auth_with` sets the type of authorization for the session. This is used
#' as the default by `aw_auth()` when no specific option is given.
#'
#' @param type The authorization type: 'oauth' or 'jwt'
#' @param path The location for the cached authorization token. It should be a
#' directory, rather than a filename. If this option is not set, the current
#' working directory is used instead. If the location does not exist, it will
#' be created the first time a token is cached.
#' @param name The filename, such as `aw_auth.rds` for the cached authorization
#' token file. The file is stored as an RDS file, but there is no requirement
#' for the `.rds` file extension. `.rds` is not appended automatically.
#'
#' @seealso [aw_auth()]
#' @return The option value, invisibly
#' @family options
#' @rdname aw_auth_with
#' @aliases aw_auth_with aw_auth_path aw_auth_name
#' @export
aw_auth_with <- function(type) {
    if (missing(type)) return(getOption("adobeanalyticsr.auth_type"))

    if (!is.null(type)) {
        type <- match.arg(type, c("oauth", "jwt"))
    }

    options(adobeanalyticsr.auth_type = type)
    invisible(type)
}

#' @description
#' `aw_auth_path` sets the file path for the cached authorization token. It
#' should be a directory, rather than a filename. If this option is not set, the
#' current working directory is used instead.
#'
#' @rdname aw_auth_with
#' @family options
#' @export
aw_auth_path <- function(path) {
    if (missing(path)) return(getOption("adobeanalyticsr.auth_path"))
    options(adobeanalyticsr.auth_path = path)
    invisible(path)
}

#' @description
#' `aw_auth_name` sets the file name for the cached authorization token. If this
#' option is not set, the default filename is `aw_auth.rds`
#'
#' @rdname aw_auth_with
#' @family options
#' @export
aw_auth_name <- function(name) {
    if (missing(name)) return(getOption("adobeanalyticsr.auth_name"))
    options(adobeanalyticsr.auth_name = name)
    invisible(name)
}

#' Retrieve a token
#'
#' Updates (if necessary) and returns a session token. This function first checks
#' for a session token, then for a cached token, and, finally, generates a
#' new token. The default type may be set for the session with `aw_auth_with()`.
#'
#' @param ... Further arguments passed to auth functions
#'
#' @importFrom rlang %||%
#' @keywords internal
#' @return A token object of type `response` (JWT) or `Token2.0` (OAuth)
retrieve_aw_token <- function(...) {
    # Check session token
    token <- .adobeanalytics$token
    type <- token_type(token) %||% aw_auth_with()

    if (!is.null(token) & !is.null(type)) {
        if (type != token_type(token)) {
            stop("Token type mismatch, malformed session token/type relationship")
        }
    }

    # Session token > cached token > generating new token
    if (is.null(token)) {
        path <- token_path(getOption("adobeanalyticsr.auth_name", "aw_auth.rds"))
        cached_token_exists <- file.exists(path)

        if (cached_token_exists && type == "oauth") {
            message(paste("Retrieving cached token:", path))
            token <- readRDS(path)
            type <- token_type(token)

            .adobeanalytics$token <- token
        } else {
            message("No session token or cached token -- generating new token")
            aw_auth(type = aw_auth_with(), ...)
            token <- .adobeanalytics$token
            type <- aw_auth_with()
        }
    }

    # Check expiration
    if(type == 'jwt'){
        if (!token$validate()) {
        # This might be the wrong thing to do with OAuth, but it's the right
        # thing to do for JWT
        .adobeanalytics$token$refresh()
        }
    }

    return(.adobeanalytics$token)
}


#' Standard location for token caching
#'
#' The default path for the token is the current working directory, but
#' the option `adobeanalyticsr.auth_path` overrides this behavior.
#'
#' @param ... Passed to file.path, usually a filename
#'
#' @return File path
#' @noRd
token_path <- function(...) {
    loc <- getOption("adobeanalyticsr.auth_path", getwd())
    file.path(loc, ...)
}

#' Get type of token
#'
#' In the future, this could become a custom object, but for now there
#' are too many differences between the token types, so I just check for
#' each class.
#'
#' @param token An `httr` `reponse` object or `oauth2.0_token` object
#'
#' @return Either 'oauth' or 'jwt'
#'
#' @noRd
token_type <- function(token) {
    if (inherits(token, "Token2.0")) {
        "oauth"
    } else if (inherits(token, "AdobeJwtToken")) {
        "jwt"
    } else if (is.null(token)) {
        NULL
    } else {
        stop("Unknown token type")
    }
}


#' Get token configuration for requests
#'
#' Returns a configuration for `httr::GET` for the correct token type.
#'
#' @param client_id Client ID
#' @param client_secret Client secret
#'
#' @return Config objects that can be passed to `httr::GET` or similar
#' functions (e.g. `httr::RETRY`)
#'
#' @noRd
get_token_config <- function(client_id,
                             client_secret) {
    token <- retrieve_aw_token(client_id,
                               client_secret)
    type <- token_type(token)

    switch(type,
        oauth = httr::config(token = token),
        jwt = httr::add_headers(Authorization = paste("Bearer", content(token$token)$access_token)),
        stop("Unknown token type")
    )
}



#' Get user's credentials
#'
#' The order of precedence is:
#'
#' 1. Variables set by auth functions
#' 2. If auth functions haven't been called, use environment variables
#' 3. If environment variables are empty, throw an error
#'
#' @return List of length two with elements `client_id` and `client_secret`
#' @noRd
get_env_vars <- function() {
    client_id <- .adobeanalytics$client_id
    client_secret <- .adobeanalytics$client_secret

    if (is.null(client_id) | is.null(client_secret)) {
        client_id <- Sys.getenv("AW_CLIENT_ID")
        client_secret <- Sys.getenv("AW_CLIENT_SECRET")
    }

    if (client_id == "" | client_secret == "") {
        env_vars <- c(AW_CLIENT_ID = client_id,
                      AW_CLIENT_SECRET = client_secret)

        missing_envs <- names(env_vars[env_vars == ""])

        stop("Cannot automatically authenticate due to missing environment variables: ", paste(missing_envs, collapse = ", "),
             call. = FALSE)
    }

    list(
        client_id = client_id,
        client_secret = client_secret
    )
}



# JWT ------------------------------------------------------------------

#' @family auth
#' @describeIn aw_auth Authenticate with JWT token
#' @export
auth_jwt <- function(file = Sys.getenv("AW_AUTH_FILE"),
                     private_key = Sys.getenv("AW_PRIVATE_KEY"),
                     jwt_token = NULL,
                     ...) {
  if (file == "") {
    if (Sys.getenv("AW_TECHNICAL_ID") != "" | Sys.getenv("AW_ORGANIZATION_ID") != "") {
      stop("Using separate environment variables for JWT auth is deprecated.\nUse file-based authentication instead. See `?aw_auth`.")
    }
    stop("Variable 'AW_AUTH_FILE' not found but required for default JWT authentication.\nSee `?aw_auth`")
  }

  secrets <- jsonlite::fromJSON(file)

  resp <- auth_jwt_gen(secrets = secrets, private_key = private_key, jwt_token = jwt_token)


  # If successful
  message("Successfully authenticated with JWT: access token valid until ",
          resp$date + httr::content(resp)$expires_in / 1000)

  .adobeanalytics$token <- AdobeJwtToken$new(resp, secrets)
  .adobeanalytics$client_id <- secrets$API_KEY
  .adobeanalytics$client_secret <- secrets$CLIENT_SECRET
}


#' Generate the authorization response object
#'
#' @param secrets List of secret values, see `auth_jwt`
#' @param private_key Filename of the private key file
#' @param jwt_token Optional, a JWT token (e.g., a cached token)
#'
#' @noRd
auth_jwt_gen <- function(secrets,
                         private_key,
                         jwt_token = NULL) {
    # Look for missing elements of secrets
    required_but_missing <- setdiff(c("API_KEY", 
                                      "CLIENT_SECRET", 
                                      "ORG_ID",
                                      "TECHNICAL_ACCOUNT_ID"),
                                    names(secrets))

    if (length(required_but_missing) != 0) {
        stop("Did not find required variables in auth file: ", 
             paste(required_but_missing, collapse = ", "))
    }

    stopifnot(is.character(secrets$API_KEY))
    stopifnot(is.character(secrets$CLIENT_SECRET))
    stopifnot(is.character(secrets$ORG_ID))
    stopifnot(is.character(secrets$TECHNICAL_ACCOUNT_ID))

    if (any(c(secrets$API_KEY, secrets$CLIENT_SECRET) == "")) {
        stop("Client ID or Client Secret not found.")
    }

    private_key <- openssl::read_key(file = private_key)


    jwt_token <- get_jwt_token(jwt_token = jwt_token,
                               client_id = secrets$API_KEY,
                               private_key = private_key,
                               org_id = secrets$ORG_ID,
                               tech_id = secrets$TECHNICAL_ACCOUNT_ID)


    token <- httr::POST(url="https://ims-na1.adobelogin.com/ims/exchange/jwt",
                        body = list(
                            client_id = secrets$API_KEY,
                            client_secret = secrets$CLIENT_SECRET,
                            jwt_token = jwt_token
                        ),
                        encode = 'form')

    httr::stop_for_status(token)
    token
}


#' Get an encoded, signed JWT token
#'
#' Gets a JWT token
#'
#' @param jwt_token Optional, a JWT token
#' @param client_id Client ID
#' @param private_key File path to private key for token signature
#' @param org_id Organization ID from integration console
#' @param tech_id Technical account ID from integration console
#'
#' @return A JWT token generated by [jose::jwt_encode_sig()]
#' @noRd
get_jwt_token <- function(jwt_token = NULL,
                          client_id,
                          private_key,
                          org_id,
                          tech_id) {
    if (is.null(jwt_token)) {
        if (any(c(org_id, tech_id, private_key) == "")) {
            stop("Missing one of org_id, tech_id, or private_key")
        }

        if (!(inherits(private_key, "key") || file.exists(private_key))) {
            stop("Invalid private key. Is private key a file or the result of `openssl::read_key`?")
        }

        jwt_claim <- jose::jwt_claim(
            exp = as.integer(as.POSIXct(Sys.time() + as.difftime(1, units = "mins"))),
            iss = org_id,
            sub = tech_id,
            aud = paste0('https://ims-na1.adobelogin.com/c/', client_id),
            # Metascope for Adobe Analytics
            "https://ims-na1.adobelogin.com/s/ent_analytics_bulk_ingest_sdk" = TRUE
        )

        jwt_token <- jose::jwt_encode_sig(jwt_claim, private_key, size = 256)
    }

    jwt_token
}


#' Adobe JWT token response
#'
#' Includes the response object containing the bearer token as well as the
#' credentials used to generate the token for seamless refreshing.
#'
#' Refreshing is disabled if the user used a custom JWT token.
#'
#' @section Methods:
#' * `refresh()`: refresh access token (if possible)
#' * `validate()`: TRUE if the token is still valid, FALSE otherwise
#'
#' @docType class
#' @keywords internal
#' @format An R6 object
#' @importFrom R6 R6Class
#' @noRd
AdobeJwtToken <- R6::R6Class("AdobeJwtToken", list(
    secrets = NULL,
    token = NULL,
    initialize = function(token, secrets) {
        self$secrets <- secrets
        self$token <- token
    },
    can_refresh = function() {
        FALSE
    },
    refresh = function() {
        self$token <- auth_jwt_gen(self$secrets)
        self
    },
    validate = function() {
        self$token$date + httr::content(self$token)$expires_in / 1000 > Sys.time() - 1200
    }
))


# OAuth ----------------------------------------------------------------
#' @family auth
#' @describeIn aw_auth Authorize via OAuth 2.0
#' @export
auth_oauth <- function(client_id = Sys.getenv("AW_CLIENT_ID"),
                       client_secret = Sys.getenv("AW_CLIENT_SECRET"),
                       use_oob = TRUE) {
    stopifnot(is.character(client_id))
    stopifnot(is.character(client_secret))

    if (use_oob) {
        oob_value <- "https://adobeanalyticsr.com/token_result.html"
    } else {
        oob_value <- NULL
    }


    if (any(c(client_id, client_secret) == "")) {
        stop("Client ID or Client Secret not found. Are your environment variables named `AW_CLIENT_ID` and `AW_CLIENT_SECRET`?")
    }

    aw_endpoint <- httr::oauth_endpoint(
        authorize = "authorize/v2/",
        access = "token/v3",
        base_url = "https://ims-na1.adobelogin.com/ims"
    )

    aw_app <- httr::oauth_app(
        appname = "adobe_analytics_v2.0",
        key = client_id,
        secret = client_secret
    )

    #Oauth2 token
    token <- httr::oauth2.0_token(
        endpoint = aw_endpoint,
        app = aw_app,
        scope = "openid,AdobeID,read_organizations,additional_info.projectedProductContext,additional_info.job_function",
        cache = token_path(getOption("adobeanalyticsr.auth_path", "aa.oauth")),
        use_oob = use_oob,
        oob_value = oob_value
    )

    message("Successfully authenticated with OAuth")
    .adobeanalytics$token <- token
    .adobeanalytics$client_id <- client_id
    .adobeanalytics$client_secret <- client_secret
}
