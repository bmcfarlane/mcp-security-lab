# Built locally on your M4 => image is arm64 by definition.
FROM python:3.12-slim

RUN pip install --no-cache-dir "fastmcp>=2.3" "psycopg[binary]>=3.1"

WORKDIR /app
COPY server.py .

EXPOSE 8000
CMD ["python", "server.py"]
