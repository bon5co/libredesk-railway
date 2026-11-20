# Libredesk wrapper for Railway. The official image installs nothing by itself: the schema, the System login and the upgrade are
# separate CLI steps, and the public URL (used in invite links and notification mails) is a database setting that defaults to
# http://localhost:9000 and can only be changed after login. This image runs install and upgrade before the server starts, binds
# the server to Railway's injected PORT, and writes the Railway domain into that setting once, on the first boot only.
# upstream: abhinavxd/libredesk
FROM libredesk/libredesk:v2.9.2@sha256:1c5a234b113b6fa7b4170219a4e1063d8a9e4a396d4811b2ea03fdfcd02c63de

RUN apk add --no-cache curl jq

COPY --chmod=0755 boot.sh /railway-boot.sh

# Literals a deployer should never have to type are baked in here as ENV.
ENV LIBREDESK_APP__ENV=prod \
    LIBREDESK_APP__LOG_LEVEL=info \
    LIBREDESK_UPLOAD__PROVIDER=fs \
    LIBREDESK_UPLOAD__FS__UPLOAD_PATH=uploads

VOLUME ["/libredesk/uploads"]
EXPOSE 8080
ENTRYPOINT ["/railway-boot.sh"]
CMD ["./libredesk"]
