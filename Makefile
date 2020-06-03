CWD := $(shell pwd)
NAME := $(shell jq -r .name META6.json)
VERSION := $(shell jq -r .version META6.json)
ARCHIVENAME := $(subst ::,-,$(NAME))

build:
	./Build.rakumod -v

check:
	git diff-index --check HEAD
	prove6

tag:
	git tag $(VERSION)
	git push origin --tags

dist:
	git archive --prefix=$(ARCHIVENAME)-$(VERSION)/ \
		-o ../$(ARCHIVENAME)-$(VERSION).tar.gz $(VERSION)

clean:
	rm -fr resources

test-alpine:
	make clean
	docker run --rm -t  \
	  -e ALL_TESTING=1 \
	  -v $(CWD):/test \
          --entrypoint="/bin/sh" \
	  jjmerelo/raku-test \
	  -c "apk add --update --no-cache g++ && zef install --/test --deps-only --test-depends . && zef -v build . && zef -v test ."

test-debian:
	make clean
	docker run --rm -t \
	  -e ALL_TESTING=1 \
	  -v $(CWD):/test -w /test \
          --entrypoint="/bin/sh" \
	  jjmerelo/rakudo-nostar \
	  -c "echo deb http://ftp.us.debian.org/debian testing main contrib non-free >> /etc/apt/sources.list && apt update && apt install -y g++ && zef install --/test --deps-only --test-depends . && zef -v build . && zef -v test ."

test-ubuntu:
	docker run --rm -t \
	  -e ALL_TESTING=1 \
	  -v $(CWD):/tmp/test -w /tmp/test \
	  tonyodell/rakudo-nightly:latest \
	  bash -c 'zef install --/test --deps-only --test-depends . && zef -v test .'

test-centos:
	make clean
	docker run --rm -t \
	  -e ALL_TESTING=1 \
	  -v $(CWD):/test -w /test \
          --entrypoint="/bin/bash" \
	  centos:latest \
	  -c "yum install -y gcc-c++ wget curl git && wget https://dl.bintray.com/nxadm/rakudo-pkg-rpms/CentOS/8/x86_64/rakudo-pkg-CentOS8-2020.02.1-04.x86_64.rpm && yum install -y rakudo-pkg-CentOS8-2020.02.1-04.x86_64.rpm && rm rakudo-pkg-CentOS8-2020.02.1-04.x86_64.rpm && source ~/.bashrc && zef install --/test --deps-only --test-depends . && zef -v build . && zef -v test ."

test: test-alpine test-debian test-ubuntu test-centos
