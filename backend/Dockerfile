FROM oven/bun:1 AS base
WORKDIR /app

COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile || bun install

COPY . .

RUN mkdir -p /app/data

ENV PORT=3000
ENV DB_PATH=/app/data/gasolina.db
ENV FETCH_INTERVAL_MINUTES=15

EXPOSE 3000

CMD ["bun", "run", "src/index.ts"]
