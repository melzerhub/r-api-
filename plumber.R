# plumber.R
library(plumber)
library(jsonlite)
library(base64enc)
library(rmarkdown)

`%||%` <- function(a, b) if (is.null(a) || is.na(a)) b else a

# ---- Analysefunktion (robust) ----
analyze_payload <- function(req_json) {
  payload <- if (is.list(req_json)) req_json else jsonlite::fromJSON(req_json)

  if (is.null(payload$data) || length(payload$data) < 1)
    stop("Payload hat kein 'data' mit mindestens einem Eintrag.")

  df <- as.data.frame(payload$data[[1]], stringsAsFactors = FALSE)
  df$ID <- payload$participant_id %||% "anon"

  U_names <- paste0("U", 1:22)
  L_names <- paste0("L", 1:15)
  S_names <- paste0("Slider_", 1:30)

  # fehlende Spalten ergänzen
  for (nm in c(U_names, L_names, S_names)) if (is.null(df[[nm]])) df[[nm]] <- NA

  to_num <- function(x) suppressWarnings(as.numeric(x))
  df[U_names] <- lapply(df[U_names], to_num)
  df[L_names] <- lapply(df[L_names], to_num)
  df[S_names] <- lapply(df[S_names], to_num)

  invert_items <- c("U3","U8","U11","U12","U15","U16","U21",
                    "L2","L3","L7","L9","L10","L11","L13")
  invert_items <- intersect(invert_items, names(df))
  if (length(invert_items))
    df[invert_items] <- lapply(df[invert_items], function(x) ifelse(is.na(x), NA, 6 - x))

  df$Unternehmerfaehigkeit <- rowMeans(df[paste0("U", 1:22)], na.rm = TRUE)
  df$Leistungsmotivation   <- rowMeans(df[paste0("L", 1:15)], na.rm = TRUE)

  rollen_cluster <- list(
    Verkaeufer          = c(1, 10, 14, 20, 30),
    Finance_Coordinator = c(1, 10, 11, 14, 15, 20, 24, 30),
    Captain             = c(2, 6, 12, 16, 19, 21, 25),
    Pioneer             = c(2, 6, 12, 15, 16, 19, 21, 24, 25),
    Netzwerker          = c(3, 5, 9, 11, 17, 22, 26, 27),
    Operator            = c(3, 5, 9, 17, 22, 26, 27),
    Productlead         = c(4, 7, 8, 13, 18, 23, 29),
    Business_Developer  = c(4, 7, 8, 13, 18, 23, 29)
  )

  for (rolle in names(rollen_cluster)) {
    cols <- paste0("Slider_", rollen_cluster[[rolle]])
    cols <- intersect(cols, names(df))
    df[[rolle]] <- if (length(cols)) rowMeans(df[, cols, drop = FALSE], na.rm = TRUE) else NA_real_
  }

  rollen_spalten <- names(rollen_cluster)
  df$Dominante_Rolle <- apply(df[, rollen_spalten, drop = FALSE], 1, function(x) {
    if (all(is.na(x))) return(NA_character_); names(x)[which.max(x)]
  })

  ergebnis <- df[, c("ID", "Unternehmerfaehigkeit", "Leistungsmotivation", rollen_spalten, "Dominante_Rolle")]

  list(ok = TRUE, ergebnis = ergebnis)
}

# ---- Healthcheck ----
#* @get /health
function(){ list(status="ok", time=as.character(Sys.time())) }

# ---- Analyse-Endpunkt ----
#* @post /analyze
function(req, res){
  tryCatch({
    body <- req$body %||% req$postBody  # je nach plumber-Version
    result <- analyze_payload(body)

    # ========== DEBUG-PHASE ==========
    # Während wir testen, NUR JSON zurückgeben.
    # Wenn das stabil läuft, den unteren Render-Block aktivieren.
    return(result)

    # ========== REPORT-PHASE (später aktivieren) ==========
    # tmp <- tempfile(fileext = ".html")
    # rmarkdown::render("onepager.Rmd",
    #   params = list(ergebnis = result$ergebnis),
    #   output_file = tmp, quiet = TRUE
    # )
    # list(
    #   filename = paste0("report_", result$ergebnis$ID[1], ".html"),
    #   mime = "text/html",
    #   content_base64 = base64enc::base64encode(tmp)
    # )
  }, error = function(e){
    res$status <- 400
    list(ok=FALSE, error=as.character(e))
  })
}
