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

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

# FIXME For some reason @rules_pkg//doc_build:rules_pkg_lib cannot be accessed from here
#  so I duplicated its content here and added "@bazel_skylib//lib:sets" because it was missing
bzl_library(
    name = "rules_pkg_lib",
    srcs = [
        "@rules_pkg//:version.bzl",
        "@rules_pkg//pkg:bzl_srcs",
        "@bazel_skylib//lib:paths",
        "@bazel_skylib//lib:sets",
    ],
    visibility = ["//visibility:public"],
)

bzl_library(
    name = "lib",
    srcs = [
        "rules.bzl",
        "@rules_pkg//:pkg.bzl",
        "@rules_pkg//pkg:pkg.bzl",
    ],
    deps = [
        ":rules_pkg_lib",
    ],
    visibility = ["//visibility:public"]
)

py_binary(
    name = "generate_depends_file",
    srcs = ["generate_depends_file.py"],
    visibility = ["//visibility:public"]
)
