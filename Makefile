DOCKER_LOCAL               ?= docker_build_$(USER)
DOCKER_REPO                ?= $(DOCKER_LOCAL)
DOCKER_REGISTRY            ?= aardbeiplantje
REMOTE_DOCKER_REGISTRY     ?= $(DOCKER_LOCAL)
DOCKER_REPOSITORY          ?= $(DOCKER_LOCAL)/$(DOCKER_REGISTRY)
REMOTE_DOCKER_PUSH         ?= $(DOCKER_REGISTRY)
DOCKER_IMAGE_TAG           ?= dev
YUM_BASE                   ?=
YUM_URL                    ?= file:///
GPG_URL                    ?= file:///
TMPDIR                     ?= /tmp/tmp_$(USER)
PERL_VERSION               ?= 5.32.0

all: perl_docker

.PHONY: perl_docker

perl_docker: build_docker.perl-dev build_docker.perl docker_tag_perl docker_prune

build_docker.perl-dev:
		docker build \
			./dockers/perl-dev \
			-f ./dockers/perl-dev/Dockerfile \
			--network host \
			$(DOCKER_OPTS) \
			--build-arg docker_registry=$(DOCKER_REGISTRY) \
			--build-arg remote_docker_registry=$(REMOTE_DOCKER_REGISTRY)/ \
			--build-arg YUM_URL=$(YUM_URL) \
			--build-arg YUM_BASE=$(YUM_BASE) \
			--build-arg GPG_URL=$(GPG_URL) \
			--cache-from $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-dev-latest \
			--tag $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-dev-latest \
			$(EXTRA_DOCKER_OPTS)

docker_tag_perl:
		   docker tag $(DOCKER_REPOSITORY)/perl:latest $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION) \
		&& docker tag $(DOCKER_REPOSITORY)/perl:latest $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-latest

docker_push_perl:
		   docker tag $(DOCKER_REPOSITORY)/perl:latest $(REMOTE_DOCKER_PUSH)/perl:$(PERL_VERSION) \
		&& docker tag $(DOCKER_REPOSITORY)/perl:latest $(REMOTE_DOCKER_PUSH)/perl:$(PERL_VERSION)-latest \
		&& docker tag $(DOCKER_REPOSITORY)/perl:latest $(REMOTE_DOCKER_PUSH)/perl:latest \
		&& docker tag $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-dev-latest $(REMOTE_DOCKER_PUSH)/perl:$(PERL_VERSION)-dev-latest \
		&& docker push $(REMOTE_DOCKER_PUSH)/perl:$(PERL_VERSION) \
		&& docker push $(REMOTE_DOCKER_PUSH)/perl:$(PERL_VERSION)-latest \
		&& docker push $(REMOTE_DOCKER_PUSH)/perl:latest \
		&& docker push $(REMOTE_DOCKER_PUSH)/perl:$(PERL_VERSION)-dev-latest

docker_prune:
		docker image prune -f

mkdist: clean
		mkdir -p $(TMPDIR)/dist/ $(TMPDIR)/tmpdist/

clean: cleandist cleantmpdist

cleandist:
		if [ -d $(TMPDIR)/dist/ ]; then chmod -R +w $(TMPDIR)/dist/; rm -rf $(TMPDIR)/dist/; fi

cleantmpdist:
		if [ -d $(TMPDIR)/tmpdist/ ]; then chmod -R +w $(TMPDIR)/tmpdist/; rm -rf $(TMPDIR)/tmpdist/; fi


# general
build_docker.%:
		docker build \
			./dockers/$* \
			-f ./dockers/$*/Dockerfile \
			--network host \
			$(DOCKER_OPTS) \
			--build-arg docker_registry=$(DOCKER_REGISTRY) \
			--build-arg remote_docker_registry=$(REMOTE_DOCKER_REGISTRY)/ \
			--build-arg perl_version=$(PERL_VERSION) \
			--build-arg YUM_URL=$(YUM_URL) \
			--build-arg YUM_BASE=$(YUM_BASE) \
			--build-arg GPG_URL=$(GPG_URL) \
			--cache-from $(DOCKER_REPOSITORY)/$*:latest \
			--tag $(DOCKER_REPOSITORY)/$*:latest \
			$(EXTRA_DOCKER_OPTS)

docker_save.%: mkdist
		cd $(TMPDIR)/tmpdist/ && (docker save $(DOCKER_REGISTRY)/$*:latest|tar xfO - --wildcards '*/layer.tar'|tar xf -) && chmod -R +w $(TMPDIR)/tmpdist/

