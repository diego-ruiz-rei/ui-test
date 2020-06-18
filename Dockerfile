FROM node:10-alpine
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
#RUN rm /var/www/html/index.nginx-debian.html

#copy configured nginx file
COPY nginx/ /etc/nginx/conf.d

# Create app directory
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# Add the generated "dist" folder in jenkins pipeline
ADD dist ./dist
# Add config/update-build-env.js to substitute the environment variables in `main-**.js` files
ADD config ./config
# Add package.json for command line used in CMD
ADD package.json ./

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