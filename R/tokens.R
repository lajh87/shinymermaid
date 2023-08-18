create_token <- function(){
  selector <- sodium::random(6) |> sodium::bin2hex()
  validator <- sodium::random(32) |> sodium::bin2hex()
  paste(selector, validator, sep  = ":")
}

split_token <- function(token){
  stringr::str_split(token, ":") %>% unlist()
}

hash_validator <- function(validator){
  sodium::hex2bin(validator) %>%
    sodium::sha256() %>%
    sodium::bin2hex()
}

create_new_token <- function(db, session, set_cookie = TRUE, expiry, token_tbl = "token"){
  token <- create_token()
  selector <- split_token(token)[1]
  validator <- split_token(token)[2]
  hashed_validator <- hash_validator(validator)

  if(set_cookie){
    session$sendCustomMessage("cookie-set", list(name = "token", value = token, expiry = expiry))
  }

  DBI::dbExecute(db, glue::glue(
    "INSERT INTO {token_tbl}",
    "VALUES('{selector}', '{hashed_validator}', '0', '{Sys.Date()}')",
    .sep = "\n"
  ))

  return(token)
}

valid_token <- function(token, db, token_tbl = "token"){

  if(is.null(token)) return(FALSE)

  selector_var <- split_token(token)[1]
  validator_var <- split_token(token)[2]
  hashed_validator_var <- hash_validator(validator_var)

  hv_server <- db |> dplyr::tbl(token_tbl) |>
    dplyr::filter(.data$selector == selector_var) |>
    dplyr::pull(hashed_validator)

  if(!length(hv_server)) return(FALSE)
  if(is.null(hv_server)) return(FALSE)

  hashed_validator_var == hv_server

}
