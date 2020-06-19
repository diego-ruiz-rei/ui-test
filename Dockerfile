#
# ---- Base Node ----
FROM node:10-alpine AS base
RUN sed -i -e 's/v3\.9/v3.10/g' /etc/apk/repositories
RUN apk update
RUN apk add --upgrade busybox
#actual patching
RUN apk update && \
apk upgrade busybox &&\
apk add gcc g++ make bash nginx curl openssl python bzip2&& \
rm -rf /var/cache/apk/*
RUN apk upgrade --available
RUN curl -O https://nodejs.org/dist/v10.11.0/node-v10.11.0-headers.tar.gz
ENV npm_config_tarball=/node-v10.11.0-headers.tar.gz
RUN sed -i -e 's/keepalive\_timeout 65/keepalive_timeout 300/g' /etc/nginx/nginx.conf

# Delete default nginx config file & index file
RUN rm /etc/nginx/conf.d/default.conf

# Create app directory
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY package.json .

#
# ---- Dependencies ----
FROM base AS dependencies
RUN npm install
COPY ./angular.json ./package.json ./tsconfig.json ./tsconfig.app.json ./tsconfig.spec.json ./karma.conf.js ./karma-headless.conf.js ./
COPY ./src ./src
RUN node -v

#
# ---- Test ----
# pulled from https://github.com/buildkite/docker-puppeteer/blob/master/Dockerfile
FROM node:12.18.0-buster-slim@sha256:97da8d5023fd0380ed923d13f83041dd60b0744e4d140f6276c93096e85d0899 as tests
    
RUN  apt-get update \
     && apt-get install -y wget gnupg ca-certificates \
     && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
     && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
     && apt-get update \
     # We install Chrome to get all the OS level dependencies, but Chrome itself
     # is not actually used as it's packaged in the node puppeteer library.
     # Alternatively, we could could include the entire dep list ourselves
     # (https://github.com/puppeteer/puppeteer/blob/master/docs/troubleshooting.md#chrome-headless-doesnt-launch-on-unix)
     # but that seems too easy to get out of date.
     && apt-get install -y google-chrome-stable \
     && rm -rf /var/lib/apt/lists/* \
     && wget --quiet https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh -O /usr/sbin/wait-for-it.sh \
     && chmod +x /usr/sbin/wait-for-it.sh
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
COPY --from=dependencies /usr/src/app/node_modules ./node_modules
COPY --from=dependencies /usr/src/app/angular.json /usr/src/app/package.json /usr/src/app/tsconfig.json /usr/src/app/tsconfig.spec.json /usr/src/app/karma-headless.conf.js ./
COPY --from=dependencies /usr/src/app/src ./src
RUN ls
RUN npm run test:ci-headless

#
# ---- Build ----
FROM dependencies AS build
RUN npm run prod

#
# ---- Release ----
FROM base AS release
COPY --from=build /usr/src/app/dist ./dist

#copy configured nginx file
COPY nginx/ /etc/nginx/conf.d

# Drop the root user and make the content of these path owned by user 1001
RUN chown -R 1001:1001 /usr/src/app/dist
RUN chown -R 1001:1001 /var/log/nginx
RUN chown -R 1001:1001 /var/lib/nginx

# Solve nginx start to create `nginx.pid` in /run
RUN mkdir -p /run/nginx
RUN chown -R 1001:1001 /run

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
     && ln -sf /dev/stderr /var/log/nginx/error.log

USER 1001

EXPOSE 8080

CMD npm run server:prod