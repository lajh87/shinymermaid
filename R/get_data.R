get_data <- function(db, tbl){
  db %>% dplyr::tbl(tbl) %>% dplyr::collect()
}

get_graph_token <- function(db, tbl, token){
  selector_ <- split_token(token)[1]
  hashed_validator_ <-  hash_validator(split_token(token)[2])
  db %>% dplyr::tbl(tbl) %>%
    dplyr::collect() %>%
    dplyr::filter(selector %in% selector_) %>%
    dplyr::filter(hashed_validator %in% hashed_validator_)
}

get_latest_graph <- function(latest_graph_tbl){
  latest_graph_tbl %>%
    dplyr::slice_tail(n = 1) %>%
    dplyr::pull(graph) %>%
    sodium::hex2bin() %>%
    rawToChar()
}
