FROM node:20-alpine
# tzdata: without it Node can't resolve TZ (e.g. America/Toronto) and silently
# runs on UTC — crons fire at the wrong hour and day boundaries shift.
RUN apk add --no-cache tzdata
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY tsconfig.json ./
COPY src ./src
EXPOSE 3000
CMD ["npm", "start"]
