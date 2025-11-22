# app.R — CSI Pacific OAuth2 (confidential) via shinyOAuth on Posit Connect

library(shiny)
library(shinyOAuth)
library(cachem)

## --------------------------------------------------------------------
## Global options: logging & observability
## --------------------------------------------------------------------
options(
  shinyOAuth.print_errors       = TRUE,
  shinyOAuth.print_traceback    = TRUE,
  shinyOAuth.expose_error_body  = TRUE,
  shinyOAuth.trace_hook = function(event) {
    # Log everything interesting to Posit Connect
    cat("=== shinyOAuth TRACE EVENT ===\n")
    str(event)
    cat("=== END TRACE EVENT ===\n")
  },
  shinyOAuth.skip_browser_token = TRUE
)

## --------------------------------------------------------------------
## Provider configuration (CSI Pacific)
## --------------------------------------------------------------------
provider <- oauth_provider(
  name        = "CSI Pacific",
  auth_url    = Sys.getenv("CSIP_AUTH_URL",  "https://apps.csipacific.ca/o/authorize/"),
  token_url   = Sys.getenv("CSIP_TOKEN_URL", "https://apps.csipacific.ca/o/token/"),
  # If you later add a userinfo endpoint, set it here:
  userinfo_url = Sys.getenv("CSIP_USERINFO_URL", "")
)

## --------------------------------------------------------------------
## Client configuration (confidential client)
## --------------------------------------------------------------------
scopes <- strsplit(
  Sys.getenv("CSIP_SCOPES", "read"),
  "\\s+"
)[[1]]

client_id     <- Sys.getenv("CSIP_CLIENT_ID")
client_secret <- Sys.getenv("CSIP_CLIENT_SECRET")
redirect_uri  <- Sys.getenv("CSIP_REDIRECT_URI")
state_key     <- Sys.getenv("CSIP_STATE_KEY")

# cat("STATE_KEY length: ", nchar(STATE_KEY), "\n")
cat("STATE_KEY length: ", nchar(state_key), "\n")

if (identical(STATE_KEY, "")) {
  stop("CSIP_STATE_KEY is empty / not set in this environment.")
}

# Shared disk cache for OAuth state (multi-process safe on Connect)
state_cache <- cache_disk(dir = "shinyoauth_state_cache")

# Fail fast if anything critical is missing
if (client_id == "" || client_secret == "" || redirect_uri == "" || state_key == "") {
  stop(paste(
    "OAuth configuration error:\n",
    "- CSIP_CLIENT_ID:     ", if (client_id == "") "MISSING" else "OK", "\n",
    "- CSIP_CLIENT_SECRET: ", if (client_secret == "") "MISSING" else "OK", "\n",
    "- CSIP_REDIRECT_URI:  ", if (redirect_uri == "") "MISSING" else redirect_uri, "\n",
    "- CSIP_STATE_KEY:     ", if (state_key == "") "MISSING" else "OK", "\n",
    "Set these as environment variables in Posit Connect."
  ))
}

client <- oauth_client(
  provider      = provider,
  client_id     = client_id,
  client_secret = client_secret,
  redirect_uri  = redirect_uri,
  scopes        = scopes,
  # Critical for multi-process on Connect:
  state_store   = state_cache,
  state_key     = state_key
)

## --------------------------------------------------------------------
## UI
## --------------------------------------------------------------------
ui <- fluidPage(
  use_shinyOAuth(),   # JS dependency (must be included!)
  uiOutput("login_information")
)

## --------------------------------------------------------------------
## Server
## --------------------------------------------------------------------
server <- function(input, output, session) {
  
  # Log callback query string to help debugging
  observe({
    qs <- session$clientData$url_search
    if (nzchar(qs)) {
      cat("Callback query string:", qs, "\n")
    }
  })
  
  # Start OAuth module; auto_redirect = TRUE = send anon users straight to login
  auth <- oauth_module_server(
    "auth",
    client,
    auto_redirect = TRUE
    # async = TRUE  # optional later if you want, not required right now
  )
  
  # Log authentication status + token presence
  observe({
    cat("Authenticated? ", auth$authenticated, "\n")
    if (!is.null(auth$token)) {
      cat("Token classes: ", paste(class(auth$token), collapse = ", "), "\n")
    }
  })
  
  # Simple UI
  output$login_information <- renderUI({
    if (auth$authenticated) {
      user_info <- auth$token@userinfo
      tagList(
        tags$p("You are logged in! Your details:"),
        tags$pre(paste(capture.output(str(user_info)), collapse = "\n"))
      )
    } else {
      tags$p("You are not logged in.")
    }
  })
}

shinyApp(ui, server)
