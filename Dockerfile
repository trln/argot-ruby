ARG RUBY_VERSION=2.7

FROM ruby:$RUBY_VERSION AS builder

RUN apt-get update && apt-get install -y libyajl2 curl redis-tools && apt-get -y upgrade

FROM builder
