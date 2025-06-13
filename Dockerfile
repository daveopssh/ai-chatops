FROM python:3.13-slim-bookworm as builder 

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      gfortran \
      libblas-dev \
      liblapack-dev \
      libffi-dev \
      libssl-dev \
      pkg-config \
      libatlas-base-dev \ 
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . .

RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip setuptools wheel \
    && /opt/venv/bin/pip install --no-cache-dir numpy==1.26.4 \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

ENV PATH="/opt/venv/bin:$PATH"


FROM python:3.13-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    libatlas3-base libblas3 liblapack3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app /app

ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

EXPOSE 8000

CMD ["fastapi", "run", "main.py"]
