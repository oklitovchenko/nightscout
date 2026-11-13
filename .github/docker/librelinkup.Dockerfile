FROM node:22-bookworm-slim AS build
WORKDIR /opt/app
COPY package.json package-lock.json ./
RUN npm ci --include=dev
COPY . .
RUN npm run build && npm prune --omit=dev

FROM node:22-bookworm-slim
WORKDIR /opt/app
COPY --from=build --chown=node:node /opt/app/dist ./dist
COPY --from=build --chown=node:node /opt/app/node_modules ./node_modules
USER node
CMD ["node", "dist/index.js"]
