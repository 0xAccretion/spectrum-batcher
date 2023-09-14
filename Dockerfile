FROM spectrumlabs/spectrum-cardano-backend:1.0.2
COPY ./config/mainnet /config/mainnet
COPY ./scripts /scripts
RUN mkdir /data