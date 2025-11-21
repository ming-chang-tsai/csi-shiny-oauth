# app.R

library(shiny)
library(shinyOAuth)

# -------------------------------------------------------------------
# OAuth provider config (CSI Pacific)
# -------------------------------------------------------------------

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
  # Optional: if you have a userinfo endpoint exposed by CSI:
  userinfo_url = Sys.getenv(
    "CSIP_USERINFO_URL",
    ""  # leave empty if not available
  )
)

# -------------------------------------------------------------------
# OAuth client config (CONFIDENTIAL client)
# -------------------------------------------------------------------
# These must all be set as environment variables on Posit Connect.
# - CSIP_CLIENT_ID
# - CSIP_CLIENT_SECRET
# - CSIP_REDIRECT_URI
# - CSIP_SCOPES (optional, default: "openid profile email")
# -------------------------------------------------------------------

scopes <- strsplit(
  Sys.getenv("CSIP_SCOPES", "openid profile email"),
  "\\s+"
)[[1]]

client <- oauth_client(
  provider      = provider,
  client_id     = Sys.getenv("CSIP_CLIENT_ID"),
  client_secret = Sys.getenv("CSIP_CLIENT_SECRET"),  # <- confidential
  redirect_uri  = Sys.getenv("CSIP_REDIRECT_URI"),   # exact app URL
  scopes        = scopes
)

# -------------------------------------------------------------------
# UI
# -------------------------------------------------------------------

ui <- fluidPage(
  use_shinyOAuth(),
  h2("CSI Pacific OAuth demo (confidential client)"),
  uiOutput("login_information")
)

# -------------------------------------------------------------------
# Server
# -------------------------------------------------------------------

server <- function(input, output, session) {
  # Log query string for debugging in Connect logs
  observe({
    qs <- session$clientData$url_search
    if (nzchar(qs)) {
      cat("Callback query string:", qs, "\n")
    }
  })
  
  # Auth module
  auth <- oauth_module_server("auth", client)
  
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

# -------------------------------------------------------------------
# Return Shiny app (required for Posit Connect)
# -------------------------------------------------------------------

shinyApp(ui, server)
