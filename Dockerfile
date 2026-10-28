# Fluentd output image used by the EFK examples.
FROM fluent/fluentd:v1.20.1-debian-1.0

USER root
RUN ["gem", "install", "fluent-plugin-elasticsearch", "--no-document", "--version", "6.0.0"]
USER fluent
