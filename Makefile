USER                       ?= builduser
DOCKER_LOCAL               ?= docker_build_$(USER)
DOCKER_REGISTRY            ?= aardbeiplantje
REMOTE_DOCKER_REGISTRY     ?= $(DOCKER_LOCAL)
DOCKER_REPOSITORY          ?= $(DOCKER_LOCAL)/$(DOCKER_REGISTRY)
REMOTE_DOCKER_REPO         ?= $(REMOTE_DOCKER_REGISTRY)/$(DOCKER_REGISTRY)
PERL_VERSION               ?= 5.32.0
LATEST_TAG                 ?= :latest

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
			--cache-from $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-dev-latest \
			--tag $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-dev-latest \
			--tag $(DOCKER_REGISTRY)/perl:$(PERL_VERSION)-dev-latest \
			$(EXTRA_DOCKER_OPTS)
			$(EXTRA_DOCKER_OPTS)

docker_tag_perl:
		   docker tag $(DOCKER_REPOSITORY)/perl:latest $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION) \
		&& docker tag $(DOCKER_REPOSITORY)/perl:latest $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-latest

docker_push_perl:
		   docker tag $(DOCKER_REPOSITORY)/perl:latest $(REMOTE_DOCKER_REPO)/perl:$(PERL_VERSION) \
		&& docker tag $(DOCKER_REPOSITORY)/perl:latest $(REMOTE_DOCKER_REPO)/perl:$(PERL_VERSION)-latest \
		&& docker tag $(DOCKER_REPOSITORY)/perl:latest $(REMOTE_DOCKER_REPO)/perl:latest \
		&& docker tag $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-dev-latest $(REMOTE_DOCKER_REPO)/perl:$(PERL_VERSION)-dev-latest \
		&& docker push $(REMOTE_DOCKER_REPO)/perl:$(PERL_VERSION) \
		&& docker push $(REMOTE_DOCKER_REPO)/perl:$(PERL_VERSION)-latest \
		&& docker push $(REMOTE_DOCKER_REPO)/perl:latest \
		&& docker push $(REMOTE_DOCKER_REPO)/perl:$(PERL_VERSION)-dev-latest

docker_prune:
		docker image prune -f

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
			--cache-from $(DOCKER_REPOSITORY)/$*$(LATEST_TAG) \
			--tag $(DOCKER_REPOSITORY)/$*$(LATEST_TAG) \
			$(EXTRA_DOCKER_OPTS)
