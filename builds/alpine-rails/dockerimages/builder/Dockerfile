# See https://gist.github.com/jonyardley/47f6bd8847c860f68ed7e0fa463d6d23
# Usage: docker build --build-arg="ASSET_HOST=http://mycdn/path-to-assets" .
# FROM ruby:2.3.5-alpine as builder
FROM ruby:2.3.5-alpine

ENV LANG ja_JP.UTF-8

# bundler 1.16.0 + rubygems >2.7.2でbundle envが以下のようなエラーで落ちてしまうバグを踏んだことがあったので、
# 同じようなことがないようにそれぞれバージョンを固定する。
#   2.3.0/bundler/build_metadata.rb:27:in ``': No such file or directory - git (Errno::ENOENT)
# 固定しておかないと、docker buildの再現性がなくなる。
# 言い換えると、同じDockerfileの内容でもdocker buildをしたタイミング次第で異なるイメージができてしまい、それがアプリの動作に影響する可能性がある。
# このようにバージョンを固定してしまうと新バージョンへの追従が面倒だが、それはそれで別途自動化したほうがよいと判断。
RUN gem update --system 2.7.4
RUN gem install bundler -v 1.16.1

# mysql-devはmysql2 gemが必要とするlibmysqlclient.soのために必要
# でもmysqlやmysqldが不要なので消すために
#   rm -rf /usr/local/bin/mysql*
# を実行している。
# かつ、それを同じRUN行で実行しないと、rmしてもDockerレイヤーが残ってDockerイメージサイズが減らない
RUN apk --update add bash git tzdata \
  libxml2 libxslt mysql-dev nodejs \
  && rm -rf /usr/bin/mysql*

RUN apk --update add --virtual build-dependencies openssh git build-base ruby-dev openssl-dev tzdata \
  libxml2-dev libxslt-dev ruby-bundler libc-dev linux-headers mysql-dev curl

ENV YARN_VERSION 1.3.2
RUN mkdir -p /opt \
  && curl -L https://github.com/yarnpkg/yarn/releases/download/v${YARN_VERSION}/yarn-v${YARN_VERSION}.tar.gz | tar zx -C /opt \
  && ln -s /opt/yarn-v${YARN_VERSION}/bin/yarn /usr/local/bin/

COPY deploy/git-credential-github-token /usr/local/bin
#RUN git config --global url."https://github.com/".insteadOf ssh://git@github.com/ \
#  && git config --global credential.helper github-token

# 以下3つの環境変数は公式Dockerイメージで設定されているもの
#
# これがあると、bundle install --deploymentでつくっておいたvendor/bundleを読んでくれないので、
# 以下のように適切な値に上書きする必要がある
#
# 参考:
#   https://github.com/bundler/bundler/issues/5068#issuecomment-259594603 for more details
#
# BUNDLE_APP_CONFIG:
#   Docker公式rubyイメージだとBUNDLE_APP_CONFIGがデフォルトで
#     /usr/local/bundle
#   となっているため、bundle exec等のためにvendor/bundleと一緒に必要なconfigというファイルが
#     /usr/local/bundle/config
#   に書き出されてしまう。
#   unsetできればよいが、DockerfileにはENVとついになるUNSETENVのような命令はないので、明示的によいデフォルト値に上書きする
ENV BUNDLE_APP_CONFIG=.bundle
# bundle install --deploymentでgemがインストールされる先のディレクトリ
# bundlerのデフォルトはvendor/bundle、公式イメージのデフォルトは/usr/local/bundleなので、驚き最小化のためvendor/bundleに戻す
ENV BUNDLE_PATH=vendor/bundle
# bundle exec <実行可能ファイル>するときに、実行可能ファイルを探しにいくディレクトリへのパス
# bundlerのデフォルトはシステムのruby環境のbin、次にvendor/bundle/ruby/$RUBY_VERSION.0/binのようだ（半分予想）
# unsetしたいができないので、それっぽいデフォルト値に上書きしておく
ENV BUNDLE_BIN=$BUNDLE_PATH/ruby/$RUBY_VERSION.0/bin

RUN bundle config build.nokogiri --use-system-libraries
