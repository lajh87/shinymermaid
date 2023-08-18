function(input, output, session){

  # Connect to Database -----
  pool <- pool::dbPool(
    RMySQL::MySQL(),
    dbname = config$dbname,
    host = config$host,
    username =  config$username,
    password = config$password
  )

  onStop(function() {
    pool::poolClose(pool)
  })

  # Load Data -----
  # Load Example Data
  values <- reactiveValues(
    examples = get_data(pool, "examples")
  )

  # Assign a Cookie and load data based on user
  observe({
    req(input$cookies)
    req(session$clientData)
    # If a valid cookie does not exist create one, otherwise load token from cookie
    if(is.null(input$cookies$token) || !valid_token(input$cookies$token, pool, config$token_tbl)){
      values$token <- create_new_token(pool, session, expiry = config$cookie_expiry, token_tbl = config$token_tbl)
    } else{
      values$token <- input$cookies$token
    }
    # Get saves and history based on token
    values$saves <- get_graph_token(pool, config$saves_tbl, values$token)
    values$history <- get_graph_token(pool, config$history_tbl, values$token)

    # If there is a history then get the latest graph
    if(nrow(values$history)>0){
      shinyAce::updateAceEditor(session, "ace", get_latest_graph(values$history))
    } else{
      shinyAce::updateAceEditor(session, "ace", values$examples$graph[1])
    }

  })

  # Render the mermaid table ----
  output$mermaid <- renderUI({
    req(input$ace)
    HTML(
      glue::glue(
        .open = "{{", .close = "}}",
        '<div class="mermaid";">{{input$ace}}</div>',
        '<script>',
        'mermaid.init();',
        '</script>',
        .sep = "\n"
        )
      )
  })

  # Examples -----
  output$examples <- DT::renderDataTable({
    dplyr::tibble(Example = values$examples$label,  Actions = shinyInput(
      FUN = actionButton,
      n = nrow(values$examples),
      id = 'button_',
      label = HTML('<i class="fa-solid fa-jet-fighter-up"></i>'),
      onclick = 'Shiny.setInputValue(\"select_example\", this.id, {priority: \"event\"})'
    ))
  },
  escape = FALSE,
  selection = "none",
  height = 150,
  rownames = FALSE,
  options = list(
    dom = "t",
    pageLength = nrow(values$examples),
    headerCallback = DT::JS(
      "function(thead, data, start, end, display){",
      "  $(thead).remove();",
      "}")))

  # On button click load the example
  observeEvent(input$select_example,{
    i <- as.numeric(strsplit(input$select_example, "_")[[1]][2])
    shinyAce::updateAceEditor(session, "ace", values$examples$graph[i])
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

  # Saves ----
  observeEvent(input$save, {
    label <- sample(
      tidytext::sentiments %>%
        dplyr::filter(sentiment == "positive") %>%
        dplyr::pull(word), 2
    ) %>%
      paste(collapse = "-")

    graph_binary <- input$ace %>%
      charToRaw() %>%
      sodium::bin2hex()

    selector <- split_token(values$token)[1]
    validator <- split_token(values$token)[2]
    hashed_validator <- hash_validator(validator)
    timestamp <- Sys.time()
    sql <- glue::glue("INSERT INTO {config$saves_tbl} VALUES(",
                      "'{selector}', '{hashed_validator}', '{label}',",
                      "'{graph_binary}', '{timestamp}');",
                      .sep ="\n")

    DBI::dbExecute(pool, DBI::sqlInterpolate(pool, sql))
    values$saves <- get_graph_token(pool, config$saves_tbl, values$token)
  })


  create_btns <- function(x) {
    purrr::map_chr(x, ~{
      glue::glue(
        '<div class = "btn-group">',
        "<button class='btn btn-default' id = loadsave_{{.x}} type='button'",
        "onclick='Shiny.setInputValue(\"load_save\", this.id, {priority: \"event\"})'>",
        "<i class='fa-solid fa-jet-fighter-up'></i></button>",
        "<button class='btn btn-default'",
        "id = deletesave_{{.x}} type='button'",
        "onclick='Shiny.setInputValue(\"delete_save\", this.id, {priority: \"event\"})'>",
        "<i class='fa-solid fa-trash'></i></button>",
        '</div>',
        .sep = " ",
        .open = "{{",
        .close = "}}" )
    })
  }


  output$saves <- DT::renderDataTable({
    if(length(values$saves)==0 || nrow(values$saves) == 0){
      df <- values$saves %>% dplyr::select(label, timestamp)
    } else{
      df <- values$saves %>% dplyr::select(label, timestamp) %>%
        dplyr::mutate(actions = create_btns(1:nrow(values$saves))) %>%
        dplyr::arrange(dplyr::desc(timestamp))
    }
    df
  },
  escape = FALSE,
  selection = "none",
  height = 150,
  rownames = FALSE,
  options = list(
    dom = "t",
    pageLength = nrow(values$saves),
    headerCallback = DT::JS(
      "function(thead, data, start, end, display){",
      "  $(thead).remove();",
      "}")))

  observeEvent(input$load_save, {
    i <- as.numeric(strsplit(input$load_save, "_")[[1]][2])
    graph <- values$saves$graph[i] %>% sodium::hex2bin() %>% rawToChar()
    shinyAce::updateAceEditor(session, "ace", graph)
  })

  observeEvent(input$delete_save, {
    i <- as.numeric(strsplit(input$delete_save, "_")[[1]][2])
    label <- values$saves$label[i]
    sql <- glue::glue("DELETE FROM {config$saves_tbl} WHERE label = '{label}';")
    DBI::dbExecute(pool, DBI::sqlInterpolate(pool, sql))
    values$saves <- get_graph_token(pool, "saves", values$token)
  })

  # History ----
  autoInvalidate <- reactiveTimer(180000) # autosave every 3 minutes (180000ms)
  observeEvent(autoInvalidate(), {
    req(input$ace)
    latest_graph_tbl <- get_graph_token(pool, config$history_tbl, values$token)

    if(nrow(latest_graph_tbl)>0){
      latest_graph <- get_latest_graph(latest_graph_tbl)
    } else{
      latest_graph <- NA
    }

    if(!is.na(latest_graph)  && input$ace == latest_graph) return(NULL) else{
      label <- sample(tidytext::sentiments %>%
                        dplyr::filter(sentiment == "positive") %>%
                        dplyr::pull(word), 2) %>% paste(collapse = "-")
      graph_binary <- input$ace %>% charToRaw() %>% sodium::bin2hex()
      selector <- split_token(values$token)[1]
      validator <- split_token(values$token)[2]
      hashed_validator <- hash_validator(validator)
      timestamp <- Sys.time()
      sql <- glue::glue("INSERT INTO {config$history_tbl} VALUES(",
                 "'{selector}', '{hashed_validator}', '{label}',",
                 "'{graph_binary}', '{timestamp}');",
                 .sep ="\n")

      DBI::dbExecute(pool, DBI::sqlInterpolate(pool, sql))
      values$history <- get_graph_token(pool, config$history_tbl, values$token)
    }
  })

  output$history <- DT::renderDataTable({
    if(length(values$history)==0 || nrow(values$history) == 0){
      df <- values$history %>% dplyr::select(label, timestamp)
    } else{
      df <-  values$history %>% dplyr::select(label, timestamp) %>%
        dplyr::mutate(actions = shinyInput(
          FUN = actionButton,
          n = nrow(values$history),
          id = 'button_',
          label = HTML('<i class="fa-solid fa-jet-fighter-up"></i>'),
          onclick = 'Shiny.setInputValue(\"select_history\", this.id, {priority: \"event\"})'
        )) %>%
        dplyr::arrange(dplyr::desc(timestamp))
    }
    df
  },
  escape = FALSE,
  selection = "none",
  height = 150,
  rownames = FALSE,
  options = list(
    dom = "t",
    pageLength = nrow(values$history),
    headerCallback = DT::JS(
      "function(thead, data, start, end, display){",
      "  $(thead).remove();",
      "}")))

  observeEvent(input$select_history,{
    i <- as.numeric(strsplit(input$select_history, "_")[[1]][2])
    graph <- values$history$graph[i] %>% sodium::hex2bin() %>% rawToChar()
    shinyAce::updateAceEditor(session, "ace", graph)
  })

  # Full Screen
  observeEvent(input$fullscreen, session$sendCustomMessage("get_element_by_id", "svg"))
  observeEvent(input$svg, showModal(
    modalDialog(
      size = "l", HTML(input$svg[1]), easyClose = TRUE,
      footer = tagList(downloadButton("download_svg", ".svg"), modalButton("Close"))
    )
  ))

  output$download_svg <- downloadHandler(
    filename = function() {
      paste(Sys.Date(),'-mermaid-plot', '.svg', sep='')
    },
    content = function(file) {
      write(HTML(input$svg[1]), file)
    }
  )
  }
