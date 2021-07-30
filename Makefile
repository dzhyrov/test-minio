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

# Create tarball from files used in bootstrap install script
kubeflow-install-tarball:
	mkdir -p build/_output/bootstrap/private-manifests
	cp -r bootstrap build/_output/bootstrap/private-manifests
	cp -r common build/_output/bootstrap/private-manifests
	cp -r apps build/_output/bootstrap/private-manifests
	cp -r contrib build/_output/bootstrap/private-manifests
	tar -C build/_output/bootstrap/ -cvf kubeflow-$(CURRENT_COMMIT_HASH).tar --exclude-vcs private-manifests/bootstrap \
						private-manifests/apps private-manifests/common private-manifests/contrib
	rm -r build
