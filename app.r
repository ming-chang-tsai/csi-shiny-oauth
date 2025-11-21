# app.R

library(shiny)
library(shinyOAuth)

options(
  shinyOAuth.print_errors = TRUE,
  shinyOAuth.print_traceback = TRUE,
  shinyOAuth.expose_error_body = TRUE
)

# ---------------------------------------------------------
# OAuth provider config (CSI Pacific)
# ---------------------------------------------------------

provider <- oauth_provider(
  name       = "CSI Pacific",
  auth_url   = Sys.getenv(
    "CSIP_AUTH_URL",
    "https://apps.csipacific.ca/o/authorize/"
  ),
  token_url  = Sys.getenv(
    "CSIP_TOKEN_URL",
    "https://apps.csipacific.ca/o/token/"
  ),
  # Optional: only if you actually have this endpoint:
  userinfo_url = Sys.getenv("CSIP_USERINFO_URL", "")
)

# ---------------------------------------------------------
# OAuth client config (CONFIDENTIAL client)
#   All secrets/URLs pulled from environment variables
# ---------------------------------------------------------

scopes <- strsplit(
  Sys.getenv("CSIP_SCOPES", "openid profile email"),
  "\\s+"
)[[1]]

client <- oauth_client(
  provider      = provider,
  client_id     = Sys.getenv("CSIP_CLIENT_ID"),
  client_secret = Sys.getenv("CSIP_CLIENT_SECRET"),  # confidential
  redirect_uri  = Sys.getenv("CSIP_REDIRECT_URI"),   # Connect URL
  scopes        = scopes
)

# ---------------------------------------------------------
# UI
# ---------------------------------------------------------

ui <- fluidPage(
  use_shinyOAuth(),
  h2("CSI Pacific OAuth demo (confidential client)"),
  uiOutput("login_information")
)

# ---------------------------------------------------------
# Server
# ---------------------------------------------------------

server <- function(input, output, session) {
  # Helpful debug: log query string when callback happens
  observe({
    qs <- session$clientData$url_search
    if (nzchar(qs)) {
      cat("Callback query string:", qs, "\n")
    }
  })
  
  auth <- oauth_module_server("auth", client)
  
  observe({
    cat("Authenticated? ", auth$authenticated, "\n")
    if (!is.null(auth$token)) {
      cat("Token classes: ", paste(class(auth$token), collapse = ", "), "\n")
    }
  })
  
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

# ---------------------------------------------------------
# Return Shiny app (for Posit Connect)
# ---------------------------------------------------------

shinyApp(ui, server)
