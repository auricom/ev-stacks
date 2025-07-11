FROM ghcr.io/celestiaorg/celestia-app-standalone:db33a83

USER root

RUN apk add lz4

USER celestia