# Copyright 2021 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Short commit hash for kubeflow tar name
CURRENT_COMMIT_HASH = $(shell git branch --show-current)-$(shell git log -n 1 --format=%h)
# Default image and tag for kubeflow-install
KF_INSTALL_IMAGE ?= gcr.io/mapr-252711/kf-ecp-5.3.0/kubeflow-install
KF_INSTALL_TAG ?= latest-dev
KF_INSTALL_HASH_TAG = $(shell git branch --show-current)-$(shell git log -n 1 --format=%h)-$(shell git diff | shasum -a256 | cut -c -6)
# tar parameters for kubeflow-install-tarball
KF_INSTALL_ARCHIVE_NAME ?= kubeflow-$(CURRENT_COMMIT_HASH).tar
KF_INSTALL_ARCHIVE_PARAMS ?= -cf

# Create tarball from files used in bootstrap install script
kubeflow-install-tarball:
	mkdir -p build/_output/bootstrap/private-manifests
	cp -r bootstrap build/_output/bootstrap/private-manifests
	cp -r common build/_output/bootstrap/private-manifests
	cp -r apps build/_output/bootstrap/private-manifests
	cp -r contrib build/_output/bootstrap/private-manifests
	tar -C build/_output/bootstrap/ $(KF_INSTALL_ARCHIVE_PARAMS) $(KF_INSTALL_ARCHIVE_NAME) --exclude-vcs private-manifests/bootstrap \
						private-manifests/apps private-manifests/common private-manifests/contrib
	rm -r build

#Set variables for kf-installer-image(const)
vars-for-kf-installer-image:
	$(eval KF_INSTALL_ARCHIVE_PARAMS = -czf)
	$(eval KF_INSTALL_ARCHIVE_NAME = ./kf-installer/manifests.tar.gz)

# Create kf-installer images for kf-installer job
kf-installer-image: vars-for-kf-installer-image kubeflow-install-tarball
	docker build -t $(KF_INSTALL_IMAGE):$(KF_INSTALL_TAG) -t $(KF_INSTALL_IMAGE):$(KF_INSTALL_HASH_TAG) ./kf-installer
	rm -r $(KF_INSTALL_ARCHIVE_NAME)
	
	@echo Built $(KF_INSTALL_IMAGE):$(KF_INSTALL_TAG)
	@echo Built $(KF_INSTALL_IMAGE):$(KF_INSTALL_HASH_TAG)

# Push image with latest tag
push-latest-tag:
	docker push $(KF_INSTALL_IMAGE):$(KF_INSTALL_TAG)
	@echo Pushed $(KF_INSTALL_IMAGE):$(KF_INSTALL_TAG)

# Push image with branch hash tag
push-branch-tag:
	docker push $(KF_INSTALL_IMAGE):$(KF_INSTALL_HASH_TAG)
	@echo Pushed $(KF_INSTALL_IMAGE):$(KF_INSTALL_HASH_TAG)

# Push kf-installer images
push-all: push-latest-tag push-branch-tag
	@echo Pushed all

# Build and push kf-installer images
build-and-push-all: kf-installer-image push-all
	@echo Built and Pushed