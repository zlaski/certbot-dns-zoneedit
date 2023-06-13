FROM certbot/certbot
LABEL org.opencontainers.image.source="https://github.com/zlaski/certbot-dns-zoneedit"
LABEL maintainer="zlaski@ziemas.net"
ENV PYTHONIOENCODING="UTF-8"

COPY . src/certbot-dns-zoneedit

RUN pip install -U pip
RUN pip install --no-cache-dir --use-feature=in-tree-build src/certbot-dns-zoneedit

ENTRYPOINT ["/usr/bin/env"]
