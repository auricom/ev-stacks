FROM ghcr.io/celestiaorg/celestia-app-standalone:${CELESTIA_APPD_TAG}

USER root

RUN apk add lz4

USER celestia