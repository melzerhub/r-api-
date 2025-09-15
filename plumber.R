# plumber.R
library(plumber)
library(jsonlite)
library(rmarkdown)
library(base64enc)

# Healthcheck (Test, ob API läuft)
#* @get /health
function(){
  list(status="ok", time=as.character(Sys.time()))
}

# Analyse-Endpunkt
#* @post /analyze
function(req, res){
  body <- fromJSON(req$postBody)

  # --- einfacher Schutz ---
  secret_env <- Sys.getenv("API_SECRET")
  if (nzchar(secret_env)) {
    if (is.null(body$secret) || body$secret != secret_env) {
      res$status <- 401
      return(list(error="unauthorized"))
    }
  }

  # Daten in Tabelle verwandeln
  df <- as.data.frame(body$data, stringsAsFactors = FALSE)

  # Beispiel-Auswertung: Items summieren
  df$score <- rowSums(df[c("item1","item2","item3","item4","item5")], na.rm = TRUE)

  # One-Pager erzeugen
  out_file <- tempfile(fileext = ".html")
  render("onepager.Rmd",
         output_file = out_file,
         params = list(participant_id = body$participant_id, data = df),
         quiet = TRUE)

  # Report als Base64 zurückgeben
  list(
    filename = paste0("report_", body$participant_id, ".html"),
    mime = "text/html",
    content_base64 = base64encode(out_file)
  )
}
