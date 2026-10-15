# Atajos del repo. Uso: make help
SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

ENV      ?= dev
ENVS     := dev qa prod
TF       := terraform
PLATFORM := terraform/platform
BOOT     := terraform/bootstrap
VARS     := -var-file=../environments/common.tfvars -var-file=../environments/$(ENV)/terraform.tfvars

# gcloud y las credenciales de Terraform (ADC) de este proyecto, aisladas del resto de cuentas.
export CLOUDSDK_CONFIG ?= $(CURDIR)/.gcloud
export TF_PLUGIN_CACHE_DIR ?= $(HOME)/.terraform.d/plugin-cache

.PHONY: help check-env suffix bootstrap-init bootstrap-plan bootstrap-apply bootstrap-migrate \
        init plan apply destroy output test fmt lint checkov validate ci images

help: ## Esta ayuda
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

check-env:
	@[[ " $(ENVS) " == *" $(ENV) "* ]] || { echo "ENV debe ser uno de: $(ENVS)"; exit 1; }
	@! grep -rq SUFIJO terraform/environments/$(ENV) || { echo "Falta el sufijo: make suffix S=xxxx"; exit 1; }

suffix: ## Fija el sufijo de los IDs de proyecto en tfvars, backends y pipelines (S=xxxx)
	@[[ "$(S)" =~ ^[a-z0-9]{4,6}$$ ]] || { echo "Uso: make suffix S=<4-6 caracteres a-z0-9>"; exit 1; }
	grep -rl SUFIJO terraform/environments cicd | xargs sed -i 's/SUFIJO/$(S)/g'
	@echo "Sufijo $(S) aplicado."

# ---------- bootstrap (una vez, con tu usuario) ----------
bootstrap-init: ## Inicializa bootstrap (estado local la primera vez)
	cd $(BOOT) && $(TF) init

bootstrap-plan: ## Plan de bootstrap: proyectos, estado, registry, SAs de CI, presupuestos
	cd $(BOOT) && $(TF) plan -out=tfplan

bootstrap-apply: ## Aplica el plan de bootstrap
	cd $(BOOT) && $(TF) apply tfplan

bootstrap-migrate: ## Mueve el estado de bootstrap al bucket GCS creado
	cd $(BOOT)
	bucket=$$($(TF) output -raw state_bucket)
	cp backend.tf.example backend.tf
	$(TF) init -migrate-state -force-copy -backend-config="bucket=$$bucket"

# ---------- plataforma por ambiente ----------
init: check-env ## terraform init del ambiente (ENV=dev|qa|prod)
	cd $(PLATFORM) && $(TF) init -reconfigure -backend-config=../environments/$(ENV)/backend.hcl

plan: init ## Plan del ambiente
	cd $(PLATFORM) && $(TF) plan -out=tfplan-$(ENV) $(VARS)

apply: ## Aplica el último plan del ambiente
	cd $(PLATFORM) && $(TF) apply tfplan-$(ENV)

destroy: init ## Destruye el ambiente (prod pide confirmación escrita)
	@if [[ "$(ENV)" == prod ]]; then read -rp "Escribe 'destruir prod' para continuar: " c; [[ "$$c" == "destruir prod" ]]; fi
	cd $(PLATFORM) && $(TF) destroy $(VARS)

output: ## Salidas del ambiente (URL, IP, conexión SQL…)
	cd $(PLATFORM) && $(TF) output

# ---------- calidad (lo mismo que corre el pipeline de PR) ----------
fmt: ## Formatea todo el código Terraform
	$(TF) fmt -recursive terraform

validate: ## terraform validate de bootstrap y platform (sin backend)
	for d in $(BOOT) $(PLATFORM); do (cd $$d && $(TF) init -backend=false -input=false >/dev/null && $(TF) validate); done

test: ## Tests de plan con provider simulado para los 3 ambientes (sin GCP)
	cd $(PLATFORM) && $(TF) init -backend=false -input=false >/dev/null
	for e in $(ENVS); do echo "== $$e"; $(TF) test -var-file=../environments/common.tfvars -var-file=../environments/$$e/terraform.tfvars; done

lint: ## tflint
	tflint --init --config=$(CURDIR)/.tflint.hcl >/dev/null
	tflint --recursive --config=$(CURDIR)/.tflint.hcl --chdir=terraform

checkov: ## Análisis de seguridad del código Terraform
	checkov -d terraform --config-file .checkov.yaml

ci: ## Todo lo anterior en orden (fmt -check, validate, lint, checkov, test)
	$(TF) fmt -check -recursive terraform
	$(MAKE) --no-print-directory validate lint checkov test

images: ## Construye las 4 imágenes en local (tag local)
	for c in frontend api worker batch; do docker build -t pprov-local/$$c:dev app/$$c; done
