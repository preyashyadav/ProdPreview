FROM node:18-alpine

WORKDIR /app


COPY package*.json ./
RUN npm ci


COPY app/ ./app/


CMD ["node", "app/index.js"]
