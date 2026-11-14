# syntax=docker/dockerfile:1
# Pre-built (optimized) Keycloak image for the iam cluster.
# The base phasetwo image ships without a database vendor, so every start
# re-runs the Quarkus build; `kc.sh build` here lets the Keycloak operator
# run `start --optimized` and cuts pod start time by minutes.
# renovate: datasource=docker depName=quay.io/phasetwo/phasetwo-keycloak
ARG PHASETWO_VERSION=26.8.1
FROM quay.io/phasetwo/phasetwo-keycloak:${PHASETWO_VERSION}

# Build-time options MUST match the values the keycloak-operator passes at
# runtime (Keycloak CR spec: keycloak.yaml) or `start --optimized` refuses
# to boot with a configuration mismatch. The two *_LOGGER / SPI envs are
# needed at build time because ext-event-mdc-logger-store is an
# EnvironmentDependentProviderFactory: it only registers during build.
ENV KC_DB=postgres \
    KC_FEATURES=client-secret-rotation:v1 \
    KC_HOSTNAME=https://iam.dcaspi.dev \
    KC_PROXY_HEADERS=xforwarded \
    KC_HTTP_ENABLED=true \
    KC_HTTP_PORT=8180 \
    KC_HTTPS_PORT=8443 \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true \
    KC_SPI_EVENTS_STORE_EXT_EVENT_MDC_LOGGER_STORE_USE_JPA=true \
    EXT_EVENT_MDC_LOGGER_ENABLED=true

RUN /opt/keycloak/bin/kc.sh build
