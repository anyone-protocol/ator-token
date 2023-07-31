# BUILD
FROM node:18.16-alpine As build

WORKDIR /usr/src/app

COPY --chown=node:node . .

RUN npm install

RUN npm run build

USER node
