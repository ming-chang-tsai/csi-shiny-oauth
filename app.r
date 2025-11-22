library(shiny)
library(shinyOAuth)

# ------------------------------------------------------------------
# Provider & client from ENV
# ------------------------------------------------------------------
provider <- oauth_provider(
  name      = "CSI Pacific",
  auth_url  = Sys.getenv("CSIP_AUTH_URL"),   # e.g. https://apps.csipacific.ca/o/authorize/
  token_url = Sys.getenv("CSIP_TOKEN_URL")   # e.g. https://apps.csipacific.ca/o/token/
)

client <- oauth_client(
  provider      = provider,
  client_id     = Sys.getenv("CSIP_CLIENT_ID"),
  client_secret = Sys.getenv("CSIP_CLIENT_SECRET"),  # non-empty for confidential
  redirect_uri  = Sys.getenv("CSIP_REDIRECT_URI"),   # your Connect share URL, https://.../
  scopes        = strsplit(Sys.getenv("CSIP_SCOPES", "read"), "\\s+")[[1]]
)

ui <- fluidPage(
  use_shinyOAuth(),
  uiOutput("login_information")
)

server <- function(input, output, session) {
  # Very lightweight debug of what shinyOAuth thinks it’s using
  observeEvent(TRUE, {
    cat("=== shinyOAuth CONFIG ===\n")
    cat("  AUTH URL  :", provider@auth_url, "\n")
    cat("  TOKEN URL :", provider@token_url, "\n")
    cat("  CLIENT ID :", substr(Sys.getenv("CSIP_CLIENT_ID"), 1, 6), "...\n")
    cat("  REDIRECT  :", Sys.getenv("CSIP_REDIRECT_URI"), "\n")
    cat("  SCOPES    :", Sys.getenv("CSIP_SCOPES"), "\n")
    cat("=========================\n")
  }, once = TRUE)
  
  auth <- oauth_module_server(
    "auth",
    client = client,
    async  = FALSE  # fine to keep false for now
  )
  
  output$login_information <- renderUI({
    if (auth$authenticated) {
      user_info <- auth$token@userinfo
      tagList(
        p("You are logged in! Your details:"),
        tags$pre(paste(capture.output(str(user_info)), collapse = "\n"))
      )
    } else {
      p("You are not logged in.")
    }
  })
}

shinyApp(ui, server)
