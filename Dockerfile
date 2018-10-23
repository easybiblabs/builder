FROM ruby:2.5-alpine

RUN apk add --update --upgrade --no-cache \
	git \
	ruby-dev \
	gcc \
	tar \
	alpine-sdk \
	libxml2-dev \
	libxslt-dev \
	bash vim nano mysql-client ca-certificates openssh-client \
	libssh2 freetype libgcc libxml2 libstdc++ icu-libs libltdl libmcrypt \
	tzdata nodejs yarn && \
	update-ca-certificates && \
	rm -rf /var/cache/apk/* && \
	mkdir -p /app && \
	mkdir -p /app/repos/tarballs && \
	mkdir /lib64 && \
	ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2

RUN curl -Ls http://install.convox.com/linux.tgz > convox.tgz && \
	tar -xzf convox.tgz -C /usr/bin && convox update && \
	rm convox.tgz

COPY Gemfile /app
COPY Gemfile.lock /app

ARG RACK_ENV
ENV RACK_ENV=${RACK_ENV:-development}

ENV CONVOX_HOST=console.convox.com

ARG CONVOX_ACCESS_TOKEN
ENV CONVOX_PASSWORD=${CONVOX_ACCESS_TOKEN}

RUN convox login

WORKDIR /app

COPY . /app  

RUN gem install bundler && \
	bundle install

# Our running command
CMD ["bundle","exec","puma","-C","config/puma.rb"]
