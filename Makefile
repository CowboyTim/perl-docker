REMOTE_DOCKER_REGISTRY     ?= docker_build_$(USER)
DOCKER_REGISTRY            ?= aardbeiplantje
DOCKER_REPOSITORY          ?= $(REMOTE_DOCKER_REGISTRY)/$(DOCKER_REGISTRY)
REMOTE_DOCKER_REPOSITORY   ?= $(DOCKER_REGISTRY)
DOCKER_IMAGE_TAG           ?= dev
YUM_BASE                   ?=
YUM_URL                    ?= file:///
GPG_URL                    ?= file:///
TMPDIR                     ?= /tmp/tmp_$(USER)
PERL_VERSION               ?= 5.32.0
PERL_AWS_LAMBDA_LAYER      ?= perl-5_32_0-runtime

all: perl_docker

.PHONY: perl_docker

perl_docker: build_docker.perl-dev build_docker.perl docker_tag_perl docker_prune

deploy: aws_lambda_layer_runtime_zip publish_aws_lambda_layer_runtime_zip

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

build_docker.perl-lambda-dev:
		docker build \
			./dockers/perl-lambda-dev \
			-f ./dockers/perl-lambda-dev/Dockerfile \
			--network host \
			$(DOCKER_OPTS) \
			--build-arg docker_registry=$(DOCKER_REGISTRY) \
			--build-arg remote_docker_registry=$(REMOTE_DOCKER_REGISTRY)/ \
			--build-arg YUM_URL=$(YUM_URL) \
			--build-arg YUM_BASE=$(YUM_BASE) \
			--build-arg GPG_URL=$(GPG_URL) \
			--cache-from $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-lambda-dev-latest \
			--tag $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-lambda-dev-latest \
			$(EXTRA_DOCKER_OPTS)

build_docker.perl-lambda:
		docker build \
			./dockers/perl-lambda \
			-f ./dockers/perl-lambda/Dockerfile \
			--network host \
			$(DOCKER_OPTS) \
			--build-arg docker_registry=$(DOCKER_REGISTRY) \
			--build-arg remote_docker_registry=$(REMOTE_DOCKER_REGISTRY)/ \
			--build-arg YUM_URL=$(YUM_URL) \
			--build-arg YUM_BASE=$(YUM_BASE) \
			--build-arg GPG_URL=$(GPG_URL) \
			--cache-from $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-lambda-latest \
			--tag $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-lambda-latest \
			$(EXTRA_DOCKER_OPTS)

docker_tag_perl:
		   docker tag $(DOCKER_REPOSITORY)/perl:latest $(REMOTE_DOCKER_REPOSITORY)/perl:$(PERL_VERSION) \
		&& docker tag $(DOCKER_REPOSITORY)/perl:latest $(REMOTE_DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-latest \
		&& docker tag $(DOCKER_REPOSITORY)/perl:latest $(REMOTE_DOCKER_REPOSITORY)/perl:latest \
		&& docker tag $(DOCKER_REPOSITORY)/perl:latest $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION) \
		&& docker tag $(DOCKER_REPOSITORY)/perl:latest $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-latest \
		&& docker tag $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-dev-latest $(REMOTE_DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-dev-latest

save_lambda_docker.perl-lambda: perl_docker build_docker.perl-lambda-dev build_docker.perl-lambda docker_prune
		cd $(TMPDIR)/tmpdist/ && (docker save $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-lambda-latest \
				|tar xfO - --wildcards '*/layer.tar'|tar xf -) \
		&& chmod -R +w $(TMPDIR)/tmpdist/

aws_lambda_layer_runtime_zip: mkdist copy_bootstrap save_lambda_docker.perl-lambda
		cd $(TMPDIR)/tmpdist/ && zip -r --symlinks $(TMPDIR)/dist/perl-lambda-runtime.zip *

publish_aws_lambda_layer_runtime_zip:
		aws lambda publish-layer-version \
				--layer-name $(PERL_AWS_LAMBDA_LAYER) \
				--description 'This is the PERL $(PERL_VERSION) Lambda runtime' \
				--license-info "MIT" \
				--compatible-runtimes provided.al2 \
				--zip-file fileb://$(TMPDIR)/dist/perl-lambda-runtime.zip

copy_bootstrap:
		cp dockers/perl-lambda/bootstrap.lambda.pl dockers/perl-lambda/bootstrap $(TMPDIR)/tmpdist/ && chmod +x $(TMPDIR)/tmpdist/bootstrap*

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

