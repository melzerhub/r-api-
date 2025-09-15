FROM rocker/r-ver:4.3.1

# System-Tools für rmarkdown/Plots
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev libssl-dev libxml2-dev pandoc \
 && rm -rf /var/lib/apt/lists/*

# Benötigte R-Pakete
RUN R -e "install.packages(c('plumber','jsonlite','rmarkdown','ggplot2','base64enc'), repos='https://cloud.r-project.org')"

WORKDIR /app
COPY plumber.R /app/plumber.R
COPY onepager.Rmd /app/onepager.Rmd

EXPOSE 8000
# Secret kommt später als Umgebungsvariable vom Hoster
ENV API_SECRET=""

# Startet den plumber-Server; nutzt $PORT falls vom Hoster vorgegeben
CMD ["R", "-e", "pr<-plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=as.integer(Sys.getenv('PORT','8000')))"]
