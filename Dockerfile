FROM ubuntu:20.04

COPY . /root/blog/

RUN set -x; \
    echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted" > /etc/apt/sources.list \
    && echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted" >> /etc/apt/sources.list \
    && echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal universe" >> /etc/apt/sources.list \
    && echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates universe" >> /etc/apt/sources.list \
    && echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal multiverse" >> /etc/apt/sources.list \
    && echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates multiverse" >> /etc/apt/sources.list \
    && echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse" >> /etc/apt/sources.list \
    && echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security main restricted" >> /etc/apt/sources.list \
    && echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security universe" >> /etc/apt/sources.list \
    && echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security multiverse" >> /etc/apt/sources.list \
    && apt update && apt install -y ruby-full build-essential zlib1g-dev \
    && apt clean && rm -rf /var/lib/apt/lists/* \
    && gem sources --remove https://rubygems.org/ \
    && gem sources -a https://gems.ruby-china.com/ \
    && gem install bundler \
    && cd /root/blog \
    && bundle install \
    && cd / \
    && rm -rf /root/blog