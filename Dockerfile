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

#RUN rm /var/www/html/index.nginx-debian.html
COPY package.json .

#
# ---- Dependencies ----
FROM base AS dependencies
# puppeteer
RUN apk add --no-cache \
      chromium \
      nss \
      freetype \
      freetype-dev \
      harfbuzz \
      ca-certificates \
      ttf-freefont
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
RUN npm install

COPY . /usr/src/app
RUN node -v

#
# ---- Test ----
FROM dependencies AS tests
RUN addgroup -S pptruser && adduser -S -g pptruser pptruser \
    && mkdir -p /home/pptruser/Downloads /app \
    && chown -R pptruser:pptruser /home/pptruser \
    && chown -R pptruser:pptruser /usr/src/app
USER pptruser
RUN npm run test:headless

#
# ---- Build ----
FROM dependencies AS build
#COPY --from=dependencies /usr/src/app/node_modules ./node_modules
RUN npm run prod

#
# ---- Release ----
FROM base AS release
COPY --from=build /usr/src/app/dist ./dist

#copy configured nginx file
COPY nginx/ /etc/nginx/conf.d


# Add config/update-build-env.js to substitute the environment variables in `main-**.js` files
# ADD config ./config
# Add package.json for command line used in CMD
# ADD package.json ./

# Drop the root user and make the content of these path owned by user 1001
RUN chown -R 1001:1001 /usr/src/app/dist
RUN chown -R 1001:1001 /var/log/nginx
RUN chown -R 1001:1001 /var/lib/nginx
#RUN chown -R 1001:1001 /var/tmp/nginx # Exist only on alpine images
#RUN chown -R 1001:1001 /usr/share/nginx #doesn't exist in alpine
# Solve nginx start to create `nginx.pid` in /run
RUN mkdir -p /run/nginx
RUN chown -R 1001:1001 /run

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
     && ln -sf /dev/stderr /var/log/nginx/error.log

USER 1001

EXPOSE 8080

# Build the static application during runtime to pick up env variables
#CMD npm run build:${UI_ENVIRONMENT} && npm run start:${UI_ENVIRONMENT}

CMD npm run server:prod