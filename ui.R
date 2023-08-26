htmlTemplate(
  filename = "template.html",
  dependencies = tagList(
    tags$link(rel = "stylesheet", type = "text/css", href = "bootstrap.min.css"),
    tags$link(rel = "stylesheet", type = "text/css", href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.2/css/all.min.css"),
    tags$script(src ="bootstrap.bundle.min.js"),
    tags$script(src = "mermaid.min.js"),
    tags$script(src = "js.cookie.min.js"),
    tags$script(src = "shiny-cookies.js"),
    tags$script(src = "shiny-mermaid.js")
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
