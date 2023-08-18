#' Initialise

config <- config::get() #Sys.getenv("R_CONFIG_ACTIVE")

db <- DBI::dbConnect(
  RMySQL::MySQL(),
  host = config$host,
  username =  config$username,
  password = config$password
)

# Create Database ----
DBI::dbExecute(db, glue::glue("CREATE DATABASE IF NOT EXISTS config$dbname;"))
DBI::dbDisconnect(db)

db <- DBI::dbConnect(
  RMySQL::MySQL(),
  dbname = config$dbname,
  host = config$host,
  username =  config$username,
  password = config$password
)

DBI::dbListTables(db)


# Create Token Table ----
DBI::dbExecute(db, glue::glue("DROP TABLE IF EXISTS {config$token_tbl};"))
DBI::dbExecute(
  conn = db,
  statement = glue::glue(
    "CREATE TABLE {config$token_tbl}(",
    "selector CHAR(12),",
    "hashed_validator CHAR(64),",
    "userid INT,",
    "created DATE",
    ");",
    .sep= "\n"
  )
)

# Create and Populate Examples Table ----
DBI::dbExecute(db, glue::glue("DROP TABLE IF EXISTS {config$example_tbl};"))
DBI::dbExecute(
  conn = db,
  statement = glue::glue(
    "CREATE TABLE {config$example_tbl}(",
    "id INT PRIMARY KEY,",
    "label TEXT,",
    "graph MEDIUMBLOB",
    ");",
    .sep = "\n"
  )
)

example_df <- purrr::map_df(list.files("examples"), ~{
  label <- substr(.x, 5, nchar(.x)-4) |>
    stringr::str_replace_all("-", " ") |>
    tools::toTitleCase()
  graph <- file.path("examples", .x) |>
    readLines() |>
    paste(collapse = "\n")
  data.frame(label, graph, stringsAsFactors = FALSE)
  }) |>
  dplyr::mutate(id = 1:dplyr::n(), .before = 1)

for(i in 1:nrow(example_df)){
  DBI::dbExecute(
    conn = db,
    glue::glue(
      "INSERT INTO {config$example_tbl} VALUES(",
      "{example_df$id[i]}, '{example_df$label[i]}', '{example_df$graph[i]}');",
      .sep = ""
    )
  )
}

# History
DBI::dbExecute(db, glue::glue("DROP TABLE IF EXISTS {config$history_tbl};"))
DBI::dbExecute(
  conn = db,
  statement = glue::glue(
    "CREATE TABLE {config$history_tbl}(",
    "selector CHAR(12),",
    "hashed_validator CHAR(64),",
    "label TEXT,",
    "graph MEDIUMBLOB,",
    "timestamp DATETIME",
    ");",
    .sep = "\n"
  )
)

DBI::dbExecute(db, glue::glue("DROP TABLE IF EXISTS {config$saves_tbl};"))
DBI::dbExecute(
  conn = db,
  statement = glue::glue(
    "CREATE TABLE {config$saves_tbl}(",
    "selector CHAR(12),",
    "hashed_validator CHAR(64),",
    "label TEXT,",
    "graph MEDIUMBLOB,",
    "timestamp DATETIME",
    ");",
    .sep = "\n"
  )
)
# Disconnect ----
DBI::dbDisconnect(db)
