# syntax=docker/dockerfile:1

# --- Stage 1: build Pikafish from its own official, unmodified source ---
# We compile rather than use the official prebuilt release binary because
# that binary is linked against a newer glibc than Debian bookworm ships
# (GLIBC_2.38), which fails to run in this image's runtime stage. Building
# from source here instead links against bookworm's own glibc, matching the
# runtime stage exactly, and is otherwise identical: unmodified upstream
# source, ARCH picked for broad portability (see `make help` in src/ for the
# full architecture list - bump this if you know your deployment target
# supports more, e.g. x86-64-avx512).
#
# GPL isolation (see docs/ARCHITECTURE.md section 2 and backend/README.md):
# the resulting binary is invoked by our Node process as a separate OS
# executable over UCI (stdin/stdout) - never linked into our code - so our
# TypeScript is not a derivative work under GPL. Copying.txt is carried into
# the final image alongside it for distribution compliance.
FROM debian:bookworm-slim AS pikafish-build

ARG PIKAFISH_REF=Pikafish-2026-09-06
ARG PIKAFISH_ARCH=x86-64-avx2

RUN apt-get update \
    && apt-get install -y --no-install-recommends git build-essential curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch "${PIKAFISH_REF}" https://github.com/official-pikafish/Pikafish.git .
WORKDIR /src/src
RUN make -j "$(nproc)" build ARCH=${PIKAFISH_ARCH} && make net

RUN mkdir -p /opt/pikafish \
    && cp pikafish pikafish.nnue /opt/pikafish/ \
    && cp ../Copying.txt /opt/pikafish/ \
    && chmod +x /opt/pikafish/pikafish

# --- Stage 2: compile TypeScript ---
FROM node:20-bookworm-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# --- Stage 3: runtime ---
FROM node:20-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production
ENV PIKAFISH_BIN_PATH=/opt/pikafish/pikafish
ENV PIKAFISH_CWD=/opt/pikafish

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=build /app/dist ./dist
COPY migrations ./migrations
COPY --from=pikafish-build /opt/pikafish /opt/pikafish

EXPOSE 3000
CMD ["node", "dist/index.js"]
