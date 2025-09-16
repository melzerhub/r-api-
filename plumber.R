# ganz oben sicherstellen:
# library(jsonlite); library(rmarkdown)

#* @post /analyze
function(req, res) {
  # ---- Payload lesen ----
  body <- jsonlite::fromJSON(req$postBody)
  # erlaubt sowohl {"data":[{...}]} als auch {"data":{...}}
  df <- as.data.frame(body$data, stringsAsFactors = FALSE)
  df$ID <- body$participant_id

  # ---- invertierte Items ----
  invert_items <- c("U3","U8","U11","U12","U15","U16","U21",
                    "L2","L3","L7","L9","L10","L11","L13")
  have_inv <- intersect(invert_items, names(df))
  if (length(have_inv)) {
    df[have_inv] <- lapply(df[have_inv], function(x) 6 - as.numeric(x))
  }

  # ---- Skalen ----
  U_cols <- intersect(paste0("U", 1:22), names(df))
  L_cols <- intersect(paste0("L", 1:15), names(df))
  df[U_cols] <- lapply(df[U_cols], as.numeric)
  df[L_cols] <- lapply(df[L_cols], as.numeric)

  df$Unternehmerfaehigkeit <- if (length(U_cols)) rowMeans(df[U_cols], na.rm = TRUE) else NA_real_
  df$Leistungsmotivation   <- if (length(L_cols)) rowMeans(df[L_cols], na.rm = TRUE) else NA_real_

  # ---- Rollen-Cluster ----
  rollen_cluster <- list(
    Verkaeufer          = c(1,10,14,20,30),
    Finance_Coordinator = c(1,10,11,14,15,20,24,30),
    Captain             = c(2,6,12,16,19,21,25),
    Pioneer             = c(2,6,12,15,16,19,21,24,25),
    Netzwerker          = c(3,5,9,11,17,22,26,27),
    Operator            = c(3,5,9,17,22,26,27),
    Productlead         = c(4,7,8,13,18,23,29),
    Business_Developer  = c(4,7,8,13,18,23,29)
  )

  for (rolle in names(rollen_cluster)) {
    items <- paste0("Slider_", rollen_cluster[[rolle]])
    have  <- intersect(items, names(df))
    df[[rolle]] <- if (length(have)) rowMeans(df[ , have, drop=FALSE], na.rm = TRUE) else NA_real_
  }

  rollen_spalten <- names(rollen_cluster)
  df$Dominante_Rolle <- if (length(rollen_spalten)) {
    apply(df[ , rollen_spalten, drop=FALSE], 1, function(x) names(x)[which.max(x)])
  } else NA_character_

  ergebnis <- df[ , c("ID","Unternehmerfaehigkeit","Leistungsmotivation", rollen_spalten, "Dominante_Rolle")]

  # ---- HTML-Report rendern und als Base64 zurückgeben ----
  tmp <- tempfile(fileext = ".html")
  rmarkdown::render(
    "onepager.Rmd",
    params = list(ergebnis = ergebnis),
    output_file = tmp,
    quiet = TRUE
  )

  list(
    filename = paste0("report_", ergebnis$ID[1], ".html"),
    mime = "text/html",
    content_base64 = jsonlite::base64_enc(readBin(tmp, "raw", file.info(tmp)$size))
  )
}
