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

load("@rules_rust//rust:rust_common.bzl", "CrateInfo")

CrateDeploymentInfo = provider(
    fields = {
        "crate": "Crate file to deploy",
    },
)

def _generate_version_file(ctx):
    version_file = ctx.file.version_file
    if not ctx.attr.version_file:
        version_file = ctx.actions.declare_file(ctx.attr.name + "__do_not_reference.version")
        version = ctx.var.get("version", ctx.attr.target[CrateSummary].version)

        if len(version) == 40:
            # this is a commit SHA, most likely
            version = "0.0.0-{}".format(version)

        ctx.actions.run_shell(
            inputs = [],
            outputs = [version_file],
            command = "echo -n {} > {}".format(version, version_file.path),
        )
    return version_file

def validate_url(field_name, field_value):
    if not field_value.startswith("http://") and not field_value.startswith("https://"):
        fail("URL for field `{}` must begin with http:// or https://".format(field_name))


def validate_keywords(keywords):
    if len(keywords) > 5:
        fail("Maximum of 5 keywords is supported; {} found".format(len(keywords)))
    for keyword in keywords:
        if len(keyword) > 20:
            fail("Keywords need to be 20 characters maximum; {} is invalid (length = {})".format(
                keyword, len(keyword)
                ))


def _assemble_crate_impl(ctx):
    deps = {}
    deps_workspaces = {}
    dep_features = {}
    for dependency in ctx.attr.target[CrateSummary].deps:
        deps[dependency[CrateSummary].name] = dependency[CrateSummary].version
        deps_workspaces[dependency[CrateSummary].name] = dependency[CrateSummary].workspace
        if dependency[CrateSummary].enabled_features:
            dep_features[dependency[CrateSummary].name] = ",".join(dependency[CrateSummary].enabled_features)

    print("DEPS: ")
    print(deps)
    print("DEPS_WORKPACES: ")
    print(deps_workspaces)

    validate_url('homepage', ctx.attr.homepage)
    validate_url('repository', ctx.attr.repository)
    validate_keywords(ctx.attr.keywords)
    version_file = _generate_version_file(ctx)
    args = [
        "--srcs", ";".join([x.path for x in ctx.attr.target[CrateInfo].srcs.to_list()] + [x.path for x in ctx.attr.target[CrateInfo].compile_data.to_list()]),
        "--output-crate", ctx.outputs.crate_package.path,
        "--root", ctx.attr.target[CrateInfo].root.path,
        "--edition", ctx.attr.target[CrateInfo].edition,
        "--name", ctx.attr.target[CrateSummary].name,
        "--version-file", version_file.path,
        "--authors", ";".join(ctx.attr.authors),
        "--keywords", ";".join(ctx.attr.keywords),
        "--categories", ";".join(ctx.attr.categories),
        "--description", ctx.attr.description,
        "--homepage", ctx.attr.homepage,
        "--license", ctx.attr.license,
        "--repository", ctx.attr.repository,
        "--deps", ";".join(["{}={}".format(k, v) for k, v in deps.items()]),
        "--dep-features", ";".join(["{}={}".format(k, v) for k, v in dep_features.items()]),
        "--dep-workspaces", ";".join(["{}={}".format(k, v) for k, v in deps_workspaces.items()]),
    ]
    if ctx.attr.documentation != "":
        validate_url('documentation', ctx.attr.documentation)
        args.append("--documentation")
        args.append(ctx.attr.documentation)
    if ctx.attr.crate_features:
        args.append("--crate-features")
        args.append(";".join([
            "{}={}".format(feature, ",".join(implied)) if implied else feature
            for feature, implied in ctx.attr.crate_features.items()
        ]))
    if ctx.files.universe_manifests:
        args.append("--universe-manifests")
        args.append(";".join([f.path for f in ctx.files.universe_manifests]))
    inputs = [version_file]
    if ctx.file.readme_file:
        args.append("--readme-file")
        args.append(ctx.file.readme_file.path)
        inputs.append(ctx.file.readme_file)
    if ctx.file.license_file:
        args.append("--license-file")
        args.append(ctx.file.license_file.path)
        inputs.append(ctx.file.license_file)
    if ctx.file.workspace_refs:
        args.append("--workspace-refs-file=" + ctx.file.workspace_refs.path)
        inputs.append(ctx.file.workspace_refs)
    ctx.actions.run(
        inputs = inputs + ctx.attr.target[CrateInfo].srcs.to_list() + ctx.attr.target[CrateInfo].compile_data.to_list() + ctx.files.universe_manifests,
        outputs = [ctx.outputs.crate_package],
        executable = ctx.executable._crate_assembler_tool,
        arguments = args,
    )
    return [
        CrateDeploymentInfo(
            crate = ctx.outputs.crate_package,
        ),
    ]

CrateSummary = provider(
    fields = {
        "name": "Crate name",
        "version": "Crate version",
        "workspace": "Bazel workspace name containing the target",
        "deps": "Crate dependencies",
        "enabled_features": "Enabled features",
    },
)

def _is_universe_crate(target):
    return str(target.label).startswith("@crates__")

def _universe_crate_name(target):
    return str(target.label).split(".")[0].rsplit("-", 1)[0].removeprefix("@crates__")

def _aggregate_crate_summary_impl(target, ctx):
    if _is_universe_crate(target):
        name = _universe_crate_name(target)
    else:
        name = ctx.rule.attr.name
        for tag in ctx.rule.attr.tags:
            if tag.startswith("crate-name"):
                name = tag.split("=")[1]
    return CrateSummary(
        name = name,
        version = ctx.rule.attr.version,
        workspace = target.label.workspace_root.replace("external/", ""),
        deps = [target for target in getattr(ctx.rule.attr, "deps", []) + getattr(ctx.rule.attr, "proc_macro_deps", [])],
        enabled_features = getattr(ctx.rule.attr, "crate_features", []),
    )


aggregate_crate_summary = aspect(
    attr_aspects = [
       "deps",
       "proc_macro_deps",
    ],
    doc = "Collects the Crate coordinates of the given rust_library and its direct dependencies",
    implementation = _aggregate_crate_summary_impl,
    provides = [CrateSummary],
)

assemble_crate = rule(
    implementation = _assemble_crate_impl,
    attrs = {
        "target": attr.label(
            mandatory = True,
            doc = "`rust_library` label to be included in the package",
            aspects = [aggregate_crate_summary],
            providers = [CrateInfo, CrateSummary],
        ),
        "version_file": attr.label(
            allow_single_file = True,
            doc = """
            File containing version string.
            Alternatively, pass --define version=VERSION to Bazel invocation.
            Not specifying version at all defaults to '0.0.0'
            """,
        ),
        "workspace_refs": attr.label(
            allow_single_file = True,
            mandatory = False, # TODO: make mandatory
            doc = "JSON file describing dependencies to other Bazel workspaces",
        ),
        "universe_manifests": attr.label_list(
            doc = """
            The Cargo manifests used by crates_universe to generate Bazel targets for crates.io dependencies.

            These manifests serve as the source of truth for emitting dependency configuration in the assembled crate,
            such as explicitly requested features and the exact version requirement.
            """,
            allow_files = True,
        ),
        "crate_features": attr.string_list_dict(
            doc = """
            Available features in the crate, in format similar to the cargo features format.
            """,
        ),
        "authors": attr.string_list(
            doc = """Project authors""",
        ),
        "description": attr.string(
            mandatory = True,
            doc = """
            The description is a short blurb about the package. crates.io will display this with your package. This should be plain text (not Markdown).
            https://doc.rust-lang.org/cargo/reference/manifest.html#the-description-field
            """,
        ),
        "documentation": attr.string(
            doc = """Link to documentation of the project""",
        ),
        "homepage": attr.string(
            mandatory = True,
            doc = """Link to homepage of the project""",
        ),
        "readme_file": attr.label(
            allow_single_file = True,
            mandatory = False,
            doc = """README of the project""",
        ),
        "keywords": attr.string_list(
            doc = """
            The keywords field is an array of strings that describe this package.
            This can help when searching for the package on a registry, and you may choose any words that would help someone find this crate.

            Note: crates.io has a maximum of 5 keywords.
            Each keyword must be ASCII text, start with a letter, and only contain letters, numbers, _ or -, and have at most 20 characters.

            https://doc.rust-lang.org/cargo/reference/manifest.html#the-keywords-field
            """,
        ),
        "categories": attr.string_list(
            doc = """Project categories""",
        ),
        "license": attr.string(
            mandatory = True,
            doc = """
            The license field contains the name of the software license that the package is released under.
            https://doc.rust-lang.org/cargo/reference/manifest.html#the-license-and-license-file-fields
            """,
        ),
        "license_file": attr.label(
            allow_single_file = True,
            mandatory = False,
            doc = "License file for the crate.",
        ),
        "repository": attr.string(
            mandatory = True,
            doc = """Repository of the project""",
        ),
        "_crate_assembler_tool": attr.label(
            executable = True,
            cfg = "host",
            default = "@vaticle_bazel_distribution//crates:crate-assembler",
        ),
    },
    outputs = {
        "crate_package": "%{name}.crate",
    },
)

def _deploy_crate_impl(ctx):
    deploy_crate_script = ctx.actions.declare_file(ctx.attr.name)

    files = [
        ctx.attr.target[CrateDeploymentInfo].crate,
        ctx.file._crate_deployer,
    ]

    ctx.actions.expand_template(
        template = ctx.file._crate_deployer_wrapper_template,
        output = deploy_crate_script,
        substitutions = {
            "$CRATE_PATH": ctx.attr.target[CrateDeploymentInfo].crate.short_path,
            "$SNAPSHOT_REPO": ctx.attr.snapshot,
            "$RELEASE_REPO": ctx.attr.release,
            "$DEPLOYER_PATH": ctx.file._crate_deployer.short_path,
        },
    )

    return DefaultInfo(
        executable = deploy_crate_script,
        runfiles = ctx.runfiles(
            files = files,
        ),
    )

deploy_crate = rule(
    attrs = {
        "target": attr.label(
            mandatory = True,
            providers = [CrateDeploymentInfo],
            doc = "assemble_crate target to deploy",
        ),
        "snapshot": attr.string(
            mandatory = True,
            doc = "Snapshot repository to release Crate artifact to",
        ),
        "release": attr.string(
            mandatory = True,
            doc = "Release repository to release Crate artifact to",
        ),
        "_crate_deployer": attr.label(
            allow_single_file = True,
            default = "@vaticle_bazel_distribution//crates:crate-deployer_deploy.jar"
        ),
        "_crate_deployer_wrapper_template": attr.label(
            allow_single_file = True,
            default = "@vaticle_bazel_distribution//crates/templates:deploy.sh",
        )
    },
    executable = True,
    implementation = _deploy_crate_impl,
    doc = "Deploy `assemble_crate` target into Crate repo",
)
