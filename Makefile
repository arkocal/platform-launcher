NAMESPACE?=oisp
SHELL:=/bin/bash

TEMPLATES_DIR?=templates

DEPLOYMENT?=debugger
DEBUGGER_POD:=$(shell kubectl -n $(NAMESPACE) get pods -o custom-columns=:metadata.name | grep debugger | head -n 1)
DASHBOARD_POD:=$(shell kubectl -n $(NAMESPACE) get pods -o custom-columns=:metadata.name | grep dashboard | head -n 1)
SELECTED_POD:=$(shell kubectl -n $(NAMESPACE) get pods -o custom-columns=:metadata.name | grep $(DEPLOYMENT) | head -n 1)

TEST_REPO?=https://github.com/Open-IoT-Service-Platform/platform-launcher.git
TEST_BRANCH?=develop

test-k8s:
	@$(call msg, "Testing on local k8s cluster");
	kafkacat -b kafka:9092 -t heartbeat

## import-debugger: Launch or update debugger pod in NAMESPACE (default:oisp)
##
import-debugger:
	kubectl apply -n $(NAMESPACE) -f $(TEMPLATES_DIR)/test

## .docker-cred: Remove this file if you need to update docker credentials
##
.docker-cred:
	@$(call msg, "(Re)creating docker credential secret.")
	@kubectl create namespace $(NAMESPACE) 2>/dev/null || echo Namespace $(NAMESPACE) already exists
	@kubectl -n $(NAMESPACE) delete secret dockercred 2>/dev/null ||:
	@read -p "Docker username:" DOCKER_USERNAME; \
	read -p "Docker e-mail:" DOCKER_EMAIL; \
	read -s -p "Docker password:" DOCKER_PASSWORD; \
	echo -e "\nTesting login"; \
	docker login -u $$DOCKER_USERNAME -p $$DOCKER_PASSWORD 2>/dev/null|| exit 1; \
	kubectl -n $(NAMESPACE) create secret docker-registry dockercred --docker-username=$$DOCKER_USERNAME --docker-password=$$DOCKER_PASSWORD --docker-email=$$DOCKER_EMAIL;
	@touch $@

## import-templates: Launch or update platform on k8s by importing the templates found in TEMPLATES_DIR
##     The resources will be loaded into NAMESPACE (default: oisp)
##
import-templates: .docker-cred
	@$(call msg, "Importing into namespace:$(NAMESPACE)")

	@kubectl create namespace $(NAMESPACE) || echo Namespace $(NAMESPACE) already exists

	kubectl apply -n $(NAMESPACE) -f $(TEMPLATES_DIR)/configmaps
	kubectl apply -n $(NAMESPACE) -f $(TEMPLATES_DIR)/secrets
	kubectl apply -n $(NAMESPACE) -f $(TEMPLATES_DIR)

## export-templates: Export templates in NAMESPACE in running k8s cluster to TEMPLATES_DIR
##     This does not follow the exact same directory structure as in import-templates
##
export-templates:
	@for n in $$(kubectl get -n $(NAMESPACE) -o=name pvc,configmap,secret,ingress,service,deployment,statefulset,hpa); do \
	mkdir -p $(TEMPLATES_DIR)/$$(dirname $$n); \
	kubectl get -n $(NAMESPACE) -o=yaml --export $$n > $(TEMPLATES_DIR)/$$n.yaml; \
	done

## clean: Remove all k8s resources by deleting namespace
##
clean:
	@$(call msg, "Removing workspace $(NAMESPACE)")
	-kubectl delete namespace $(NAMESPACE)
	rm -f .docker-cred

## open-shell: Open a shell to a random pod in DEPLOYMENT.
##     By default thi will try to open a shell to a debugger pod.
##
open-shell:
	@$(call msg, "Opening shell to pod: $(DEBUGGER_POD)")
	kubectl -n $(NAMESPACE) exec -it $(SELECTED_POD) /bin/bash

## reset-db: Reset database via admin tool in frontend
##
reset-db:
	kubectl -n $(NAMESPACE) exec $(DASHBOARD_POD) -- node admin resetDB

## add-test-user: Add a test user via admin tool in frontend
##
add-test-user:
	for i in $(shell seq 1 100); do kubectl -n $(NAMESPACE) exec $(DASHBOARD_POD) -- node admin addUser user$${i}@example.com password admin; done;


## prepare-tests: Pull the latest repo in the debugger pod
##     This has no permanent effect as the pod on which the tests
##     are prepared is mortal
prepare-tests:
	kubectl -n $(NAMESPACE) exec $(DEBUGGER_POD) -- /bin/bash -c "rm -rf *"
	kubectl -n $(NAMESPACE) exec $(DEBUGGER_POD) -- /bin/bash -c "rm -rf .* || true"
	kubectl -n $(NAMESPACE) exec $(DEBUGGER_POD) -- \
            git clone $(TEST_REPO) -b $(TEST_BRANCH) .

## Run tests
## Platform launcher will be cloned from TEST_REPO, branch TEST_BRANCH will be used
##
test: prepare-tests
	kubectl -n $(NAMESPACE) exec $(DEBUGGER_POD) -- make test TESTING_PLATFORM=kubernetes TERM=xterm
## help: Show this help message
##
help:
	@grep "^##" Makefile | cut -c4-

#---------------------------------------------------------------------------------------------------
# helper functions
#---------------------------------------------------------------------------------------------------

define msg
	tput setaf 2 && \
	for i in $(shell seq 1 120 ); do echo -n "-"; done; echo "" && \
	echo -e "\t"$1 && \
	for i in $(shell seq 1 120 ); do echo -n "-"; done; echo "" && \
	tput sgr0
endef
