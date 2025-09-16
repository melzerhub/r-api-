# Robuste Basis mit fertigen Binärpaketen für CRAN
FROM rocker/r2u:jammy

# Systemtools (Pandoc für rmarkdown)
RUN apt-get update && apt-get install -y --no-install-recommends pandoc && rm -rf /var/lib/apt/lists/*

# R-Pakete als Binärpakete installieren (sehr stabil/schnell)
RUN install.r plumber jsonlite rmarkdown ggplot2 base64enc

WORKDIR /app
COPY plumber.R /app/plumber.R
COPY onepager.Rmd /app/onepager.Rmd

EXPOSE 8000
ENV API_SECRET=""

# Start: falls Plattform einen $PORT setzt, nutzen wir den
CMD ["R", "-e", "pr<-plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=as.integer(Sys.getenv('PORT','8000')))"]
