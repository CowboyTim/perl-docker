DOCKER_LOCAL               ?= docker_build_$(USER)
DOCKER_REGISTRY            ?= aardbeiplantje
REMOTE_DOCKER_REGISTRY     ?= $(DOCKER_LOCAL)
DOCKER_REPOSITORY          ?= $(DOCKER_LOCAL)/$(DOCKER_REGISTRY)
REMOTE_DOCKER_REPO         ?= $(REMOTE_DOCKER_REGISTRY)/$(DOCKER_REGISTRY)
TMPDIR                     ?= /tmp/tmp_$(USER)
PERL_VERSION               ?= 5.32.0
PERL_AWS_LAMBDA_LAYER      ?= perl-5_32_0-runtime
LATEST_TAG                 ?= :latest

all: lambda

.PHONY: lambda

perl_docker: build_docker.perl-dev build_docker.perl docker_tag_perl docker_prune

publishlambda: publish_aws_lambda_layer_runtime_zip
lambda: build_docker.perl-dev aws_lambda_layer_runtime_zip

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

fetch_build_docker.perl-dev: docker_local_tag_pull_perl_dev docker_remote_tag_pull_perl_dev

docker_remote_pull_perl_dev:
	    docker image inspect $(REMOTE_DOCKER_REPO)/perl:$(PERL_VERSION)-dev-latest >/dev/null 2>&1 \
		|| docker pull $(REMOTE_DOCKER_REPO)/perl:$(PERL_VERSION)-dev-latest \
		|| exit 0

docker_local_pull_perl_dev:
		docker image inspect $(DOCKER_REGISTRY)/perl:$(PERL_VERSION)-dev-latest >/dev/null 2>&1 \
	    || docker pull $(DOCKER_REGISTRY)/perl:$(PERL_VERSION)-dev-latest \
		|| exit 0

docker_remote_tag_pull_perl_dev: docker_remote_pull_perl_dev
		docker tag $(REMOTE_DOCKER_REPO)/perl:$(PERL_VERSION)-dev-latest $(DOCKER_REGISTRY)/perl:$(PERL_VERSION)-dev-latest || exit 0

docker_local_tag_pull_perl_dev: docker_local_pull_perl_dev
		docker tag $(DOCKER_REGISTRY)/perl:$(PERL_VERSION)-dev-latest $(REMOTE_DOCKER_REPO)/perl:$(PERL_VERSION)-dev-latest || exit 0

build_docker.perl-lambda-dev: fetch_build_docker.perl-dev
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

build_docker.perl-lambda: build_docker.perl-lambda-dev
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

save_lambda_docker.perl-lambda: cleantmpdist mkdist build_docker.perl-lambda docker_prune
	    (cd $(TMPDIR)/tmpdist/ || exit 1; \
        did=$$(docker create $(DOCKER_REPOSITORY)/perl:$(PERL_VERSION)-lambda-latest); \
        docker export $$did|tar xf -; \
        docker rm -f $$did; \
        chmod -R +w $(TMPDIR)/tmpdist/; \
        rm -rf proc dev sys .dockerenv etc)

aws_lambda_layer_runtime_zip: cleandist mkdist copy_bootstrap save_lambda_docker.perl-lambda
		(cd $(TMPDIR)/tmpdist/ && zip -r --symlinks $(TMPDIR)/dist/perl-lambda-runtime.zip *) \
		&& rm -rf dist/ \
		&& mkdir dist/ \
		&& mv $(TMPDIR)/dist/perl-lambda-runtime.zip ./dist/perl-lambda-runtime-$(PERL_VERSION).zip \
		&& rm -rf $(TMPDIR)/tmpdist/ \
		&& echo lambda zip is made in `pwd`/dist/perl-lambda-runtime-$(PERL_VERSION).zip

publish_aws_lambda_layer_runtime_zip:
		aws lambda publish-layer-version \
				--layer-name $(PERL_AWS_LAMBDA_LAYER) \
				--description 'This is the PERL $(PERL_VERSION) Lambda runtime' \
				--license-info "MIT" \
				--compatible-runtimes provided.al2 \
				--zip-file fileb://./dist/perl-lambda-runtime-$(PERL_VERSION).zip

copy_bootstrap:
		cp dockers/perl-lambda/bootstrap.lambda.* dockers/perl-lambda/bootstrap $(TMPDIR)/tmpdist/ && chmod +x $(TMPDIR)/tmpdist/bootstrap*

docker_prune:
		docker image prune -f

mkdist: clean
		@mkdir -p $(TMPDIR)/dist/ $(TMPDIR)/tmpdist/ ./dist

clean: cleandist cleantmpdist
		@if [ -d ./dist/ ]; then chmod -R +w ./dist/; rm -rf ./dist/; fi
		@if [ -d $(TMPDIR) ]; then rmdir $(TMPDIR) 2>/dev/null; fi

cleandist:
		@if [ -d $(TMPDIR)/dist/ ]; then chmod -R +w $(TMPDIR)/dist/; rm -rf $(TMPDIR)/dist/; fi

cleantmpdist:
		@if [ -d $(TMPDIR)/tmpdist/ ]; then chmod -R +w $(TMPDIR)/tmpdist/; rm -rf $(TMPDIR)/tmpdist/; fi

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

