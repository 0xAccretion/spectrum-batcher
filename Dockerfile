FROM ubuntu:22.04 as builder

RUN apt-get update -y && apt-get upgrade -y && apt-get install librocksdb-dev git liblzma-dev libnuma-dev curl automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf libncurses-dev clang llvm-13 llvm-13-dev -y

# GHCUP
ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1
RUN bash -c "curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh"
RUN bash -c "curl -sSL https://get.haskellstack.org/ | sh"

# Add ghcup to PATH
ENV PATH=${PATH}:/root/.local/bin
ENV PATH=${PATH}:/root/.ghcup/bin

# install GHC and cabal
ARG GHC=8.10.7
ARG CABAL=3.6.2.0

RUN ghcup -v install ghc ${GHC} && \
    ghcup -v install cabal ${CABAL}
RUN ghcup set ghc $GHC
RUN ghcup set cabal $CABAL

# Cardano haskell dependencies
RUN git clone https://github.com/input-output-hk/libsodium
RUN cd libsodium && git checkout 66f017f1 && ./autogen.sh && ./configure && make && make install
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

# libsecp256k1
RUN git clone https://github.com/bitcoin-core/secp256k1
RUN cd secp256k1 && git checkout ac83be33 && ./autogen.sh && ./configure --enable-module-schnorrsig --enable-experimental && make && make check && make install


ENV PATH=/usr/lib/llvm-13/bin:$PATH
RUN export CPLUS_INCLUDE_PATH=$(llvm-config --includedir):$CPLUS_INCLUDE_PATH
RUN export LD_LIBRARY_PATH=$(llvm-config --libdir):$LD_LIBRARY_PATH

ARG CACHE_BUST
ARG git_branch = master
RUN git clone https://github.com/spectrum-finance/cardano-dex-backend.git /spectrum-batcher
RUN cd /spectrum-batcher && git checkout ${git_branch}

WORKDIR /spectrum-batcher
RUN cabal clean
RUN cabal update
RUN cp CHANGELOG.md amm-executor/CHANGELOG.md
RUN cp CHANGELOG.md wallet-helper/CHANGELOG.md
RUN cabal configure --disable-tests --disable-benchmarks -f-scrypt -O2
RUN cabal install amm-executor-app

FROM ubuntu:22.04
RUN apt-get update -y && apt-get upgrade -y && apt-get install librocksdb-dev libnuma-dev x509-util curl -y
RUN x509-util system
# TEST CARDANO EXPLORER
RUN curl https://explorer.spectrum.fi/cardano/mainnet/v1/outputs/31a497ef6b0033e66862546aa2928a1987f8db3b8f93c59febbe0f47b14a83c6:0
COPY --from=builder /usr/lib/llvm-13 /usr/lib/llvm-13
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /root/.cabal/store/ghc-8.10.7 /root/.cabal/store/ghc-8.10.7
COPY --from=builder /root/.cabal/bin /root/.cabal/bin
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENTRYPOINT /root/.cabal/bin/amm-executor-app "/mnt/spectrum/config.dhall"
