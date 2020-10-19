DOCKER_REGISTRY    ?= docker_build_$(USER)
DOCKER_REPOSITORY  ?= $(DOCKER_REGISTRY)/thuisdockers
DOCKER_IMAGE_TAG   ?= dev
YUM_BASE           ?= 8
YUM_URL            ?= file:///
GPG_URL            ?= file:///
TMPDIR             ?= /tmp/tmp_$(USER)
CI_COMMIT_REF_SLUG ?= latest

all: perl_docker

.PHONY: perl_docker

perl_docker: build_docker.base-sandbox build_docker.stage-sandbox build_docker.perl-sandbox

aws_lambda_perl_runtime: perl_docker docker_prune clean mkdist copy_bootstrap docker_save.perl-sandbox aws_lambda_layer_runtime_zip

deploy: aws_lambda_perl_runtime publish_aws_lambda_layer_runtime_zip_terraform

build_docker.%:
		# Pull by commit ref slug so we get the latest on this branch
		docker pull $*:$(CI_COMMIT_REF_SLUG) || true
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

docker_tag.%:
		docker tag $(DOCKER_REGISTRY)/perl-sandbox:latest $(DOCKER_REGISTRY)/$*:latest

docker_save.%: mkdist
		cd $(TMPDIR)/tmpdist/ && (docker save $(DOCKER_REGISTRY)/$*:latest|tar xfO - --wildcards '*/layer.tar'|tar xf -) && chmod -R +w $(TMPDIR)/tmpdist/

save_lambda_docker.%: perl_docker build_docker.perl-lambda-dev-sandbox build_docker.perl-lambda
		cd $(TMPDIR)/tmpdist/ && (docker save $(DOCKER_REGISTRY)/$*:latest|tar xfO - --wildcards '*/layer.tar'|tar xf -) && chmod -R +w $(TMPDIR)/tmpdist/

aws_lambda_layer_runtime_zip: mkdist copy_bootstrap save_lambda_docker.perl-lambda
		cd $(TMPDIR)/tmpdist/ && zip -r --symlinks $(TMPDIR)/dist/perl-lambda-runtime.zip *

publish_aws_lambda_layer_runtime_zip:
		aws lambda publish-layer-version \
                                --layer-name perl-runtime \
                                --description 'This is the PERL Lambda runtime' \
                                --zip-file fileb://$(TMPDIR)/dist/perl-lambda-runtime.zip

publish_aws_lambda_layer_runtime_zip_terraform:
		cd tf && terraform init && terraform apply -input=false -auto-approve -var="perl_lambda_runtime_zip=$(TMPDIR)/dist/perl-lambda-runtime.zip"

publish_new_runtime: clean mkdist copy_bootstrap docker_save.perl-sandbox aws_lambda_layer_runtime_zip publish_aws_lambda_layer_runtime_zip_terraform

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

