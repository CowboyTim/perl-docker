DOCKER_REGISTRY    ?= docker_build_$(USER)
DOCKER_REPOSITORY  ?= $(DOCKER_REGISTRY)/thuisdockers
DOCKER_IMAGE_TAG   ?= dev
YUM_BASE           ?= 8
YUM_URL            ?= file:///
GPG_URL            ?= file:///
TMPDIR             ?= /tmp/tmp_$(USER)

PERL_VERSION          ?= 5.32.0
PERL_AWS_LAMBDA_LAYER ?= perl-5_32_0-runtime

all: perl_docker

.PHONY: perl_docker

perl_docker: build_docker.base-sandbox build_docker.stage-sandbox build_docker.perl-sandbox perl_docker_tag.perl-sandbox

aws_lambda_perl_runtime: aws_lambda_layer_runtime_zip

deploy: aws_lambda_perl_runtime publish_aws_lambda_layer_runtime_zip

build_docker.%:
		docker build \
			./dockers/$* \
			-f ./dockers/$*/Dockerfile \
			--network host \
			$(DOCKER_OPTS) \
			--build-arg docker_registry=$(DOCKER_REGISTRY)/ \
			--build-arg YUM_URL=$(YUM_URL) \
			--build-arg YUM_BASE=$(YUM_BASE) \
			--build-arg GPG_URL=$(GPG_URL) \
			--cache-from $(DOCKER_REGISTRY)/$*:latest \
			--tag $(DOCKER_REGISTRY)/$*:latest \
			$(EXTRA_DOCKER_OPTS)

perl_docker_tag.%:
		docker tag $(DOCKER_REGISTRY)/$*:latest $(DOCKER_REGISTRY)/perl:latest
		docker tag $(DOCKER_REGISTRY)/$*:latest $(DOCKER_REGISTRY)/perl:$(PERL_VERSION)

docker_save.%: mkdist
		cd $(TMPDIR)/tmpdist/ && (docker save $(DOCKER_REGISTRY)/$*:latest|tar xfO - --wildcards '*/layer.tar'|tar xf -) && chmod -R +w $(TMPDIR)/tmpdist/

save_lambda_docker.%: perl_docker build_docker.perl-lambda-dev-sandbox build_docker.perl-lambda
		cd $(TMPDIR)/tmpdist/ && (docker save $(DOCKER_REGISTRY)/$*:latest|tar xfO - --wildcards '*/layer.tar'|tar xf -) && chmod -R +w $(TMPDIR)/tmpdist/

aws_lambda_layer_runtime_zip: mkdist copy_bootstrap save_lambda_docker.perl-lambda
		cd $(TMPDIR)/tmpdist/ && zip -r --symlinks $(TMPDIR)/dist/perl-lambda-runtime.zip *

publish_aws_lambda_layer_runtime_zip:
		aws lambda publish-layer-version \
				--layer-name $(PERL_AWS_LAMBDA_LAYER) \
				--description 'This is the PERL $(PERL_VERSION) Lambda runtime' \
				--license-info "MIT" \
				--compatible-runtimes provided.al2 \
				--zip-file fileb://$(TMPDIR)/dist/perl-lambda-runtime.zip

publish_new_runtime: clean mkdist copy_bootstrap docker_save.perl-sandbox aws_lambda_layer_runtime_zip publish_aws_lambda_layer_runtime_zip

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

