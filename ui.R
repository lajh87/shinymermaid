htmlTemplate(
  filename = "template.html",
  dependencies = tagList(
    includeScript("www/bootstrap.bundle.min.js"),
    includeCSS("www/bootstrap.min.css"),
    includeScript("www/mermaid.min.js"),
    cookie_lib = includeScript("www/js.cookie.min.js"),
    shiny_cookies = includeScript("www/shiny-cookies.js"),
    fa = fontawesome::fa_html_dependency()
  ),
  editor = shinyAce::aceEditor(
    outputId = "ace",
    mode = "dot",
    height = "42.5vh",
    value = ""
  ),
  mermaid_diagram = uiOutput("mermaid"),
  examples = DT::dataTableOutput("examples"),
  history = DT::dataTableOutput("history"),
  saves = DT::dataTableOutput("saves")
  )
