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

exports_files(["rules.bzl"])

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@io_bazel_rules_kotlin//kotlin:jvm.bzl", "kt_jvm_library")

bzl_library(
    name = "lib",
    srcs = [
        "rules.bzl",
    ],
    deps = [
        "@rules_rust//rust:bzl_lib"
    ],
    visibility = ["//visibility:public"],
)

kt_jvm_library(
    name = "crate-assembler-lib",
    srcs = [
        "CrateAssembler.kt",
    ],
    deps = [
        "@maven//:com_eclipsesource_minimal_json_minimal_json",
        "@maven//:com_electronwill_night_config_core",
        "@maven//:com_electronwill_night_config_toml",
        "@maven//:info_picocli_picocli",
        "@maven//:org_apache_commons_commons_compress",
    ],
)

java_binary(
    name = "crate-assembler",
    main_class = "com.vaticle.bazeldistribution.crates.CrateAssemblerKt",
    visibility = ["//visibility:public"],
    runtime_deps = [
        ":crate-assembler-lib",
    ],
)

kt_jvm_library(
    name = "crate-deployer-lib",
    srcs = [
        "CrateDeployer.kt",
    ],
    deps = [
        "@maven//:com_eclipsesource_minimal_json_minimal_json",
        "@maven//:com_google_http_client_google_http_client",
        "@maven//:info_picocli_picocli",
    ],
)

java_binary(
    name = "crate-deployer",
    main_class = "com.vaticle.bazeldistribution.crates.CrateDeployerKt",
    visibility = ["//visibility:public"],
    runtime_deps = [
        ":crate-deployer-lib",
    ],
)
