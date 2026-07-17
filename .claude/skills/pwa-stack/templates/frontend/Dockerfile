FROM node:20-alpine AS build
WORKDIR /app
# [FEATURE: web-push] Public VAPID key is baked into the bundle at build time.
ARG VITE_VAPID_PUBLIC_KEY
ENV VITE_VAPID_PUBLIC_KEY=$VITE_VAPID_PUBLIC_KEY
COPY package.json ./
RUN npm install
COPY . .
RUN npm run build
# Final stage just holds the artifacts for extraction into the shared volume.
FROM alpine:3.20
COPY --from=build /app/dist /dist
CMD ["sh", "-c", "cp -r /dist/. /out/ && echo 'frontend build copied' && sleep infinity"]
