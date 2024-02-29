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

exports_files(["archiver.py", "common.py"])

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@io_bazel_rules_kotlin//kotlin:jvm.bzl", "kt_jvm_library")

bzl_library(
    name = "lib",
    srcs = [ "rules.bzl" ],
    deps = [
        "//common/assemble_versioned:lib",
        "//common/checksum:lib",
        "//common/generate_json_config:lib",
        "//common/java_deps:lib",
        "//common/rename:lib",
        "//common/targz:lib",
        "//common/tgz2zip:lib",
        "//common/workspace_refs:lib",
        "//common/zip:lib"
    ],
    visibility = ["//visibility:public"]
)

kt_jvm_library(
    name = "common",
    srcs = glob(["*.kt"]),
    deps = [],
    visibility = ["//visibility:public"],
)
