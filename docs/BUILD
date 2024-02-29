#
# Copyright (C) 2022 Vaticle
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

exports_files(["cpp/doxyfile.template", "python/requirements.txt"])

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@vaticle_dependencies_tool_docs//:requirements.bzl", docs_requirement = "requirement")

py_binary(
    name = "sphinx_runner",
    srcs = [
        "python/sphinx_html_builder.py",
    ],
    main = "sphinx_html_builder.py",
    deps = [docs_requirement("sphinx")],
    visibility = ["//visibility:public"]
)

bzl_library(
    name = "lib",
    srcs = [
        "cpp/rules.bzl",
        "python/rules.bzl",
    ],
    deps = [],
    visibility = ["//visibility:public"],
)
