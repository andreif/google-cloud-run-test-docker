# Note: It expects env var PROJECT to be set before running make commands!
# Example:  PROJECT=my-project-123456  make setup build-and-deploy

REGION = europe-west1
ZONE = b
REPO = test-repo
APP = test-app
APP_IMG = ${REGION}-docker.pkg.dev/${PROJECT}/${REPO}/${APP}:latest
SERVICE = test-service


###  SETUP CLI

GCLOUD_IMG = gcr.io/google.com/cloudsdktool/google-cloud-cli:alpine
GCLOUD_CONTAINER = gcloud
GCLOUD_EXEC = docker exec -ti ${GCLOUD_CONTAINER}
GCLOUD = ${GCLOUD_EXEC} gcloud
PLATFORM = $(shell uname -m | grep -q 'arm64' && echo '--platform linux/arm64')

setup:  auth  config-set  config-list
auth:  remove-existing-container
	docker run -ti ${PLATFORM} -v .:/app -w /app --name ${GCLOUD_CONTAINER} ${GCLOUD_IMG} gcloud auth login --brief
	docker start ${GCLOUD_CONTAINER}
remove-existing-container:
	@docker rm -f ${GCLOUD_CONTAINER} 2>/dev/null || true
config-set:
	test -n "${PROJECT}" || (echo "PROJECT env var not set"; exit 1)
	${GCLOUD} config set core/project ${PROJECT}
	${GCLOUD} config set compute/region ${REGION}
	${GCLOUD} config set compute/zone ${REGION}-$(subst ${REGION}-,,${ZONE})
	@echo
	make config-list
config-list:
	${GCLOUD} config list


###  BUILD AND DEPLOY

PROJECT_NUMBER = $(shell ${GCLOUD} projects describe ${PROJECT} --format='value(projectNumber)')
SERVICE_ACCOUNT = ${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
COMPUTE_ACCOUNT = ${PROJECT_NUMBER}-compute@developer.gserviceaccount.com

repo-create:
	${GCLOUD} artifacts repositories list --location=${REGION} | grep -q ${REPO} || \
	${GCLOUD} artifacts repositories create ${REPO} --project=${PROJECT} --repository-format=docker --location=${REGION}

repo-list:
	${GCLOUD} artifacts repositories list

build:
	${GCLOUD} builds submit --region=${REGION} --tag ${APP_IMG}

grant-run-admin:  # Grant the Cloud Run Admin role to the Cloud Build service account
	${GCLOUD} projects add-iam-policy-binding ${PROJECT} \
		--member=serviceAccount:${SERVICE_ACCOUNT} --role=roles/run.admin

grant-service:  # Grant the IAM Service Account User role to the Cloud Build service account for the Cloud Run runtime service account
	${GCLOUD} iam service-accounts add-iam-policy-binding ${COMPUTE_ACCOUNT} \
		--member=serviceAccount:${SERVICE_ACCOUNT} --role=roles/iam.serviceAccountUser

deploy:
	${GCLOUD} run deploy ${SERVICE} --image ${APP_IMG} --region ${REGION} --platform managed --allow-unauthenticated

build-and-deploy:  repo-create  build  grant-run-admin  grant-service  deploy


### LOCAL

LOCAL_IMG = ${APP_IMG}-local
local-run:
	docker build ${PLATFORM} -t ${LOCAL_IMG} .
	docker run ${PLATFORM} --rm -ti -p 8080:8080 --name ${APP}-local ${LOCAL_IMG}
