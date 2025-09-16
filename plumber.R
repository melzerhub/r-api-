#* @post /analyze
function(req, res) {
  body <- jsonlite::fromJSON(req$postBody)
  df <- as.data.frame(body$data)

  df$ID <- body$participant_id

  # Invertierte Items
  invert_items <- c("U3","U8","U11","U12","U15","U16","U21",
                    "L2","L3","L7","L9","L10","L11","L13")
  df[invert_items] <- lapply(df[invert_items], function(x) 6 - x)

  # Scores
  df$Unternehmerfaehigkeit <- rowMeans(df[paste0("U",1:22)], na.rm = TRUE)
  df$Leistungsmotivation   <- rowMeans(df[paste0("L",1:15)], na.rm = TRUE)

  rollen_cluster <- list(
    Verkaeufer        = c(1,10,14,20,30),
    Finance_Coordinator = c(1,10,11,14,15,20,24,30),
    Captain           = c(2,6,12,16,19,21,25),
    Pioneer           = c(2,6,12,15,16,19,21,24,25),
    Netzwerker        = c(3,5,9,11,17,22,26,27),
    Operator          = c(3,5,9,17,22,26,27),
    Productlead       = c(4,7,8,13,18,23,29),
    Business_Developer = c(4,7,8,13,18,23,29)
  )

  for (rolle in names(rollen_cluster)) {
    items <- paste0("Slider_", rollen_cluster[[rolle]])
    df[[rolle]] <- rowMeans(df[, items], na.rm = TRUE)
  }

  rollen_spalten <- names(rollen_cluster)
  df$Dominante_Rolle <- apply(df[,rollen_spalten], 1, function(x) names(x)[which.max(x)])

  ergebnis <- df[,c("ID","Unternehmerfaehigkeit","Leistungsmotivation",rollen_spalten,"Dominante_Rolle")]

  return(list(ok=TRUE, ergebnis=ergebnis))
}
