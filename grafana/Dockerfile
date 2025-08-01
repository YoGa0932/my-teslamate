# Ensure selecting a tag that is available for arm/v7, arm64, and amd64
# https://hub.docker.com/r/grafana/grafana/tags
FROM grafana/grafana-oss:12.1.0

ENV GF_ANALYTICS_REPORTING_ENABLED=false \
    GF_AUTH_ANONYMOUS_ENABLED=false \
    GF_AUTH_BASIC_ENABLED=false \
    GF_SECURITY_ADMIN_PASSWORD=admin \
    GF_SECURITY_ADMIN_USER=admin \
    GF_SECURITY_ALLOW_EMBEDDING=true \
    GF_SECURITY_DISABLE_GRAVATAR=true \
    GF_DATABASE_HIGH_AVAILABILITY=false \
    GF_USERS_ALLOW_SIGN_UP=false \
    GF_USERS_DEFAULT_LANGUAGE=detect \
    GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/dashboards_internal/home.json \
    GF_DATE_FORMATS_USE_BROWSER_LOCALE=true \
    GF_PLUGINS_PREINSTALL_DISABLED=true \
    GF_UNIFIED_ALERTING_ENABLED=false \
    DATABASE_PORT=5432 \
    DATABASE_SSL_MODE=disable

USER grafana

COPY logo.svg /usr/share/grafana/public/img/grafana_icon.svg
COPY favicon.png /usr/share/grafana/public/img/fav32.png
COPY apple-touch-icon.png /usr/share/grafana/public/img/apple-touch-icon.png

COPY datasource.yml /etc/grafana/provisioning/datasources/
COPY dashboards.yml /etc/grafana/provisioning/dashboards/
COPY dashboards/internal/*.json /dashboards_internal/
COPY dashboards/reports/*.json /dashboards_reports/
COPY dashboards/*.json /dashboards/

EXPOSE 3000
