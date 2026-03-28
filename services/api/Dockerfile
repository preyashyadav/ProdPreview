FROM node:18-alpine

WORKDIR /app

ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --omit=dev

COPY app/ ./app/

EXPOSE 4000

CMD ["npm", "start"]
