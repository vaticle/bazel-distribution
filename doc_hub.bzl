#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

# File which loads *all* rules to make them visible for doc generation
# Rules *do* need to be reexported because otherwise they are not visible

load("//apt:rules.bzl", _assemble_apt = "assemble_apt", _deploy_apt = "deploy_apt")

load("//aws:rules.bzl", _assemble_aws = "assemble_aws")

load("//azure:rules.bzl", _assemble_azure = "assemble_azure")

load("//brew:rules.bzl", _deploy_brew = "deploy_brew")

load("//common/assemble_versioned:rules.bzl", _assemble_versioned = "assemble_versioned")

load("//common/checksum:rules.bzl", _checksum = "checksum")

load("//common/generate_json_config:rules.bzl", _generate_json_config = "generate_json_config")

load("//common/java_deps:rules.bzl",
    _MAVEN_COORDINATES_PREFIX = "MAVEN_COORDINATES_PREFIX",
    _JarToMavenCoordinatesMapping = "JarToMavenCoordinatesMapping",
    _TransitiveJarToMavenCoordinatesMapping = "TransitiveJarToMavenCoordinatesMapping",
    _java_deps = "java_deps",
)

load("//common:rules.bzl", _assemble_targz = "assemble_targz", _assemble_zip = "assemble_zip")

load("//common/tgz2zip:rules.bzl", _tgz2zip = "tgz2zip")

load("//crates:rules.bzl", _assemble_crate = "assemble_crate", _deploy_crate = "deploy_crate")

load("//docs:cpp/rules.bzl", _doxygen_docs = "doxygen_docs")
load("//docs:python/rules.bzl", _sphinx_docs = "sphinx_docs")

load("//gcp:rules.bzl", _assemble_gcp = "assemble_gcp")

load('//github:rules.bzl', _deploy_github = "deploy_github")

load('//maven:rules.bzl',
    _JarInfo = "JarInfo",
    _MavenDeploymentInfo = "MavenDeploymentInfo",
    _assemble_maven = "assemble_maven",
    _deploy_maven = "deploy_maven",
)

load("//npm:rules.bzl", _assemble_npm = "assemble_npm", _deploy_npm = "deploy_npm")

load("//packer:rules.bzl", _assemble_packer = "assemble_packer", _deploy_packer = "deploy_packer")

load("//pip:rules.bzl", _assemble_pip = "assemble_pip", _deploy_pip = "deploy_pip")

assemble_apt = _assemble_apt
deploy_apt = _deploy_apt

assemble_aws = _assemble_aws

assemble_azure = _assemble_azure

deploy_brew = _deploy_brew

assemble_versioned = _assemble_versioned

checksum = _checksum

generate_json_config = _generate_json_config

MAVEN_COORDINATES_PREFIX = _MAVEN_COORDINATES_PREFIX
JarToMavenCoordinatesMapping = _JarToMavenCoordinatesMapping
TransitiveJarToMavenCoordinatesMapping = _TransitiveJarToMavenCoordinatesMapping
java_deps = _java_deps

assemble_targz = _assemble_targz
assemble_zip = _assemble_zip

tgz2zip = _tgz2zip

assemble_crate = _assemble_crate
deploy_crate = _deploy_crate

doxygen_docs = _doxygen_docs
sphinx_docs = _sphinx_docs

assemble_gcp = _assemble_gcp

deploy_github = _deploy_github

JarInfo = _JarInfo
MavenDeploymentInfo = _MavenDeploymentInfo
assemble_maven = _assemble_maven
deploy_maven = _deploy_maven

assemble_npm = _assemble_npm
deploy_npm = _deploy_npm

assemble_packer = _assemble_packer
deploy_packer = _deploy_packer

assemble_pip = _assemble_pip
deploy_pip = _deploy_pip
